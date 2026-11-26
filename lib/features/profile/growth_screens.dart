import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/api/api_client.dart';
import '../../ui/theme/jol_theme.dart';
import '../../ui/widgets/jol_button.dart';
import '../../ui/widgets/jol_card.dart';
import '../../ui/widgets/jol_toast.dart';
import '../inbox/inbox_screens.dart';

/// Help articles, JOL credit (gift cards, invites) and the language for
/// emails and web pages.
class GrowthRepository {
  const GrowthRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<HelpContent> help() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/help');
    final data = response.data?['data'];
    return HelpContent(
      articles: [
        if (data is List)
          for (final item in data)
            if (item is Map)
              HelpArticle(
                audience: '${item['audience']}',
                question: '${item['question']}',
                answer: '${item['answer']}',
              ),
      ],
      contactEmail: response.data?['contact_email'] as String? ?? '',
    );
  });

  Future<CreditWallet> wallet() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/credit');
    final data = Map<String, dynamic>.from(response.data?['data'] as Map? ?? {});
    final entries = data['entries'];
    return CreditWallet(
      balance: (data['balance'] as num?)?.toDouble() ?? 0,
      inviteCode: data['invite_code'] as String? ?? '',
      inviteReward: (data['invite_reward'] as num?)?.toDouble() ?? 0,
      invited: data['invited_by'] == true,
      entries: [
        if (entries is List)
          for (final item in entries)
            if (item is Map)
              CreditLine(
                amount: (item['amount'] as num?)?.toDouble() ?? 0,
                description: '${item['description']}',
                at: DateTime.tryParse('${item['created_at']}')?.toLocal(),
              ),
      ],
    );
  });

  Future<String> _message(String path, Map<String, dynamic> body) =>
      _call(() async {
        final response = await _dio.post<Map<String, dynamic>>(path, data: body);
        return response.data?['message'] as String? ?? 'Done.';
      });

  Future<String> redeemGiftCard(String code) =>
      _message('/credit/gift-cards', {'code': code});

  Future<String> claimInvite(String code) =>
      _message('/credit/invite', {'code': code});

  Future<void> setLocale(String locale) => _call(() async {
    await _dio.put<void>('/me/locale', data: {'locale': locale});
  });
}

final growthRepositoryProvider = Provider<GrowthRepository>(
  (ref) => GrowthRepository(ref.watch(apiClientProvider)),
);

final helpProvider = FutureProvider<HelpContent>(
  (ref) => ref.watch(growthRepositoryProvider).help(),
);

final creditWalletProvider = FutureProvider<CreditWallet>(
  (ref) => ref.watch(growthRepositoryProvider).wallet(),
);

class HelpArticle {
  const HelpArticle({
    required this.audience,
    required this.question,
    required this.answer,
  });

  final String audience;
  final String question;
  final String answer;
}

class HelpContent {
  const HelpContent({required this.articles, required this.contactEmail});

  final List<HelpArticle> articles;
  final String contactEmail;
}

class CreditLine {
  const CreditLine({required this.amount, required this.description, this.at});

  final double amount;
  final String description;
  final DateTime? at;
}

class CreditWallet {
  const CreditWallet({
    required this.balance,
    required this.inviteCode,
    required this.inviteReward,
    required this.invited,
    required this.entries,
  });

  final double balance;
  final String inviteCode;
  final double inviteReward;
  final bool invited;
  final List<CreditLine> entries;
}

String _rand(double value) =>
    'R${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';

/// Me → Help: questions and answers, and a way to reach JOL.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final help = ref.watch(helpProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('help')),
      body: help.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (content) {
          final q = _query.trim().toLowerCase();
          final shown = content.articles
              .where(
                (article) =>
                    q.isEmpty ||
                    '${article.question} ${article.answer}'
                        .toLowerCase()
                        .contains(q),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search, e.g. refund, transfer, payout',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              for (final audience in const ['guests', 'hosts'])
                if (shown.any((article) => article.audience == audience)) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                    child: Text(
                      audience == 'guests' ? 'Going out' : 'Hosting',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: tokens.muted),
                    ),
                  ),
                  JolCard(
                    child: Column(
                      children: [
                        for (final article in shown.where(
                          (article) => article.audience == audience,
                        ))
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(article.question),
                            childrenPadding: const EdgeInsets.only(bottom: 12),
                            expandedAlignment: Alignment.centerLeft,
                            children: [Text(article.answer)],
                          ),
                      ],
                    ),
                  ),
                ],
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No answers match that. Try another word.'),
                ),
              const SizedBox(height: 22),
              JolButton(
                label: 'Message JOL support',
                expanded: true,
                variant: JolButtonVariant.ghost,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SupportMessagesScreen(),
                  ),
                ),
              ),
              if (content.contactEmail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Or email ${content.contactEmail}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tokens.muted),
                ),
              ],
              const SizedBox(height: 22),
              const _LanguagePicker(),
            ],
          );
        },
      ),
    );
  }
}

/// The language JOL's emails and web pages use for this person.
class _LanguagePicker extends ConsumerStatefulWidget {
  const _LanguagePicker();

  @override
  ConsumerState<_LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends ConsumerState<_LanguagePicker> {
  String? _locale;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: _locale,
      decoration: const InputDecoration(
        labelText: 'Language for emails and web pages',
      ),
      items: const [
        DropdownMenuItem(value: 'en', child: Text('English')),
        DropdownMenuItem(value: 'af', child: Text('Afrikaans')),
        DropdownMenuItem(value: 'xh', child: Text('isiXhosa')),
      ],
      onChanged: (value) async {
        if (value == null) return;
        setState(() => _locale = value);
        try {
          await ref.read(growthRepositoryProvider).setLocale(value);
          if (context.mounted) JolToast.show(context, 'Language saved.');
        } on ApiException catch (error) {
          if (context.mounted) JolToast.show(context, error.message);
        }
      },
    );
  }
}

/// Me → JOL credit: balance, gift card codes and invites.
class CreditScreen extends ConsumerStatefulWidget {
  const CreditScreen({super.key});

  @override
  ConsumerState<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends ConsumerState<CreditScreen> {
  final _giftCode = TextEditingController();
  final _inviteCode = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _giftCode.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action, TextEditingController field) async {
    if (field.text.trim().isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      field.clear();
      ref.invalidate(creditWalletProvider);
      if (mounted) JolToast.show(context, message);
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final wallet = ref.watch(creditWalletProvider);
    final repository = ref.read(growthRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('jol credit')),
      body: wallet.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (credit) => RefreshIndicator(
          onRefresh: () => ref.refresh(creditWalletProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              JolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your credit', style: TextStyle(color: tokens.muted)),
                    const SizedBox(height: 4),
                    Text(
                      _rand(credit.balance),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pays for a whole booking: choose Pay with JOL credit at '
                      'checkout. It can’t be paid out as cash.',
                      style: TextStyle(color: tokens.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _giftCode,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Gift card code',
                  hintText: 'JOL-XXXX-XXXX',
                ),
              ),
              const SizedBox(height: 8),
              JolButton(
                label: 'Add to my credit',
                expanded: true,
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => repository.redeemGiftCard(_giftCode.text.trim()),
                        _giftCode,
                      ),
              ),
              const SizedBox(height: 26),
              Text('Invite friends', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                credit.inviteReward > 0
                    ? 'When a friend joins with your code and buys their first '
                          'ticket, you each get ${_rand(credit.inviteReward)} credit.'
                    : 'Share your code so friends can find you on JOL.',
                style: TextStyle(color: tokens.muted),
              ),
              const SizedBox(height: 10),
              JolCard(
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        credit.inviteCode,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: credit.inviteCode));
                        if (context.mounted) JolToast.show(context, 'Copied.');
                      },
                    ),
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.ios_share),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          text: 'Join me on JOL for events in Cape Town. '
                              'Use my invite code ${credit.inviteCode} in Me → JOL credit.',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!credit.invited) ...[
                const SizedBox(height: 18),
                TextField(
                  controller: _inviteCode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Joined because of a friend? Their invite code',
                  ),
                ),
                const SizedBox(height: 8),
                JolButton(
                  label: 'Add invite code',
                  expanded: true,
                  variant: JolButtonVariant.ghost,
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => repository.claimInvite(_inviteCode.text.trim()),
                          _inviteCode,
                        ),
                ),
              ],
              if (credit.entries.isNotEmpty) ...[
                const SizedBox(height: 26),
                Text('History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                for (final line in credit.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(line.description),
                    subtitle: line.at == null
                        ? null
                        : Text(
                            '${line.at!.day}/${line.at!.month}/${line.at!.year}',
                          ),
                    trailing: Text(
                      '${line.amount < 0 ? '−' : '+'}${_rand(line.amount.abs())}',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
