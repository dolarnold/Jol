import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../attendee/state/attendee_controller.dart';
import '../../../data/api/api_client.dart';
import '../../../data/auth/auth_repository.dart';
import '../../../data/auth/privacy_repository.dart';
import '../../../data/auth/profile_repository.dart';
import '../../../data/booking/booking_repository.dart';
import '../../discover/data/event_repository.dart';
import '../../discover/models/jol_event.dart';
import '../../hosting/data/hosting_repository.dart';
import '../../inbox/inbox_screens.dart';
import '../../hosting/screens/event_form_screen.dart';
import '../../hosting/screens/host_mode.dart';
import '../growth_screens.dart';
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
          const _AccountWarningsBanner(),
          const SizedBox(height: 18),
          const _ProfileHeaderCard(),
          const SizedBox(height: 14),
          // One account: switch between going out and hosting.
          const JolModeSwitch(),
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
          _ProfileSectionTitle(title: 'privacy & data'),
          const _PrivacyDataCard(),
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
                  title: 'JOL credit',
                  subtitle: 'Gift cards and invites',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(builder: (_) => const CreditScreen()),
                  ),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Notifications',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
                  ),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Refunds and receipts',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _notConnected(context, 'Refunds and receipts'),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Host details & payouts',
                  subtitle: 'Bank account, ID and business details',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(builder: (_) => const HostProfileScreen()),
                  ),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Help',
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
                  ),
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
    final mode = ref.watch(
      attendeeControllerProvider.select((state) => state.accessMode),
    );
    // Going-out mode: explain hosting and offer the switch.
    if (mode != AppAccessMode.host) return const HostIntroView();
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
    final checkedIn = hosted.fold<int>(0, (sum, item) => sum + item.checkedIn + item.guestsCheckedIn);
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
            const SizedBox(height: 14),
            const JolModeSwitch(),
            const SizedBox(height: 18),
            const HostReadinessCard(),
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
                        builder: (_) => const EventFormScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 12),
                  JolListRow(
                    title: 'Door',
                    subtitle: 'Scan tickets, guest list and door sales',
                    trailing: const Icon(Icons.qr_code_2_outlined),
                    onTap: () => context.push('/staff'),
                  ),
                  const Divider(height: 12),
                  JolListRow(
                    title: 'Host details & payouts',
                    subtitle: 'Bank account, ID and business details',
                    trailing: const Icon(Icons.account_balance_outlined),
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(builder: (_) => const HostProfileScreen()),
                    ),
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
                    [
                      if (event.isDraft) 'DRAFT',
                      if (event.status == 'cancelled') 'CANCELLED',
                      '${formatEventDate(event.date)} · ${event.startTime}',
                    ].join(' · '),
                    style: TextStyle(color: tokens.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.goingCount} RSVPs · ${item.ticketsSold} tickets · '
                    '${item.checkedIn + item.guestsCheckedIn} checked in · '
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
                case 'edit':
                  await Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EventFormScreen(existing: event),
                    ),
                  );
                case 'publish':
                  await _publishEvent(context, ref, event);
                case 'guests':
                  await _showGuestsSheet(context, ref, event);
                case 'door':
                  await context.push('/door/${event.id}');
                case 'share':
                  await context.push('/share/${event.id}');
                case 'repeat':
                  await _repeatEvent(context, ref, event);
                case 'message':
                  await _messageGuests(context, ref, event);
                case 'cancel':
                  await _cancelEvent(context, ref, event);
              }
            },
            itemBuilder: (_) {
              final upcoming = event.date.isAfter(DateTime.now());
              final active = event.status != 'cancelled';
              return [
                if (event.isDraft && upcoming)
                  const PopupMenuItem(value: 'publish', child: Text('Publish')),
                if (upcoming && active)
                  const PopupMenuItem(value: 'edit', child: Text('Edit event')),
                const PopupMenuItem(value: 'guests', child: Text('Guest list')),
                if (!event.isDraft && active)
                  const PopupMenuItem(value: 'door', child: Text('Door: scan, list, sell')),
                if (!event.isDraft)
                  const PopupMenuItem(value: 'share', child: Text('Share')),
                if (active)
                  const PopupMenuItem(value: 'repeat', child: Text('Repeat event')),
                if (!event.isDraft && active)
                  const PopupMenuItem(value: 'message', child: Text('Message guests')),
                if (active)
                  const PopupMenuItem(value: 'cancel', child: Text('Cancel event')),
              ];
            },
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

Future<void> _repeatEvent(
  BuildContext context,
  WidgetRef ref,
  JolEvent event,
) async {
  var frequency = 'weekly';
  var count = 4;
  var publish = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: const Text('Repeat this event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Copies it, with its tickets, to later dates. Each date gets its '
              'own guests and sales.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: frequency,
              decoration: const InputDecoration(labelText: 'How often'),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('Every week')),
                DropdownMenuItem(
                  value: 'fortnightly',
                  child: Text('Every two weeks'),
                ),
                DropdownMenuItem(value: 'monthly', child: Text('Every month')),
              ],
              onChanged: (value) => setState(() => frequency = value ?? frequency),
            ),
            DropdownButtonFormField<int>(
              initialValue: count,
              decoration: const InputDecoration(labelText: 'More dates'),
              items: [
                for (var n = 1; n <= 12; n++)
                  DropdownMenuItem(value: n, child: Text('$n')),
              ],
              onChanged: (value) => setState(() => count = value ?? count),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Publish them now'),
              value: publish,
              onChanged: (value) => setState(() => publish = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add dates'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    final added = await ref
        .read(hostingRepositoryProvider)
        .repeatEvent(event.id, frequency: frequency, count: count, publish: publish);
    ref.invalidate(myEventsProvider);
    if (context.mounted) {
      JolToast.show(
        context,
        publish
            ? 'Added $added dates. They’re live.'
            : 'Added $added dates as drafts.',
      );
    }
  } on ApiException catch (error) {
    if (context.mounted) JolToast.show(context, error.message);
  }
}

Future<void> _messageGuests(
  BuildContext context,
  WidgetRef ref,
  JolEvent event,
) async {
  final subject = TextEditingController();
  final body = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Message guests'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'JOL sends it to everyone coming, in the app and by email. '
              'For updates about this event only.',
            ),
            TextField(
              controller: subject,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
            TextField(
              controller: body,
              maxLength: 2000,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Message'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Send'),
        ),
      ],
    ),
  );
  final subjectText = subject.text.trim();
  final bodyText = body.text.trim();
  if (send != true || !context.mounted) return;
  if (subjectText.isEmpty || bodyText.isEmpty) {
    JolToast.show(context, 'Add a subject and a message.');
    return;
  }
  try {
    final message = await ref
        .read(hostingRepositoryProvider)
        .messageGuests(event.id, subject: subjectText, body: bodyText);
    if (context.mounted) JolToast.show(context, message);
  } on ApiException catch (error) {
    if (context.mounted) JolToast.show(context, error.message);
  }
}

Future<void> _publishEvent(
  BuildContext context,
  WidgetRef ref,
  JolEvent event,
) async {
  try {
    await ref.read(hostingRepositoryProvider).publish(event.id);
    ref.invalidate(myEventsProvider);
    ref.invalidate(attendeeEventsProvider);
    if (context.mounted) JolToast.show(context, 'Your event is live.');
  } on ApiException catch (error) {
    if (context.mounted) JolToast.show(context, error.message);
  }
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

/// Door staff and hosts: pick an event, then open its door (scan tickets,
/// tick guests off the list, sell at the door).
class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final eventsResult = ref.watch(myEventsProvider);
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final events = (eventsResult.asData?.value ?? const <HostedEvent>[])
        .where((item) => !item.event.date.isBefore(yesterday) && item.event.status != 'cancelled')
        .toList()
      ..sort((a, b) => a.event.date.compareTo(b.event.date));

    return Scaffold(
      appBar: AppBar(title: const Text('staff')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myEventsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          children: [
            Text('door', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Scan tickets, tick guests off the list and sell at the door. '
              'Save the list before doors open and it keeps working without signal.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: 18),
            if (eventsResult.isLoading && eventsResult.asData == null)
              const Center(child: CircularProgressIndicator())
            else if (eventsResult.hasError && eventsResult.asData == null)
              Text('Your events could not be loaded: ${eventsResult.error}')
            else if (events.isEmpty)
              const Text(
                'You have no upcoming events. Ask the organiser to add you as '
                'door staff.',
              )
            else
              for (final item in events) ...[
                JolCard(
                  border: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JolListRow(
                        title: item.event.title,
                        subtitle: '${formatEventDate(item.event.date)} · ${item.event.startTime} · '
                            '${item.isHost ? 'Host' : 'Team'}',
                      ),
                      Text(
                        [
                          if (item.ticketsSold > 0) '${item.checkedIn} of ${item.ticketsSold} tickets in',
                          '${item.goingCount} RSVPs',
                          if (item.guestsCheckedIn > 0) '${item.guestsCheckedIn} guests in',
                        ].join(' · '),
                        style: TextStyle(color: tokens.muted),
                      ),
                      const SizedBox(height: 12),
                      JolButton(
                        label: 'Open door',
                        expanded: true,
                        onPressed: () => context.push('/door/${item.event.id}'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 6),
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

/// "Staff features": ask an organiser to let you scan tickets at their event.
/// Sends POST /staff-requests; the host or the JOL team approves.
class StaffRequestScreen extends ConsumerStatefulWidget {
  const StaffRequestScreen({super.key});

  @override
  ConsumerState<StaffRequestScreen> createState() => _StaffRequestScreenState();
}

class _StaffRequestScreenState extends ConsumerState<StaffRequestScreen> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _note = TextEditingController();
  String? _sentFor;
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_code, _name, _mobile, _note]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final title = await ref
          .read(bookingRepositoryProvider)
          .requestStaffAccess(
            inviteCode: _code.text,
            name: _name.text,
            phone: _mobile.text,
            note: _note.text,
          );
      if (mounted) setState(() => _sentFor = title);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    if (_sentFor != null) {
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
                Text(
                  'Waiting for the organiser of $_sentFor to approve you. '
                  'You’ll get a notification when they do.',
                  textAlign: TextAlign.center,
                ),
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
    final ready =
        _code.text.trim().isNotEmpty &&
        _name.text.trim().isNotEmpty &&
        _mobile.text.trim().isNotEmpty;
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
            'Ask the organiser for their event’s invite code. They’ll need '
            'to approve your request before you can scan tickets.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _code,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Event invite code'),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          JolButton(
            label: _sending ? 'Sending…' : 'Send request',
            expanded: true,
            onPressed: !ready || _sending ? null : _send,
          ),
        ],
      ),
    );
  }
}

/// Unread warnings from the JOL team, until the person taps "I understand".
class _AccountWarningsBanner extends ConsumerWidget {
  const _AccountWarningsBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(accountWarningsProvider).asData?.value ?? const [];
    if (warnings.isEmpty) return const SizedBox.shrink();
    final error = Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          for (final warning in warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: JolCard(
                border: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: error),
                        const SizedBox(width: 8),
                        Text(
                          'A warning from the JOL team',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(warning.reason),
                    const SizedBox(height: 4),
                    Text(
                      formatEventDate(warning.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () async {
                          try {
                            await ref
                                .read(bookingRepositoryProvider)
                                .acknowledgeWarning(warning.id);
                            ref.invalidate(accountWarningsProvider);
                          } on ApiException catch (failure) {
                            if (context.mounted) {
                              JolToast.show(context, failure.message);
                            }
                          }
                        },
                        child: const Text('I understand'),
                      ),
                    ),
                  ],
                ),
              ),
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
          'Cookie notice',
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
                'Privacy policy' => '$siteUrl/privacy',
                'Cookie notice' => '$siteUrl/cookies',
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

/// Marketing choice, "email me my data" and account deletion (POPIA).
class _PrivacyDataCard extends ConsumerWidget {
  const _PrivacyDataCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final settings = ref.watch(privacySettingsProvider);

    return JolCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          Material(
            color: tokens.surface,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('News and offers from JOL'),
              subtitle: const Text(
                'Ticket and account messages always reach you.',
              ),
              value: settings.value?.marketingOptIn ?? false,
              onChanged: settings.hasValue
                  ? (value) async {
                      try {
                        await ref
                            .read(privacyRepositoryProvider)
                            .setMarketing(value);
                        ref.invalidate(privacySettingsProvider);
                      } on ApiException catch (error) {
                        if (context.mounted) {
                          JolToast.show(context, error.message);
                        }
                      }
                    }
                  : null,
            ),
          ),
          const Divider(height: 1),
          JolListRow(
            title: 'Email me my data',
            subtitle: 'A download link to everything JOL holds about you',
            trailing: const Icon(Icons.mail_outline),
            onTap: () async {
              try {
                final message = await ref
                    .read(privacyRepositoryProvider)
                    .requestExport();
                if (context.mounted) JolToast.show(context, message);
              } on ApiException catch (error) {
                if (context.mounted) JolToast.show(context, error.message);
              }
            },
          ),
          const Divider(height: 1),
          JolListRow(
            title: 'Delete my account',
            subtitle: 'Removes your details for good',
            trailing: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onTap: settings.hasValue
                ? () => _confirmDeleteAccount(context, ref, settings.value!)
                : null,
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteAccount(
  BuildContext context,
  WidgetRef ref,
  PrivacySettings settings,
) async {
  if (settings.deleteBlockers.isNotEmpty) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not yet'),
        content: Text(settings.deleteBlockers.join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final password = TextEditingController();
  final code = TextEditingController();
  final typed = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your name, email, phone, photo and messages are removed and '
              'you’re signed out. This can’t be undone. Payment records are '
              'kept for 5 years without your name, as tax law requires.',
            ),
            if (settings.upcomingTickets > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Your ${settings.upcomingTickets} upcoming ticket(s) will be '
                'cancelled without a refund. Transfer them first to keep them.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (settings.twoFactorEnabled)
              TextField(
                controller: code,
                decoration: const InputDecoration(
                  labelText: 'Code from your authenticator app',
                ),
              ),
            TextField(
              controller: typed,
              decoration: const InputDecoration(labelText: 'Type DELETE'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            'Delete',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ),
  );

  final passwordText = password.text;
  final codeText = code.text.trim();
  final typedText = typed.text.trim();
  // Not disposed here: the dialog may still be animating closed.
  if (confirmed != true || !context.mounted) return;
  if (typedText != 'DELETE') {
    JolToast.show(context, 'Type DELETE in capitals to confirm.');
    return;
  }

  try {
    await ref
        .read(privacyRepositoryProvider)
        .deleteAccount(
          password: passwordText,
          twoFactorCode: codeText.isEmpty ? null : codeText,
        );
    await ref.read(authRepositoryProvider).logout();
    ref.read(attendeeControllerProvider.notifier).resetSession();
    ref.invalidate(currentUserProvider);
    if (!context.mounted) return;
    JolToast.show(context, 'Your account has been deleted.');
    context.go('/welcome');
  } on ApiException catch (error) {
    if (context.mounted) JolToast.show(context, error.message);
  }
}
