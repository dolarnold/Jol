import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/api/api_client.dart';
import '../../../data/auth/privacy_repository.dart';
import '../../../data/auth/profile_repository.dart';
import '../../../ui/theme/jol_theme.dart';
import '../../../ui/widgets/jol_button.dart';
import '../../../ui/widgets/jol_card.dart';
import '../../../ui/widgets/jol_list_row.dart';
import '../../../ui/widgets/jol_toast.dart';
import '../../attendee/state/attendee_controller.dart';

/// Guest | Host: one account, two ways of using the app.
class JolModeSwitch extends ConsumerWidget {
  const JolModeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      attendeeControllerProvider.select((state) => state.accessMode),
    );
    final hosting = mode == AppAccessMode.host;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        key: const ValueKey('mode-switch'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.local_activity_outlined),
            label: Text('Going out'),
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.event_available_outlined),
            label: Text('Hosting'),
          ),
        ],
        selected: {hosting},
        onSelectionChanged: (selection) =>
            switchMode(context, ref, host: selection.first),
      ),
    );
  }

  static void switchMode(BuildContext context, WidgetRef ref, {required bool host}) {
    HapticFeedback.selectionClick();
    ref
        .read(attendeeControllerProvider.notifier)
        .setAccessMode(host ? AppAccessMode.host : AppAccessMode.attendee);
    context.go(host ? '/host' : '/discover');
  }
}

/// The Host tab while in "going out" mode: what hosting is, and the switch.
class HostIntroView extends ConsumerWidget {
  const HostIntroView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('hosting')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
        children: [
          Text('host on jol', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Same account, a different view: make events, sell tickets, run '
            'the door and get paid. Switch back any time.',
            style: theme.textTheme.bodyLarge?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 20),
          for (final (icon, text) in const [
            (Icons.add_circle_outline, 'Create a night in a few minutes, free or ticketed'),
            (Icons.qr_code_scanner, 'Scan tickets at the door, even without signal'),
            (Icons.groups_outlined, 'Add co-hosts and door staff'),
            (Icons.account_balance_outlined, 'Ticket money paid to your bank the day after'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(icon, color: tokens.text),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          JolButton(
            label: 'Switch to hosting',
            expanded: true,
            onPressed: () => JolModeSwitch.switchMode(context, ref, host: true),
          ),
          const SizedBox(height: 10),
          Text(
            'Big ticketed events (concerts, festivals, clubs) are set up on the '
            'JOL website by commercial hosts.',
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

/// On the host dashboard: what's still needed before ticket money can be paid out.
class HostReadinessCard extends ConsumerWidget {
  const HostReadinessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    if (user == null) return const SizedBox.shrink();
    final identity = ref.watch(identityCheckProvider).asData?.value;
    final tokens = JolTokens.of(context);
    final steps = [
      if (identity?.needsAction ?? false) 'Verify your identity (2 minutes)',
      ...user.payoutSteps,
    ];
    final waiting = steps.isEmpty && !user.kycVerified;
    if (steps.isEmpty && user.kycVerified && !user.payoutsHeld) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: JolCard(
        border: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.payoutsHeld
                  ? 'Payouts are on hold'
                  : waiting
                  ? 'Your details are being checked'
                  : 'Before you sell tickets',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              user.payoutsHeld
                  ? 'The JOL team is checking a change to your account. Ticket sales carry on; payouts wait.'
                  : waiting
                  ? 'The JOL team checks your ID and bank details, usually within a working day.'
                  : 'Free events work now. To be paid for tickets, finish these:',
              style: TextStyle(color: tokens.muted),
            ),
            for (final step in steps) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.radio_button_unchecked, size: 18, color: tokens.muted),
                  const SizedBox(width: 8),
                  Text(step),
                ],
              ),
            ],
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 12),
              JolButton(
                label: 'Complete host details',
                expanded: true,
                variant: JolButtonVariant.secondary,
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(builder: (_) => const HostProfileScreen()),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Host details and payouts: business details, bank account and the documents
/// the JOL team checks before paying out. Matches PUT/POST /auth/profile.
class HostProfileScreen extends ConsumerStatefulWidget {
  const HostProfileScreen({super.key});

  @override
  ConsumerState<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends ConsumerState<HostProfileScreen> {
  // Same list as the website (config/payout.php), with each bank's universal branch code.
  static const _banks = {
    'ABSA': '632005',
    'Capitec': '470010',
    'Discovery Bank': '679000',
    'First National Bank': '250655',
    'Investec': '580105',
    'Nedbank': '198765',
    'Standard Bank': '051001',
    'TymeBank': '678910',
  };
  static const _accountTypes = {
    'cheque': 'Cheque / current',
    'savings': 'Savings',
    'transmission': 'Transmission',
  };

  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _businessName = TextEditingController();
  final _vat = TextEditingController();
  final _address = TextEditingController();
  final _accountNumber = TextEditingController();
  final _branchCode = TextEditingController();
  String? _bankName;
  String? _accountType;
  PickedDocument? _idDocument;
  PickedDocument? _bankStatement;
  var _loaded = false;
  var _saving = false;
  var _sendingEmail = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_phone, _businessName, _vat, _address, _accountNumber, _branchCode]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(JolUser user) {
    if (_loaded) return;
    _loaded = true;
    _phone.text = user.phone ?? '';
    _businessName.text = user.businessName ?? '';
    _vat.text = user.vatNumber ?? '';
    _address.text = user.businessAddress ?? '';
    _bankName = _banks.containsKey(user.bank?.bankName) ? user.bank?.bankName : null;
    _accountType = _accountTypes.containsKey(user.bank?.accountType) ? user.bank?.accountType : null;
    _branchCode.text = user.bank?.branchCode ?? '';
  }

  Future<void> _pick(bool idDocument) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Choose a file (PDF or image)'),
              subtitle: const Text('e.g. a statement downloaded from your banking app'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    PickedDocument? document;
    try {
      if (choice == 'file') {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        );
        final file = files.firstOrNull;
        if (file != null) {
          document = PickedDocument(name: file.name, bytes: await file.readAsBytes());
        }
      } else {
        final photo = await ImagePicker().pickImage(
          source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2400,
          imageQuality: 85,
        );
        if (photo != null) {
          document = PickedDocument(name: photo.name, bytes: await photo.readAsBytes());
        }
      }
    } catch (_) {
      if (mounted) JolToast.show(context, 'Couldn’t open that file. Try another one.');
      return;
    }
    if (document == null || !mounted) return;
    if (document.tooBig) {
      JolToast.show(context, 'That file is over 4 MB. Try a photo or a smaller PDF.');
      return;
    }
    setState(() {
      if (idDocument) {
        _idDocument = document;
      } else {
        _bankStatement = document;
      }
    });
  }

  Future<void> _save(JolUser user) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final addingBank = user.bank == null && _accountNumber.text.trim().isNotEmpty;
    try {
      final phone = _phone.text.replaceAll(' ', '').trim();
      await ref.read(profileRepositoryProvider).updateHostProfile(
        phone: phone.isEmpty || phone == user.phone
            ? null
            : phone.startsWith('0')
            ? '+27${phone.substring(1)}'
            : phone,
        businessName: _businessName.text.trim(),
        vatNumber: _vat.text.replaceAll(' ', '').trim(),
        businessAddress: _address.text.trim(),
        bankDetails: addingBank
            ? {
                'bank_name': _bankName!,
                'account_type': _accountType!,
                'account_number': _accountNumber.text.replaceAll(' ', '').trim(),
                'branch_code': _branchCode.text.trim(),
              }
            : null,
        idDocument: _idDocument,
        bankStatement: _bankStatement,
      );
      ref.invalidate(currentUserProvider);
      if (!mounted) return;
      JolToast.show(context, 'Host details saved.');
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendVerification() async {
    setState(() => _sendingEmail = true);
    try {
      final message = await ref.read(profileRepositoryProvider).sendEmailVerification();
      if (mounted) JolToast.show(context, message);
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userResult = ref.watch(currentUserProvider);
    final tokens = JolTokens.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('host details & payouts')),
      body: userResult.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Couldn’t load your details: $error')),
        data: (user) {
          _fill(user);
          final bankLocked = user.bank != null;
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Text(
                  'Ticket money is paid into this account the day after each event. '
                  'The JOL team checks your ID and bank statement first.',
                  style: TextStyle(color: tokens.muted),
                ),
                const SizedBox(height: 18),
                _Section('account'),
                JolCard(
                  child: JolListRow(
                    title: user.email ?? 'No email',
                    subtitle: user.emailVerified ? 'Email verified' : 'Email not verified yet',
                    trailing: user.emailVerified
                        ? const Icon(Icons.verified_outlined)
                        : TextButton(
                            onPressed: _sendingEmail ? null : _sendVerification,
                            child: const Text('Send link'),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile number',
                    hintText: '082 123 4567',
                  ),
                  validator: (value) {
                    final digits = (value ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
                    if (digits.isEmpty) return 'Add a mobile number guests and JOL can reach.';
                    return RegExp(r'^(\+?[1-9]\d{7,14}|0\d{9})$').hasMatch(digits)
                        ? null
                        : 'Enter a valid mobile number.';
                  },
                ),
                const SizedBox(height: 22),
                _Section('business (optional)'),
                Text(
                  'Shown on your payout statements and tax invoices.',
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _businessName,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Business or trading name'),
                ),
                TextFormField(
                  controller: _vat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'VAT number',
                    hintText: '10 digits, starts with 4',
                  ),
                  validator: (value) {
                    final vat = (value ?? '').replaceAll(' ', '');
                    return vat.isEmpty || RegExp(r'^4\d{9}$').hasMatch(vat)
                        ? null
                        : 'A VAT number is 10 digits and starts with 4.';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Business address'),
                ),
                const SizedBox(height: 12),
                _Section('payout account'),
                if (bankLocked)
                  JolCard(
                    border: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user.bank!.bankName ?? 'Bank'} · ${_accountTypes[user.bank!.accountType] ?? user.bank!.accountType ?? ''}',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text('Account ending ${user.bank!.last4 ?? '••••'} · branch ${user.bank!.branchCode ?? ''}'),
                        const SizedBox(height: 10),
                        Text(
                          'To keep your money safe, changing bank details is done on '
                          'the JOL website with a new bank statement and a code we email you.',
                          style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                        ),
                        TextButton(
                          onPressed: () => launchUrl(
                            Uri.parse('$siteUrl/host/profile'),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: const Text('Change on the website'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _bankName,
                    decoration: const InputDecoration(labelText: 'Bank'),
                    items: [
                      for (final bank in _banks.keys)
                        DropdownMenuItem(value: bank, child: Text(bank)),
                    ],
                    onChanged: (value) => setState(() {
                      _bankName = value;
                      // Universal branch code; the host can still change it.
                      if (value != null) _branchCode.text = _banks[value]!;
                    }),
                    validator: (value) =>
                        value == null && _accountNumber.text.trim().isNotEmpty ? 'Choose your bank.' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _accountType,
                    decoration: const InputDecoration(labelText: 'Account type'),
                    items: [
                      for (final entry in _accountTypes.entries)
                        DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                    ],
                    onChanged: (value) => setState(() => _accountType = value),
                    validator: (value) => value == null && _accountNumber.text.trim().isNotEmpty
                        ? 'Choose the account type.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _accountNumber,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Account number'),
                    validator: (value) {
                      final number = (value ?? '').replaceAll(' ', '');
                      return number.isEmpty || RegExp(r'^\d{6,17}$').hasMatch(number)
                          ? null
                          : 'Account numbers are 6 to 17 digits.';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _branchCode,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Branch code'),
                    validator: (value) {
                      final code = (value ?? '').trim();
                      if (_accountNumber.text.trim().isEmpty) return null;
                      return RegExp(r'^\d{6}$').hasMatch(code) ? null : 'Branch codes are 6 digits.';
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use an account in your own (or your business’s) name.',
                    style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                  ),
                ],
                const SizedBox(height: 22),
                const _IdentitySection(),
                _Section('documents'),
                Text(
                  'Photos or PDFs up to 4 MB. Kept private: only the JOL team can see them.',
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                ),
                const SizedBox(height: 8),
                JolCard(
                  child: Column(
                    children: [
                      _DocumentRow(
                        title: 'ID document or passport',
                        onFile: user.hasIdDocument,
                        picked: _idDocument,
                        onPick: () => _pick(true),
                      ),
                      const Divider(height: 12),
                      _DocumentRow(
                        title: 'Bank statement (last 3 months)',
                        onFile: user.hasBankStatement,
                        picked: _bankStatement,
                        onPick: () => _pick(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  switch (user.kycStatus) {
                    'verified' => 'Checked by the JOL team.',
                    'rejected' => 'The JOL team couldn’t accept your documents. Upload new ones.',
                    _ => user.hasIdDocument ? 'Waiting for the JOL team to check.' : 'A photo of each is fine.',
                  },
                  style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 20),
                JolButton(
                  label: _saving ? 'Saving…' : 'Save',
                  expanded: true,
                  onPressed: _saving ? null : () => _save(user),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.title,
    required this.onFile,
    required this.picked,
    required this.onPick,
  });

  final String title;
  final bool onFile;
  final PickedDocument? picked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => JolListRow(
    title: title,
    subtitle: picked != null
        ? 'Ready to upload: ${picked!.name}'
        : onFile
        ? 'Uploaded'
        : 'Not uploaded yet',
    trailing: TextButton(
      onPressed: onPick,
      child: Text(onFile || picked != null ? 'Replace' : 'Add'),
    ),
  );
}


/// Didit identity check: a quick ID + selfie, or the Home Affairs check when
/// the host receives money. Opens in the browser; the result comes back to JOL.
class _IdentitySection extends ConsumerStatefulWidget {
  const _IdentitySection();

  @override
  ConsumerState<_IdentitySection> createState() => _IdentitySectionState();
}

class _IdentitySectionState extends ConsumerState<_IdentitySection>
    with WidgetsBindingObserver {
  var _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from the browser: check the result.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(identityCheckProvider);
      ref.invalidate(currentUserProvider);
    }
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final url = await ref.read(profileRepositoryProvider).startIdentityCheck();
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(identityCheckProvider).asData?.value;
    if (identity == null || !identity.available) return const SizedBox.shrink();
    final tokens = JolTokens.of(context);
    final homeAffairs = identity.neededLevel == 'dha';
    final (title, text) = identity.verified
        ? ('Identity verified', homeAffairs ? 'Confirmed with Home Affairs.' : 'ID and selfie checked.')
        : switch (identity.status) {
            'in_review' => ('Being checked', 'The JOL team is reviewing your check, usually within a working day.'),
            'declined' => ('Check didn’t go through', 'Try again with a clear photo of your ID in good light.'),
            _ => (
              'Verify your identity',
              homeAffairs
                  ? 'Because you receive ticket money, we confirm your ID with Home Affairs. About 2 minutes.'
                  : 'A quick ID and selfie check. About 2 minutes.',
            ),
          };
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Section('identity'),
          JolCard(
            border: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(identity.verified ? Icons.verified_outlined : Icons.badge_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(text, style: TextStyle(color: tokens.muted)),
                if (identity.needsAction) ...[
                  const SizedBox(height: 12),
                  JolButton(
                    label: _starting ? 'Opening…' : 'Start identity check',
                    expanded: true,
                    onPressed: _starting ? null : _start,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
