import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/api_client.dart';
import '../../ui/theme/jol_theme.dart';
import '../../ui/widgets/jol_button.dart';
import '../../ui/widgets/jol_card.dart';
import '../../ui/widgets/jol_toast.dart';
import '../discover/models/jol_event.dart';
import 'inbox_repository.dart';

String _when(DateTime date) {
  final now = DateTime.now();
  final time =
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return time;
  }
  return '${formatEventDate(date)} · $time';
}

/// Everything the JOL team and hosts sent this person: tickets, refunds,
/// announcements, approvals. Opening it marks them read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Mark read once the list has been shown.
    Future<void>.delayed(const Duration(seconds: 2), () async {
      try {
        await ref.read(inboxRepositoryProvider).markAllRead();
      } on ApiException {
        // Not important enough to bother the person.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final result = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('notifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future).catchError((_) => <AppNotice>[]);
        },
        child: switch (result) {
          AsyncValue(:final value?) when value.isEmpty => ListView(
            children: const [
              Padding(
                padding: EdgeInsets.all(32),
                child: Text('Nothing yet. Updates about your tickets and events show here.', textAlign: TextAlign.center),
              ),
            ],
          ),
          AsyncValue(:final value?) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            itemCount: value.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final notice = value[index];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: notice.eventId == null
                    ? null
                    : () => context.push('/event/${notice.eventId}'),
                child: JolCard(
                  border: !notice.read,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (notice.title != null)
                        Text(notice.title!, style: Theme.of(context).textTheme.titleSmall),
                      Text(notice.message),
                      const SizedBox(height: 6),
                      Text(_when(notice.createdAt), style: TextStyle(color: tokens.muted, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
          AsyncValue(:final error?) => ListView(
            children: [Padding(padding: const EdgeInsets.all(32), child: Text('Couldn’t load notifications: $error'))],
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// Help: a conversation with the JOL team.
class SupportMessagesScreen extends ConsumerStatefulWidget {
  const SupportMessagesScreen({super.key});

  @override
  ConsumerState<SupportMessagesScreen> createState() =>
      _SupportMessagesScreenState();
}

class _SupportMessagesScreenState extends ConsumerState<SupportMessagesScreen> {
  final _text = TextEditingController();
  var _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(inboxRepositoryProvider).send(body);
      _text.clear();
      ref.invalidate(supportMessagesProvider);
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final messages = ref.watch(supportMessagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('help')),
      body: Column(
        children: [
          Expanded(
            child: switch (messages) {
              AsyncValue(:final value?) when value.isEmpty => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Questions about an event, tickets or payouts? Write to the JOL team below.', textAlign: TextAlign.center),
                ),
              ),
              AsyncValue(:final value?) => ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: value.length,
                itemBuilder: (context, index) {
                  final message = value[value.length - 1 - index];
                  final mine = !message.fromJol;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                      decoration: BoxDecoration(
                        color: mine ? tokens.text : tokens.surface2,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!mine)
                            Text('JOL team', style: TextStyle(color: tokens.muted, fontSize: 11)),
                          Text(message.body, style: TextStyle(color: mine ? tokens.background : tokens.text)),
                          const SizedBox(height: 2),
                          Text(
                            _when(message.createdAt),
                            style: TextStyle(color: (mine ? tokens.background : tokens.muted).withValues(alpha: .7), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              AsyncValue(:final error?) => Center(child: Text('Couldn’t load messages: $error')),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Message the JOL team'),
                  ),
                ),
                const SizedBox(width: 8),
                JolButton(label: _sending ? '…' : 'Send', small: true, onPressed: _sending ? null : _send),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
