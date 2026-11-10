import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../attendee/state/attendee_controller.dart';
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
          JolCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: tokens.surface2,
                  child: Text(
                    'L',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lerato Mokoena'),
                      SizedBox(height: 4),
                      Text('@lerato.m'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => JolToast.show(
                    context,
                    'Profile editing is not connected yet.',
                  ),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
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
            onPressed: () {
              ref.read(attendeeControllerProvider.notifier).resetSession();
              context.go('/welcome');
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

    return Scaffold(
      appBar: AppBar(title: const Text('hosting')),
      body: ListView(
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
          JolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_available_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your next event',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Amapiano Sundowner',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'Sat, 14 Nov · 16:00 · The Rooftop',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Guests',
                  value: '214',
                  tone: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Tickets',
                  value: 'R 18.2k',
                  tone: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          JolCard(
            child: Column(
              children: [
                JolListRow(
                  title: 'Create event',
                  subtitle: 'Draft a new night or edit a live listing',
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => JolToast.show(
                    context,
                    'Host creation flow is ready for the next API pass.',
                  ),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Guestlist approvals',
                  subtitle: 'Review names, plus-ones and access requests',
                  trailing: const Icon(Icons.people_alt_outlined),
                  onTap: () => JolToast.show(
                    context,
                    'Guestlist queue is ready for moderation.',
                  ),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Event insights',
                  subtitle: 'Check check-ins, spend and performance',
                  trailing: const Icon(Icons.insights_outlined),
                  onTap: () => JolToast.show(
                    context,
                    'Insights are ready for the next analytics pass.',
                  ),
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
    );
  }
}

class StaffDashboardScreen extends ConsumerWidget {
  const StaffDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('staff')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
        children: [
          Text(
            'door staff',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Review check-ins, scan tickets and help at the door.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          JolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Entry queue',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '18 wait',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Guests currently checked in: 196 / 240',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: tokens.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Checked in',
                  value: '196',
                  tone: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  label: 'Alerts',
                  value: '3',
                  tone: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          JolCard(
            child: Column(
              children: [
                JolListRow(
                  title: 'Pending check-ins',
                  subtitle: '18 people waiting in the queue',
                  trailing: const Icon(Icons.pending_actions_outlined),
                  onTap: () => JolToast.show(
                    context,
                    'Check-in flow is ready for live event data.',
                  ),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Guestlist scan',
                  subtitle: 'Verify guest names and capacity',
                  trailing: const Icon(Icons.fact_check_outlined),
                  onTap: () => JolToast.show(
                    context,
                    'Ticket scanning is ready for the event day.',
                  ),
                ),
                const Divider(height: 12),
                JolListRow(
                  title: 'Gate notes',
                  subtitle: 'Entry rules, plus-one status and access tags',
                  trailing: const Icon(Icons.note_alt_outlined),
                  onTap: () => JolToast.show(
                    context,
                    'Door notes are synced and ready for the team.',
                  ),
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
              } else {
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
