import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/api/api_client.dart';
import '../../../data/booking/booking_repository.dart';
import '../../../data/mocks/mock_attendee_events.dart';
import '../../../ui/theme/jol_theme.dart';
import '../../../ui/widgets/jol_button.dart';
import '../../../ui/widgets/jol_card.dart';
import '../../../ui/widgets/jol_list_row.dart';
import '../../../ui/widgets/jol_segmented.dart';
import '../../../ui/widgets/jol_sheet.dart';
import '../../../ui/widgets/jol_toast.dart';
import '../../attendee/state/attendee_controller.dart';
import '../../maps/discover_map_screen.dart';
import '../../maps/event_location_card.dart';
import '../../maps/maps_repository.dart';
import '../data/event_repository.dart';
import '../models/jol_event.dart';
import '../widgets/attendee_components.dart';
import '../widgets/jol_poster.dart';

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(
      attendeeControllerProvider.select((state) => state.selectedInterests),
    );
    final tokens = JolTokens.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('A little more you'),
        actions: [
          TextButton(
            onPressed: () => context.go('/discover'),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              'what are you into?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a few things and we’ll tune your Cape Town feed.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: 24),
            for (final category in mockCategoryNames) ...[
              Semantics(
                button: true,
                selected: selected.contains(category),
                label: '$category interest',
                child: GestureDetector(
                  onTap: () => ref
                      .read(attendeeControllerProvider.notifier)
                      .toggleInterest(category),
                  child: Stack(
                    children: [
                      MockCategoryArt(category: category, height: 144),
                      if (selected.contains(category))
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            semanticLabel: 'Selected',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            JolButton(
              label: 'Continue',
              expanded: true,
              onPressed: selected.isEmpty
                  ? null
                  : () => context.go('/discover'),
            ),
            const SizedBox(height: 16),
            Text(
              'Location is optional. You can set it anytime from Discover.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Whether Discover sorts events by distance from the phone.
class DiscoverNearMeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final discoverNearMeProvider = NotifierProvider<DiscoverNearMeNotifier, bool>(
  DiscoverNearMeNotifier.new,
);

class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  static final _referenceToday = DateTime(2026, 11, 12);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendeeControllerProvider);
    final controller = ref.read(attendeeControllerProvider.notifier);
    final eventsResult = ref.watch(attendeeEventsProvider);
    final tokens = JolTokens.of(context);
    final allEvents = eventsResult.asData?.value ?? const <JolEvent>[];
    final nearMe = ref.watch(discoverNearMeProvider);
    final positionResult = nearMe ? ref.watch(userPositionProvider) : null;
    final position = positionResult?.asData?.value;
    double? distanceTo(JolEvent event) => position == null || !event.hasPin
        ? null
        : distanceMetres(
            position.latitude,
            position.longitude,
            event.latitude!,
            event.longitude!,
          );
    final events = _filteredEvents(state, allEvents);
    if (position != null) {
      // Closest first; events without a map pin go last.
      events.sort((a, b) {
        final da = distanceTo(a);
        final db = distanceTo(b);
        if (da == null && db == null) return a.date.compareTo(b.date);
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AttendeeScreenHeader(
              title: 'discover more',
              subtitle: 'A good night starts with a plan.',
              trailing: AttendeeIconButton(
                icon: Icons.tune_rounded,
                label: 'Choose interests',
                onPressed: () => context.go('/interests'),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: _RoleSwitchCard(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showLocationSheet(context, ref),
                      icon: const Icon(Icons.place_outlined),
                      label: Text(state.location),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showDateSheet(context, ref),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      state.selectedDate == null
                          ? 'Date'
                          : formatEventDate(state.selectedDate!),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Map view',
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => Navigator.of(context, rootNavigator: true)
                        .push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DiscoverMapScreen(),
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.near_me_outlined, size: 18),
                    label: const Text('Near me'),
                    selected: nearMe,
                    onSelected: (value) {
                      ref.read(discoverNearMeProvider.notifier).set(value);
                      if (value) ref.invalidate(userPositionProvider);
                    },
                  ),
                  const SizedBox(width: 10),
                  if (nearMe && positionResult?.isLoading == true)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (nearMe && position == null)
                    Expanded(
                      child: Text(
                        'Turn on location to sort by distance.',
                        style: TextStyle(color: tokens.muted),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (state.isOffline)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: JolCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off_outlined, color: tokens.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You’re offline. Showing events saved on this device.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _DateStrip(
              today: _referenceToday,
              selectedDate: state.selectedDate,
              events: allEvents,
              onSelect: controller.setDate,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: AttendeeSectionTitle(
                'pick your kind of night',
                trailing: TextButton(
                  onPressed: () => context.go('/interests'),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 118,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: mockCategoryNames.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final category = mockCategoryNames[index];
                  return SizedBox(
                    width: 156,
                    child: InkWell(
                      onTap: () => context.push('/category/$category'),
                      borderRadius: BorderRadius.circular(14),
                      child: MockCategoryArt(category: category, height: 118),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: AttendeeSectionTitle(
                state.selectedDate == null
                    ? 'this week'
                    : formatEventDate(state.selectedDate!),
                trailing: TextButton(
                  onPressed: () {
                    if (state.selectedDate == null) {
                      context.go('/search');
                    } else {
                      controller.setDate(null);
                    }
                  },
                  child: Text(
                    state.selectedDate == null ? 'See all' : 'Any date',
                  ),
                ),
              ),
            ),
          ),
          if (eventsResult.isLoading && eventsResult.asData == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (eventsResult.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: JolCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Live events could not be loaded.'),
                      const SizedBox(height: 8),
                      Text(
                        eventsResult.error.toString(),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: tokens.muted),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(attendeeEventsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (events.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AttendeeEmptyState(
                title: 'No events on this day',
                message: 'Try another date or see what’s happening any day.',
                actionLabel: 'Show any date',
                onAction: () => controller.setDate(null),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              sliver: SliverList.separated(
                itemCount: events.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final event = events[index];
                  final distance = distanceTo(event);
                  return AttendeePosterCard(
                    event: event,
                    distance: distance == null ? null : formatDistance(distance),
                    onTap: () => context.push('/event/${event.id}'),
                    trailing: Icon(
                      event.isSoldOut
                          ? Icons.notifications_none
                          : Icons.arrow_forward,
                      size: 18,
                      color: tokens.muted,
                    ),
                  );
                },
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              child: JolCard(
                child: JolListRow(
                  title: 'Got an invite code?',
                  subtitle: 'Enter it to find a private event.',
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () => context.push('/invite'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<JolEvent> _filteredEvents(
    AttendeeState state,
    List<JolEvent> allEvents,
  ) {
    return allEvents.where((event) {
      if (state.selectedDate != null &&
          !_sameDay(event.date, state.selectedDate!)) {
        return false;
      }
      if (state.location.toLowerCase() != 'cape town' &&
          !event.area.toLowerCase().contains(state.location.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({
    required this.today,
    required this.selectedDate,
    required this.events,
    required this.onSelect,
  });

  final DateTime today;
  final DateTime? selectedDate;
  final List<JolEvent> events;
  final ValueChanged<DateTime?> onSelect;

  @override
  Widget build(BuildContext context) {
    final dates = List.generate(
      10,
      (index) => today.add(Duration(days: index)),
    );
    return SizedBox(
      height: 102,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        scrollDirection: Axis.horizontal,
        children: [
          _dateItem(
            context,
            label: 'Any',
            subLabel: 'date',
            selected: selectedDate == null,
            hasEvents: false,
            onTap: () => onSelect(null),
          ),
          for (final date in dates)
            _dateItem(
              context,
              label: _weekday(date),
              subLabel: '${date.day}',
              selected: selectedDate != null && _sameDay(selectedDate!, date),
              hasEvents: events.any((event) => _sameDay(event.date, date)),
              onTap: () => onSelect(date),
            ),
        ],
      ),
    );
  }

  Widget _dateItem(
    BuildContext context, {
    required String label,
    required String subLabel,
    required bool selected,
    required bool hasEvents,
    required VoidCallback onTap,
  }) {
    final tokens = JolTokens.of(context);
    return SizedBox(
      width: 52,
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label $subLabel${hasEvents ? ', events available' : ''}',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: selected ? tokens.text : tokens.muted),
              ),
              const SizedBox(height: 5),
              Text(
                subLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? tokens.text : tokens.muted,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: hasEvents ? tokens.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendeeControllerProvider);
    final eventsResult = ref.watch(attendeeEventsProvider);
    final events = (eventsResult.asData?.value ?? const <JolEvent>[])
        .where(
          (event) =>
              event.category == category &&
              (state.selectedDate == null ||
                  _sameDay(event.date, state.selectedDate!)),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: MockCategoryArt(category: category, height: 154),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showLocationSheet(context, ref),
                      icon: const Icon(Icons.place_outlined),
                      label: Text(state.location),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showDateSheet(context, ref),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      state.selectedDate == null
                          ? 'Date'
                          : formatEventDate(state.selectedDate!),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AttendeeSectionTitle('$category in Cape Town'),
            ),
          ),
          if (eventsResult.isLoading && eventsResult.asData == null)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (eventsResult.hasError)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: JolCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Live events could not be loaded.'),
                      const SizedBox(height: 8),
                      Text(eventsResult.error.toString()),
                      TextButton(
                        onPressed: () => ref.invalidate(attendeeEventsProvider),
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (events.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: AttendeeEmptyState(
                title: 'Nothing on this date',
                message: 'Choose another date to see more events.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverList.separated(
                itemCount: events.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) => AttendeePosterCard(
                  event: events[index],
                  onTap: () => context.push('/event/${events[index].id}'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendeeControllerProvider);
    final controller = ref.read(attendeeControllerProvider.notifier);
    final eventsResult = ref.watch(attendeeEventsProvider);
    final tokens = JolTokens.of(context);
    final query = state.searchQuery.trim().toLowerCase();
    final allEvents = eventsResult.asData?.value ?? const <JolEvent>[];
    final matchingEvents = allEvents.where((event) {
      return query.isEmpty ||
          '${event.title} ${event.area} ${event.category} ${event.host}'
              .toLowerCase()
              .contains(query);
    }).toList();
    final hosts = allEvents
        .map((event) => event.host)
        .toSet()
        .where((host) => query.isEmpty || host.toLowerCase().contains(query))
        .toList();
    // People search needs a backend endpoint; until then show none.
    const people = <MockPerson>[];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          Text('search', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          TextField(
            onChanged: controller.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Events, organisers, people',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: state.searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => controller.setSearchQuery(''),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          JolSegmented(
            options: const ['All', 'Events', 'Organisers', 'People'],
            selected: switch (state.searchTab) {
              AttendeeSearchTab.all => 'All',
              AttendeeSearchTab.events => 'Events',
              AttendeeSearchTab.organisers => 'Organisers',
              AttendeeSearchTab.people => 'People',
            },
            onSelectionChanged: (value) =>
                controller.setSearchTab(switch (value) {
                  'Events' => AttendeeSearchTab.events,
                  'Organisers' => AttendeeSearchTab.organisers,
                  'People' => AttendeeSearchTab.people,
                  _ => AttendeeSearchTab.all,
                }),
          ),
          const SizedBox(height: 18),
          if (eventsResult.isLoading && eventsResult.asData == null)
            const Center(child: CircularProgressIndicator())
          else if (eventsResult.hasError)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Live events could not be loaded: ${eventsResult.error}'),
                TextButton(
                  onPressed: () => ref.invalidate(attendeeEventsProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          if (state.searchTab == AttendeeSearchTab.all ||
              state.searchTab == AttendeeSearchTab.events) ...[
            AttendeeSectionTitle('events'),
            for (final event in matchingEvents.take(4)) ...[
              AttendeePosterCard(
                event: event,
                onTap: () => context.push('/event/${event.id}'),
                compact: true,
              ),
              const SizedBox(height: 10),
            ],
          ],
          if (state.searchTab == AttendeeSearchTab.all ||
              state.searchTab == AttendeeSearchTab.organisers) ...[
            AttendeeSectionTitle('organisers'),
            for (final host in hosts.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: JolCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: JolListRow(
                    title: host,
                    subtitle:
                        allEvents.any(
                          (event) => event.host == host && event.isVerifiedHost,
                        )
                        ? 'Verified organiser'
                        : 'Event organiser',
                    trailing: TextButton(
                      onPressed: () => controller.toggleFollowOrganiser(host),
                      child: Text(
                        state.followedOrganisers.contains(host)
                            ? 'Following'
                            : 'Follow',
                      ),
                    ),
                  ),
                ),
              ),
          ],
          if (state.searchTab == AttendeeSearchTab.all ||
              state.searchTab == AttendeeSearchTab.people) ...[
            AttendeeSectionTitle('people'),
            for (final person in people)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: JolCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: JolListRow(
                    title: person.name,
                    subtitle: person.isPublic ? person.note : 'Private profile',
                    trailing: person.isPublic && person.username != null
                        ? TextButton(
                            onPressed: () =>
                                controller.toggleFollowPerson(person.username!),
                            child: Text(
                              state.followedPeople.contains(person.username)
                                  ? 'Following'
                                  : 'Follow',
                            ),
                          )
                        : null,
                  ),
                ),
              ),
          ],
          if (matchingEvents.isEmpty && hosts.isEmpty && people.isEmpty)
            AttendeeEmptyState(
              title: 'No results yet',
              message: 'Try another name, event or neighbourhood.',
            ),
          const SizedBox(height: 8),
          Text(
            'Showing Cape Town events',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

class EventScreen extends ConsumerWidget {
  const EventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventResult = ref.watch(attendeeEventProvider(eventId));
    if (eventResult.isLoading && eventResult.asData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (eventResult.hasError && eventResult.asData == null) {
      return Scaffold(
        appBar: AppBar(),
        body: AttendeeEmptyState(
          title: 'Event could not be loaded',
          message: eventResult.error.toString(),
        ),
      );
    }
    final event = eventResult.asData?.value;
    if (event == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const AttendeeEmptyState(
          title: 'Event not found',
          message: 'This event may have been removed.',
        ),
      );
    }
    return EventDetailsView(event: event);
  }
}

/// The host's preview of an event before it's saved: the real event page
/// with every button switched off.
class EventPreviewScreen extends StatelessWidget {
  const EventPreviewScreen({super.key, required this.event, this.coverFile});

  final JolEvent event;
  final File? coverFile;

  @override
  Widget build(BuildContext context) =>
      EventDetailsView(event: event, preview: true, coverFile: coverFile);
}

/// The event page. [preview] disables every action for the host's preview.
class EventDetailsView extends ConsumerWidget {
  const EventDetailsView({
    super.key,
    required this.event,
    this.preview = false,
    this.coverFile,
  });

  final JolEvent event;
  final bool preview;

  /// Photo picked on the form but not uploaded yet (preview only).
  final File? coverFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendeeControllerProvider);
    final controller = ref.read(attendeeControllerProvider.notifier);
    final tokens = JolTokens.of(context);
    final isJoined = state.joinedGuestlists.contains(event.id);
    final myRsvps = ref.watch(myRsvpsProvider).asData?.value ?? const [];
    final isRsvped =
        state.rsvpEvents.contains(event.id) ||
        myRsvps.any((rsvp) => rsvp.event.id == event.id);
    // The server hides private locations from guests who haven't RSVP'd.
    final hasAccess = event.isApiBacked
        ? !event.locationHidden
        : (!event.isPrivate || isRsvped);
    final entryText = [
      if (event.isAgeRestricted) '18+ only · bring a valid ID.',
      if (event.entryRules.isNotEmpty) event.entryRules,
    ].join(' ');

    return Scaffold(
      appBar: AppBar(
        title: Text(preview ? 'preview' : 'event'),
        actions: preview ? null : [
          AttendeeIconButton(
            icon: state.savedEvents.contains(event.id)
                ? Icons.bookmark
                : Icons.bookmark_border,
            label: state.savedEvents.contains(event.id)
                ? 'Remove saved event'
                : 'Save event',
            onPressed: () => controller.toggleSavedEvent(event.id),
          ),
          AttendeeIconButton(
            icon: Icons.ios_share,
            label: 'Share event',
            onPressed: () => context.push('/share/${event.id}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          if (preview) ...[
            JolCard(
              padding: const EdgeInsets.all(12),
              child: Text(
                'This is how guests will see your event. Buttons are off in the preview.',
                style: TextStyle(color: tokens.muted),
              ),
            ),
            const SizedBox(height: 12),
          ],
          JolPoster(
            style: event.posterStyle,
            primary: Color(event.posterPrimary),
            secondary: Color(event.posterSecondary),
            title: event.title,
            area: event.area,
            dateStamp: eventDateStamp(event.date),
            imageUrl: event.coverImageUrl,
            imageFile: coverFile,
            size: Size(MediaQuery.sizeOf(context).width - 40, 350),
          ),
          const SizedBox(height: 20),
          Text(
            event.title,
            style: Theme.of(context).textTheme.displayMedium
                ?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatEventDate(event.date)} · ${event.startTime}–${event.endTime}',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 14),
          JolCard(
            child: Column(
              children: [
                JolListRow(
                  title: hasAccess ? event.venue : 'Address shared after RSVP',
                  subtitle: hasAccess
                      ? '${event.area}, Cape Town'
                      : 'Somewhere in ${event.area}',
                  trailing: const Icon(Icons.location_on_outlined),
                  onTap: hasAccess && !preview
                      ? () => showDirectionsSheet(context, event)
                      : null,
                ),
                const Divider(height: 18),
                JolListRow(
                  title: event.host,
                  subtitle: event.isVerifiedHost
                      ? 'Verified organiser · ${event.hostEventCount} events'
                      : 'Organiser',
                  trailing: TextButton(
                    onPressed: preview
                        ? null
                        : () => controller.toggleFollowOrganiser(event.host),
                    child: Text(
                      state.followedOrganisers.contains(event.host)
                          ? 'Following'
                          : 'Follow',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (event.isApiBacked && (event.hasPin || event.locationHidden)) ...[
            const SizedBox(height: 14),
            EventLocationCard(event: event, enabled: !preview),
          ],
          const SizedBox(height: 16),
          JolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AttendeeSectionTitle('about this event'),
                Text(event.description),
                if (entryText.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'GETTING IN',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(entryText),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (event.guestlistSpots > 0) ...[
            JolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AttendeeSectionTitle(
                    'guestlist',
                    trailing: Icon(
                      Icons.confirmation_number_outlined,
                      color: tokens.muted,
                    ),
                  ),
                  Text(
                    'Free entry before ${event.guestlistCutoff} · '
                    '${event.guestlistSpots} spots left',
                  ),
                  const SizedBox(height: 12),
                  JolButton(
                    label: isJoined ? 'On the guestlist' : 'Join guestlist',
                    expanded: true,
                    variant: isJoined
                        ? JolButtonVariant.secondary
                        : JolButtonVariant.primary,
                    onPressed: isJoined || preview
                        ? null
                        : () => _showGuestlistSheet(context, ref, event),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your name is shared with the host for entry.',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: tokens.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (event.rsvpCapacity > 0) ...[
            JolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AttendeeSectionTitle('free RSVP'),
                  Text(
                    [
                      '${event.rsvpCapacity} spots',
                      if (event.isApiBacked && event.maxPlusOnes > 0)
                        'up to ${event.maxPlusOnes} plus-one${event.maxPlusOnes == 1 ? '' : 's'}',
                      if (event.guestlistCutoff != null)
                        'RSVPs close ${event.guestlistCutoff}',
                    ].join(' · '),
                  ),
                  const SizedBox(height: 12),
                  JolButton(
                    label: isRsvped
                        ? 'You’re going'
                        : event.rsvpClosed
                        ? 'RSVPs closed'
                        : 'RSVP free',
                    expanded: true,
                    onPressed: isRsvped || preview || event.rsvpClosed
                        ? null
                        : () => _showRsvpSheet(context, ref, event),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (event.fundTitle != null) ...[
            JolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AttendeeSectionTitle(event.fundTitle!),
                  Text(
                    '${formatZar(event.fundRaised)} of ${formatZar(event.fundGoal)} · '
                    '${event.fundContributors} contributions',
                  ),
                  const SizedBox(height: 12),
                  JolButton(
                    label: event.fundSuggested > 0
                        ? 'Contribute · suggested ${formatZar(event.fundSuggested)}'
                        : 'Contribute',
                    expanded: true,
                    variant: JolButtonVariant.purchase,
                    onPressed: preview
                        ? null
                        : () => context.push('/fund/${event.id}'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (!preview) JolCard(
            child: Column(
              children: [
                JolListRow(
                  title: 'Add to calendar',
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () => _showCalendarSheet(context, event),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Contact organiser',
                  trailing: const Icon(Icons.mail_outline),
                  onTap: () => _showContactSheet(context, event),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Report event',
                  trailing: const Icon(Icons.flag_outlined),
                  onTap: () => _showReportSheet(context, event),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          JolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AttendeeSectionTitle(
                  'who’s going',
                  trailing: Text('${event.attending}'),
                ),
                Text(
                  'People who choose to appear on public guest lists show here.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 94),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: JolButton(
          label: event.isSoldOut
              ? 'Sold out · Notify me'
              : event.isPaid
              ? (event.fromPrice == 0
                    ? 'Get free tickets'
                    : 'Get tickets · from ${formatZar(event.fromPrice)}')
              : isRsvped
              ? 'You’re going'
              : event.rsvpClosed
              ? 'RSVPs closed'
              : 'RSVP free',
          expanded: true,
          variant: event.isPaid
              ? JolButtonVariant.purchase
              : JolButtonVariant.primary,
          onPressed: preview
              ? null
              : event.isSoldOut
              ? () => JolToast.show(
                  context,
                  'We’ll notify you when tickets open.',
                )
              : event.isPaid
              ? () {
                  controller.setEvent(
                    event.id,
                    initialTierId: event.tiers
                        .firstWhere(
                          (tier) => !tier.isSoldOut,
                          orElse: () => event.tiers.first,
                        )
                        .id,
                  );
                  context.push('/tickets/choose/${event.id}');
                }
              : isRsvped || event.rsvpClosed
              ? null
              : () => _showRsvpSheet(context, ref, event),
        ),
      ),
    );
  }
}

class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('invite code')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'you’re invited',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the code from your host to open a private event.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Invite code'),
            ),
            const SizedBox(height: 14),
            JolButton(
              label: 'Find event',
              expanded: true,
              onPressed: () {
                final code = _codeController.text.trim();
                if (code.isEmpty) {
                  JolToast.show(context, 'Enter an invite code to continue.');
                  return;
                }
                context.go('/event/${Uri.encodeComponent(code)}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showLocationSheet(BuildContext context, WidgetRef ref) async {
  final parentContext = context;
  final locationController = TextEditingController(
    text: ref.read(attendeeControllerProvider).location,
  );
  var unsupported = false;
  await JolSheet.show<void>(
    context: context,
    title: 'choose a location',
    child: StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          TextField(
            controller: locationController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cape Town or an area',
            ),
            onChanged: (_) => setState(() => unsupported = false),
          ),
          if (unsupported) ...[
            const SizedBox(height: 12),
            JolCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("JOL isn’t in ${locationController.text.trim()} yet"),
                  const SizedBox(height: 6),
                  const Text('Let us know you want events there.'),
                  const SizedBox(height: 10),
                  JolButton(
                    label: 'Notify me',
                    expanded: true,
                    variant: JolButtonVariant.secondary,
                    onPressed: () {
                      Navigator.pop(context);
                      JolToast.show(
                        parentContext,
                        'You’ll be notified when JOL launches in ${locationController.text.trim()}.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          JolListRow(
            title: 'Cape Town',
            subtitle: 'All areas',
            onTap: () {
              ref
                  .read(attendeeControllerProvider.notifier)
                  .setLocation('Cape Town');
              Navigator.pop(context);
            },
          ),
          for (final area in [
            'Sea Point',
            'Woodstock',
            'Observatory',
            'City Centre',
          ])
            JolListRow(
              title: area,
              onTap: () {
                ref.read(attendeeControllerProvider.notifier).setLocation(area);
                Navigator.pop(context);
              },
            ),
          JolButton(
            label: 'Use this location',
            expanded: true,
            onPressed: () {
              final place = locationController.text.trim();
              const supported = {
                'cape town',
                'sea point',
                'woodstock',
                'observatory',
                'city centre',
                'bree street',
              };
              if (!supported.contains(place.toLowerCase())) {
                setState(() => unsupported = true);
                return;
              }
              ref.read(attendeeControllerProvider.notifier).setLocation(place);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
  locationController.dispose();
}

Future<void> _showDateSheet(BuildContext context, WidgetRef ref) async {
  final today = DiscoverScreen._referenceToday;
  await JolSheet.show<void>(
    context: context,
    title: 'choose a date',
    child: Column(
      children: [
        JolListRow(
          title: 'Any date',
          trailing: const Icon(Icons.calendar_month_outlined),
          onTap: () {
            ref.read(attendeeControllerProvider.notifier).setDate(null);
            Navigator.pop(context);
          },
        ),
        for (var index = 0; index < 10; index++)
          Builder(
            builder: (context) {
              final date = today.add(Duration(days: index));
              final liveEvents =
                  ref.read(attendeeEventsProvider).asData?.value ??
                  const <JolEvent>[];
              final hasEvents = liveEvents.any(
                (event) => _sameDay(event.date, date),
              );
              return JolListRow(
                title: formatEventDate(date),
                subtitle: hasEvents ? 'Events available' : null,
                onTap: () {
                  ref.read(attendeeControllerProvider.notifier).setDate(date);
                  Navigator.pop(context);
                },
              );
            },
          ),
      ],
    ),
  );
}

Future<void> _showGuestlistSheet(
  BuildContext context,
  WidgetRef ref,
  JolEvent event,
) async {
  await JolSheet.show<void>(
    context: context,
    title: 'join the guestlist',
    child: _RsvpForm(event: event, guestlist: true),
  );
}

Future<void> _showRsvpSheet(
  BuildContext context,
  WidgetRef ref,
  JolEvent event,
) async {
  await JolSheet.show<void>(
    context: context,
    title: 'RSVP for free',
    child: _RsvpForm(event: event, guestlist: false),
  );
}

/// Sends POST /events/{id}/rsvp. A guestlist spot is an RSVP with status going.
class _RsvpForm extends ConsumerStatefulWidget {
  const _RsvpForm({required this.event, required this.guestlist});

  final JolEvent event;
  final bool guestlist;

  @override
  ConsumerState<_RsvpForm> createState() => _RsvpFormState();
}

class _RsvpFormState extends ConsumerState<_RsvpForm> {
  final _name = TextEditingController();
  var _plusOnes = 0;

  bool get _plusOne => _plusOnes > 0;

  /// API events set how many plus-ones each guest may bring.
  int get _maxPlusOnes =>
      widget.event.isApiBacked ? widget.event.maxPlusOnes : 1;
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(bookingRepositoryProvider)
          .rsvp(
            widget.event.id,
            plusOnes: _plusOnes,
            guestName: _name.text,
            note: widget.guestlist ? 'Guestlist' : null,
          );
      final controller = ref.read(attendeeControllerProvider.notifier);
      if (widget.guestlist) {
        controller.joinGuestlist(widget.event.id, plusOne: _plusOne);
      } else {
        controller.rsvp(widget.event.id, plusOne: _plusOnes);
      }
      ref.invalidate(myRsvpsProvider);
      ref.invalidate(attendeeEventProvider(widget.event.id));
      if (!mounted) return;
      Navigator.pop(context);
      JolToast.show(
        context,
        widget.guestlist ? 'You’re on the guestlist.' : 'Your RSVP is confirmed.',
      );
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.guestlist)
          const Text('Your name will be shared with the host for entry.'),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: InputDecoration(
            labelText: widget.guestlist ? 'Name on the list' : 'Name',
            helperText: 'Leave blank to use your profile name',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 8),
        if (_maxPlusOnes == 1)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(widget.guestlist ? 'Add a plus-one' : 'Bring a plus-one'),
            value: _plusOne,
            onChanged: (value) => setState(() => _plusOnes = value ? 1 : 0),
          )
        else if (_maxPlusOnes > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DropdownButtonFormField<int>(
              initialValue: _plusOnes,
              decoration: const InputDecoration(labelText: 'Plus-ones'),
              items: [
                for (var count = 0; count <= _maxPlusOnes; count++)
                  DropdownMenuItem(
                    value: count,
                    child: Text(count == 0 ? 'Just me' : '+$count'),
                  ),
              ],
              onChanged: (value) => setState(() => _plusOnes = value ?? 0),
            ),
          ),
        if (_error != null) ...[
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'You can find this pass in Tickets.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: tokens.muted),
        ),
        const SizedBox(height: 12),
        JolButton(
          label: _sending
              ? 'Sending…'
              : widget.guestlist
              ? 'Confirm guestlist'
              : 'Confirm RSVP',
          expanded: true,
          onPressed: _sending ? null : _submit,
        ),
      ],
    );
  }
}

Future<void> _showCalendarSheet(BuildContext context, JolEvent event) async {
  await JolSheet.show<void>(
    context: context,
    title: 'add to calendar',
    child: Column(
      children: [
        for (final calendar in [
          ('Google Calendar', Icons.calendar_today_outlined),
          ('Apple Calendar', Icons.phone_iphone_outlined),
          ('Outlook', Icons.mail_outline),
          ('Other calendar (.ics)', Icons.ios_share),
        ])
          JolListRow(
            title: calendar.$1,
            trailing: Icon(calendar.$2),
            onTap: () {
              _addEventToCalendar(event);
              Navigator.pop(context);
              JolToast.show(
                context,
                '${event.title} calendar details are ready to add.',
              );
            },
          ),
      ],
    ),
  );
}

Future<void> _showContactSheet(BuildContext context, JolEvent event) async {
  await JolSheet.show<void>(
    context: context,
    title: 'contact organiser',
    child: _ContactForm(event: event),
  );
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({required this.event});

  final JolEvent event;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  var _includeEmail = true;
  var _sent = false;

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text('Your message was sent to JOL to relay to the organiser.'),
      );
    }
    return Column(
      children: [
        Text(
          'Your email stays private. JOL relays this message to ${widget.event.host}.',
        ),
        const SizedBox(height: 12),
        const TextField(
          decoration: InputDecoration(labelText: 'Topic'),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 10),
        const TextField(
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(labelText: 'Message'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include my email so they can reply'),
          value: _includeEmail,
          onChanged: (value) => setState(() => _includeEmail = value),
        ),
        JolButton(
          label: 'Send message',
          expanded: true,
          onPressed: () {
            setState(() => _sent = true);
            JolToast.show(
              context,
              'Your message is sent to JOL to relay privately to ${widget.event.host}.',
            );
          },
        ),
      ],
    );
  }
}

Future<void> _showReportSheet(BuildContext context, JolEvent event) async {
  await JolSheet.show<void>(
    context: context,
    title: 'report this event',
    child: _ReportForm(event: event),
  );
}

class _ReportForm extends ConsumerStatefulWidget {
  const _ReportForm({required this.event});

  final JolEvent event;

  @override
  ConsumerState<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<_ReportForm> {
  String? _reason;
  bool _submitted = false;
  bool _sending = false;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .report(widget.event.id, reason: _reason!, details: _details.text);
      if (!mounted) return;
      setState(() => _submitted = true);
      JolToast.show(context, 'Your report is sent to JOL for moderation review.');
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text('Your report was sent to JOL for review.'),
      );
    }
    const reasons = [
      'Fake or scam',
      'Misleading details or pricing',
      'Unsafe',
      'Offensive',
      'Cancelled but still selling',
      'Something else',
    ];
    return Column(
      children: [
        for (final reason in reasons)
          Semantics(
            button: true,
            selected: _reason == reason,
            child: InkWell(
              onTap: () => setState(() => _reason = reason),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Icon(
                      _reason == reason
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
            ),
          ),
        TextField(
          controller: _details,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Details (optional)'),
        ),
        const SizedBox(height: 12),
        JolButton(
          label: _sending ? 'Sending…' : 'Send report',
          expanded: true,
          onPressed: _reason == null || _sending ? null : _send,
        ),
      ],
    );
  }
}

void _addEventToCalendar(JolEvent event) {
  final startParts = event.startTime.split(':');
  final endParts = event.endTime.split(':');
  final startDate = DateTime(
    event.date.year,
    event.date.month,
    event.date.day,
    int.tryParse(startParts.first) ?? 0,
    int.tryParse(startParts.elementAtOrNull(1) ?? '0') ?? 0,
  );
  final endDate = DateTime(
    event.date.year,
    event.date.month,
    event.date.day,
    int.tryParse(endParts.first) ?? 0,
    int.tryParse(endParts.elementAtOrNull(1) ?? '0') ?? 0,
  );

  final calendarEvent = Event(
    title: event.title,
    description: event.description,
    location: '${event.venue}, ${event.area}, Cape Town',
    startDate: startDate,
    endDate: endDate,
    allDay: false,
  );

  Add2Calendar.addEvent2Cal(calendarEvent);
}

class _RoleSwitchCard extends ConsumerWidget {
  const _RoleSwitchCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      attendeeControllerProvider.select((state) => state.accessMode),
    );
    final tokens = JolTokens.of(context);
    final options = [
      (
        label: 'Normal user',
        mode: AppAccessMode.attendee,
        icon: Icons.person_outline,
      ),
      (
        label: 'Host',
        mode: AppAccessMode.host,
        icon: Icons.event_available_outlined,
      ),
      (label: 'Staff', mode: AppAccessMode.staff, icon: Icons.badge_outlined),
    ];

    return JolCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('View as', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(option.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(option.label),
                      ],
                    ),
                    selected: mode == option.mode,
                    onSelected: (_) {
                      ref
                          .read(attendeeControllerProvider.notifier)
                          .setAccessMode(option.mode);
                      switch (option.mode) {
                        case AppAccessMode.attendee:
                          context.go('/discover');
                        case AppAccessMode.host:
                          context.go('/host');
                        case AppAccessMode.staff:
                          context.go('/staff');
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              switch (mode) {
                AppAccessMode.attendee => 'Normal attendee mode',
                AppAccessMode.host => 'Host dashboard enabled',
                AppAccessMode.staff => 'Door staff checklist enabled',
              },
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: tokens.muted),
            ),
          ],
        ),
      ),
    );
  }
}

String _weekday(DateTime date) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[date.weekday - 1];
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;
