import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../attendee/state/attendee_controller.dart';
import '../../../data/api/api_client.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/auth/profile_repository.dart';
import '../../../data/booking/booking_repository.dart';
import '../../discover/data/event_repository.dart';
import '../../discover/models/jol_event.dart';
import '../../../ui/theme/jol_theme.dart';
import '../../../ui/widgets/jol_button.dart';
import '../../../ui/widgets/jol_card.dart';
import '../../../ui/widgets/jol_list_row.dart';
import '../../../ui/widgets/jol_sheet.dart';
import '../../../ui/widgets/jol_theme_button.dart';
import '../../../ui/widgets/jol_toast.dart';

class AttendeeMeScreen extends ConsumerWidget {
  const AttendeeMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendeeControllerProvider);
    final controller = ref.read(attendeeControllerProvider.notifier);
    final tokens = JolTokens.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'you',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/gallery'),
                child: const Text('Open widget gallery'),
              ),
              const JolThemeButton(),
            ],
          ),
          const SizedBox(height: 18),
          const _ProfileHeaderCard(),
          const SizedBox(height: 14),
          JolCard(
            child: JolListRow(
              title: 'Student status',
              subtitle: state.isStudentVerified
                  ? 'Verified · ${state.studentEmail}'
                  : 'Not verified',
              trailing: Icon(
                state.isStudentVerified
                    ? Icons.verified_outlined
                    : Icons.school_outlined,
              ),
              onTap: () => context.push('/student-verify'),
            ),
          ),
          const SizedBox(height: 22),
          _ProfileSectionTitle(title: 'privacy'),
          JolCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                Material(
                  color: tokens.surface,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Public profile'),
                    value: state.privacyPublicProfile,
                    onChanged: (value) =>
                        controller.setPrivacy(publicProfile: value),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: tokens.surface,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show me on public guest lists'),
                    value: state.privacyGuestlists,
                    onChanged: (value) =>
                        controller.setPrivacy(guestlists: value),
                  ),
                ),
                const Divider(height: 1),
                Material(
                  color: tokens.surface,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show events I’m attending'),
                    value: state.privacyAttending,
                    onChanged: (value) =>
                        controller.setPrivacy(attending: value),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ProfileSectionTitle(title: 'staff features'),
          JolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Help an organiser at the door.'),
                const SizedBox(height: 12),
                JolButton(
                  label: 'Request staff access',
                  expanded: true,
                  variant: JolButtonVariant.secondary,
                  onPressed: () => context.push('/staff-request'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ProfileSectionTitle(title: 'account'),
          JolCard(
            child: Column(
              children: [
                JolListRow(
                  title: 'Payment methods',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _notConnected(context, 'Payment methods'),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Notifications',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _notConnected(context, 'Notifications'),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Refunds and receipts',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _notConnected(context, 'Refunds and receipts'),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Hosting',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/host'),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Help',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _notConnected(context, 'Help centre'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ProfileSectionTitle(title: 'about'),
          JolCard(
            child: Column(
              children: [
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final info = snapshot.data;
                    return JolListRow(
                      title: 'App version',
                      subtitle: info?.version ?? 'Loading app info',
                      trailing: const Icon(Icons.info_outline),
                    );
                  },
                ),
                const Divider(height: 12),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) => JolListRow(
                    title: 'Build version',
                    subtitle: snapshot.data?.buildNumber ?? 'Loading app info',
                  ),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Legal',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showLegalSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          JolButton(
            label: 'Sign out',
            expanded: true,
            variant: JolButtonVariant.ghost,
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.read(attendeeControllerProvider.notifier).resetSession();
              ref.invalidate(currentUserProvider);
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
    );
  }
}

class HostDashboardScreen extends ConsumerWidget {
  const HostDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final eventsResult = ref.watch(myEventsProvider);
    final hosted = (eventsResult.asData?.value ?? const <HostedEvent>[])
        .where((item) => item.isHost && item.event.isApiBacked)
        .toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming =
        hosted.where((item) => !item.event.date.isBefore(today)).toList()
          ..sort((a, b) => a.event.date.compareTo(b.event.date));
    final next = upcoming.firstOrNull;
    final revenue = hosted.fold<double>(0, (sum, item) => sum + item.ticketRevenue);
    final checkedIn = hosted.fold<int>(0, (sum, item) => sum + item.checkedIn);
    final guests = hosted.fold<int>(
      0,
      (sum, item) => sum + item.goingCount + item.ticketsSold,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('hosting')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myEventsProvider);
          await ref.read(myEventsProvider.future).catchError((_) => <HostedEvent>[]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          children: [
            Text(
              'host dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Create, review and manage the nights you run.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: 18),
            if (eventsResult.isLoading && eventsResult.asData == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (eventsResult.hasError && eventsResult.asData == null)
              JolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your events could not be loaded: ${eventsResult.error}'),
                    TextButton(
                      onPressed: () => ref.invalidate(myEventsProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else ...[
              JolCard(
                child: JolListRow(
                  title: next?.event.title ?? 'No upcoming events',
                  subtitle: next == null
                      ? 'Create your first event below.'
                      : '${formatEventDate(next.event.date)} · '
                            '${next.event.startTime} · ${next.event.venue}',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: next == null
                      ? null
                      : () => context.push('/event/${next.event.id}'),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Guests',
                      value: '$guests',
                      tone: tokens.text,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Checked in',
                      value: '$checkedIn',
                      tone: tokens.text,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Sales',
                      value: formatZar(revenue.round()),
                      tone: tokens.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _ProfileSectionTitle(title: 'your events'),
              if (hosted.isEmpty)
                Text(
                  'Events you create show here.',
                  style: TextStyle(color: tokens.muted),
                ),
              for (final item in hosted) ...[
                _HostedEventCard(item: item),
                const SizedBox(height: 10),
              ],
            ],
            const SizedBox(height: 8),
            JolCard(
              child: Column(
                children: [
                  JolListRow(
                    title: 'Create event',
                    subtitle: 'Publish a new night to Discover',
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const _CreateEventScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 12),
                  JolListRow(
                    title: 'Scan tickets',
                    subtitle: 'Check guests in at the door',
                    trailing: const Icon(Icons.qr_code_2_outlined),
                    onTap: () => context.push('/staff'),
                  ),
                  const Divider(height: 12),
                  JolListRow(
                    title: 'Switch to attendee',
                    trailing: const Icon(Icons.arrow_back),
                    onTap: () {
                      ref
                          .read(attendeeControllerProvider.notifier)
                          .setAccessMode(AppAccessMode.attendee);
                      context.go('/discover');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HostedEventCard extends ConsumerWidget {
  const _HostedEventCard({required this.item});

  final HostedEvent item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final event = item.event;
    return JolCard(
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => context.push('/event/${event.id}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${formatEventDate(event.date)} · ${event.startTime}',
                    style: TextStyle(color: tokens.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.goingCount} RSVPs · ${item.ticketsSold} tickets · '
                    '${item.checkedIn} checked in · '
                    '${formatZar(item.ticketRevenue.round())}',
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Event actions',
            onSelected: (action) async {
              switch (action) {
                case 'guests':
                  await _showGuestsSheet(context, ref, event);
                case 'share':
                  await context.push('/share/${event.id}');
                case 'cancel':
                  await _cancelEvent(context, ref, event);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'guests', child: Text('Guest list')),
              PopupMenuItem(value: 'share', child: Text('Share')),
              PopupMenuItem(value: 'cancel', child: Text('Cancel event')),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showGuestsSheet(
  BuildContext context,
  WidgetRef ref,
  JolEvent event,
) {
  return JolSheet.show<void>(
    context: context,
    title: 'guest list',
    child: FutureBuilder(
      future: ref.read(bookingRepositoryProvider).guests(event.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text('Guest list could not be loaded: ${snapshot.error}');
        }
        final guests = snapshot.data ?? const [];
        if (guests.isEmpty) return const Text('No RSVPs yet.');
        return Column(
          children: [
            for (final guest in guests)
              JolListRow(
                title: guest.name,
                subtitle: guest.plusOnes > 0
                    ? '${guest.status} · +${guest.plusOnes}'
                    : guest.status,
              ),
          ],
        );
      },
    ),
  );
}

Future<void> _cancelEvent(
  BuildContext context,
  WidgetRef ref,
  JolEvent event,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Cancel this event?'),
      content: Text('${event.title} will be removed from Discover.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep it'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Cancel event'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(bookingRepositoryProvider).cancelEvent(event.id);
    ref.invalidate(myEventsProvider);
    ref.invalidate(attendeeEventsProvider);
    if (context.mounted) JolToast.show(context, 'Event cancelled.');
  } on ApiException catch (error) {
    if (context.mounted) JolToast.show(context, error.message);
  }
}

/// Casual hosting: max R250 per ticket and 400 people.
class _CreateEventScreen extends ConsumerStatefulWidget {
  const _CreateEventScreen();

  @override
  ConsumerState<_CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<_CreateEventScreen> {
  static const _categories = ['nightlife', 'fitness', 'networking'];
  static const _maxPrice = 250;
  static const _maxPeople = 400;

  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _ticketName = TextEditingController(text: 'General');
  final _price = TextEditingController();
  final _capacity = TextEditingController();
  var _category = _categories.first;
  DateTime? _date;
  TimeOfDay _start = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 23, minute: 0);
  var _isPrivate = false;
  var _isPaid = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _venue,
      _address,
      _description,
      _ticketName,
      _price,
      _capacity,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  DateTime _at(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Give your event a name.';
    if (_date == null) return 'Pick a date.';
    if (!_at(_date!, _start).isAfter(DateTime.now())) {
      return 'The start time must be in the future.';
    }
    if (_isPaid) {
      final price = int.tryParse(_price.text.trim());
      final capacity = int.tryParse(_capacity.text.trim());
      if (price == null || price < 1) return 'Enter a ticket price.';
      if (price > _maxPrice) return 'Tickets can be at most R$_maxPrice.';
      if (capacity == null || capacity < 1) return 'Enter how many tickets.';
      if (capacity > _maxPeople) return 'You can sell at most $_maxPeople tickets.';
      if (price * capacity > 20000) {
        return 'Lower the price or the number of tickets.';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final start = _at(_date!, _start);
    var end = _at(_date!, _end);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    try {
      await ref
          .read(bookingRepositoryProvider)
          .createEvent(
            title: _title.text.trim(),
            category: _category,
            start: start,
            end: end,
            description: _description.text.trim(),
            venue: _venue.text.trim(),
            address: _address.text.trim(),
            isPrivate: _isPrivate,
            ticketName: _isPaid ? _ticketName.text.trim() : null,
            ticketPrice: _isPaid ? int.parse(_price.text.trim()) : null,
            ticketCapacity: _isPaid ? int.parse(_capacity.text.trim()) : null,
          );
      ref.invalidate(myEventsProvider);
      ref.invalidate(attendeeEventsProvider);
      if (!mounted) return;
      JolToast.show(context, 'Your event is live.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final price = int.tryParse(_price.text.trim()) ?? 0;
    final capacity = int.tryParse(_capacity.text.trim()) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('create event')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Event name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in _categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          JolListRow(
            title: _date == null ? 'Pick a date' : formatEventDate(_date!),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 365)),
                initialDate: _date ?? now,
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          Row(
            children: [
              Expanded(
                child: JolListRow(
                  title: 'Starts ${_start.format(context)}',
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _start,
                    );
                    if (picked != null) setState(() => _start = picked);
                  },
                ),
              ),
              Expanded(
                child: JolListRow(
                  title: 'Ends ${_end.format(context)}',
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _end,
                    );
                    if (picked != null) setState(() => _end = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _venue,
            decoration: const InputDecoration(labelText: 'Venue'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Address',
              helperText: 'End with the area, e.g. "12 Bree St, City Centre"',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'About this event'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Private event'),
            subtitle: const Text('Only people with the invite code can find it'),
            value: _isPrivate,
            onChanged: (value) => setState(() => _isPrivate = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sell tickets'),
            subtitle: const Text('Off means a free RSVP event'),
            value: _isPaid,
            onChanged: (value) => setState(() => _isPaid = value),
          ),
          if (_isPaid) ...[
            TextField(
              controller: _ticketName,
              decoration: const InputDecoration(labelText: 'Ticket name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: 'R ',
                      helperText: 'Up to R$_maxPrice',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tickets',
                      helperText: 'Up to $_maxPeople',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total ticket value: ${formatZar(price * capacity)}',
              style: TextStyle(color: tokens.muted),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          JolButton(
            label: _saving ? 'Publishing…' : 'Publish event',
            expanded: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class StaffDashboardScreen extends ConsumerStatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  ConsumerState<StaffDashboardScreen> createState() =>
      _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends ConsumerState<StaffDashboardScreen> {
  final _code = TextEditingController();
  String? _eventId;
  ScanResult? _result;
  var _checking = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final eventId = _eventId;
    final code = _code.text.trim();
    if (eventId == null || code.isEmpty) return;
    setState(() => _checking = true);
    final result = await ref.read(bookingRepositoryProvider).scanTicket(eventId, code);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
      if (result.success) _code.clear();
    });
    if (result.success) ref.invalidate(myEventsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final eventsResult = ref.watch(myEventsProvider);
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final events = (eventsResult.asData?.value ?? const <HostedEvent>[])
        .where((item) => !item.event.date.isBefore(yesterday))
        .toList()
      ..sort((a, b) => a.event.date.compareTo(b.event.date));
    final selected = events.where((item) => item.event.id == _eventId).firstOrNull ??
        events.firstOrNull;
    _eventId = selected?.event.id;

    return Scaffold(
      appBar: AppBar(title: const Text('staff')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: [
          Text('door staff', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Check tickets for events you host or work at.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          if (eventsResult.isLoading && eventsResult.asData == null)
            const Center(child: CircularProgressIndicator())
          else if (eventsResult.hasError && eventsResult.asData == null)
            Text('Your events could not be loaded: ${eventsResult.error}')
          else if (events.isEmpty)
            const Text(
              'You have no upcoming events to scan. Ask the organiser to add '
              'you as door staff.',
            )
          else ...[
            DropdownButtonFormField<String>(
              value: selected!.event.id,
              decoration: const InputDecoration(labelText: 'Event'),
              items: [
                for (final item in events)
                  DropdownMenuItem(
                    value: item.event.id,
                    child: Text(
                      '${item.event.title} · ${formatEventDate(item.event.date)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                _eventId = value;
                _result = null;
              }),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Checked in',
                    value: '${selected.checkedIn}',
                    tone: tokens.text,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Tickets sold',
                    value: '${selected.ticketsSold}',
                    tone: tokens.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _check(),
              decoration: const InputDecoration(
                labelText: 'Ticket code',
                hintText: 'JOL-XXXXXXXX',
              ),
            ),
            const SizedBox(height: 12),
            JolButton(
              label: _checking ? 'Checking…' : 'Check in',
              expanded: true,
              onPressed: _checking ? null : _check,
            ),
            if (_result != null) ...[
              const SizedBox(height: 18),
              JolCard(
                border: true,
                child: JolListRow(
                  title: _result!.success ? 'Admit' : 'Do not admit',
                  subtitle: [
                    _result!.message,
                    if (_result!.guestName != null) _result!.guestName!,
                  ].join(' · '),
                  trailing: Icon(
                    _result!.success ? Icons.check_circle_outline : Icons.block,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          JolCard(
            child: JolListRow(
              title: 'Switch to attendee',
              trailing: const Icon(Icons.arrow_back),
              onTap: () {
                ref
                    .read(attendeeControllerProvider.notifier)
                    .setAccessMode(AppAccessMode.attendee);
                context.go('/discover');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return JolCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaffRequestScreen extends StatefulWidget {
  const StaffRequestScreen({super.key});

  @override
  State<StaffRequestScreen> createState() => _StaffRequestScreenState();
}

class _StaffRequestScreenState extends State<StaffRequestScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _note = TextEditingController();
  String? _organiser;
  var _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    if (_submitted) {
      return Scaffold(
        appBar: AppBar(title: const Text('staff features')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hourglass_top, size: 52),
                const SizedBox(height: 16),
                Text(
                  'request sent',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text('Waiting for $_organiser to approve you.'),
                const SizedBox(height: 20),
                JolButton(
                  label: 'Done',
                  expanded: true,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('staff features')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'request door staff access',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a verified organiser. They’ll need to approve your request.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: _organiser,
            decoration: const InputDecoration(labelText: 'Organiser'),
            items: const [
              DropdownMenuItem(
                value: 'Kasi Collective',
                child: Text('Kasi Collective'),
              ),
              DropdownMenuItem(
                value: 'Blue Room Live',
                child: Text('Blue Room Live'),
              ),
              DropdownMenuItem(
                value: 'Still Studio',
                child: Text('Still Studio'),
              ),
            ],
            onChanged: (value) => setState(() => _organiser = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Your name'),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile number'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 18),
          JolButton(
            label: 'Send request',
            expanded: true,
            onPressed:
                _organiser == null ||
                    _name.text.trim().isEmpty ||
                    _mobile.text.trim().isEmpty
                ? null
                : () {
                    JolToast.show(
                      context,
                      'Your staff access request is queued for approval.',
                    );
                    setState(() => _submitted = true);
                  },
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: tokens.muted),
      ),
    );
  }
}

void _notConnected(BuildContext context, String feature) {
  JolToast.show(context, '$feature is coming soon.');
}

Future<void> _showLegalSheet(BuildContext context) async {
  await JolSheet.show<void>(
    context: context,
    title: 'legal',
    child: Column(
      children: [
        for (final item in [
          'Terms of service',
          'Privacy policy',
          'Ticket and refund terms',
          'Community guidelines',
          'Open-source licences',
        ])
          JolListRow(
            title: item,
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final url = switch (item) {
                'Terms of service' => 'https://www.jol.app/terms',
                'Privacy policy' => 'https://www.jol.app/privacy',
                'Ticket and refund terms' => 'https://www.jol.app/tickets',
                'Community guidelines' =>
                  'https://www.jol.app/community-guidelines',
                _ => 'https://www.jol.app/licenses',
              };
              Navigator.pop(context);
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (context.mounted) {
                JolToast.show(
                  context,
                  'The legal page is unavailable right now.',
                );
              }
            },
          ),
      ],
    ),
  );
}

class _ProfileHeaderCard extends ConsumerWidget {
  const _ProfileHeaderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final userAsync = ref.watch(currentUserProvider);

    return JolCard(
      child: userAsync.when(
        loading: () => const SizedBox(
          height: 56,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Row(
          children: [
            Expanded(child: Text(error.toString())),
            TextButton(
              onPressed: () => ref.invalidate(currentUserProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
        data: (user) => Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: tokens.surface2,
              backgroundImage: user.avatarUrl != null
                  ? NetworkImage(user.avatarUrl!)
                  : null,
              child: user.avatarUrl == null
                  ? Text(
                      user.initial,
                      style: Theme.of(context).textTheme.titleLarge,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? user.phone ?? '',
                    style: TextStyle(color: tokens.muted),
                  ),
                  if (user.bio != null) ...[
                    const SizedBox(height: 4),
                    Text(user.bio!),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Edit profile',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _EditProfileSheet(user: user),
              ),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});

  final JolUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _bio = TextEditingController(text: widget.user.bio ?? '');
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bio = _bio.text.trim();
      await ref
          .read(profileRepositoryProvider)
          .updateProfile(name: name, bio: bio.isEmpty ? null : bio);
      ref.invalidate(currentUserProvider);
      if (!mounted) return;
      JolToast.show(context, 'Profile updated');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('edit profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          JolButton(
            label: _saving ? 'Saving…' : 'Save',
            expanded: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
