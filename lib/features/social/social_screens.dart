import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/api/api_client.dart';
import '../../data/auth/profile_repository.dart';
import '../../ui/theme/jol_theme.dart';
import '../../ui/widgets/jol_button.dart';
import '../../ui/widgets/jol_card.dart';
import '../../ui/widgets/jol_toast.dart';
import '../discover/data/event_repository.dart';
import '../discover/models/jol_event.dart';
import '../discover/widgets/attendee_components.dart';
import 'social_repository.dart';

String _ago(DateTime time) {
  final gap = DateTime.now().difference(time);
  if (gap.inMinutes < 1) return 'now';
  if (gap.inHours < 1) return '${gap.inMinutes}m';
  if (gap.inDays < 1) return '${gap.inHours}h';
  return '${gap.inDays}d';
}

String _rand(double amount) =>
    'R${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';

// ---- Friends -----------------------------------------------------------------

/// Your friend code, people to follow back, your friends, and whether friends
/// can see what you're going to.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _code = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _findByCode() async {
    final code = _code.text.trim();
    if (code.length < 4) return;
    setState(() => _busy = true);
    try {
      final person = await ref.read(socialRepositoryProvider).findByCode(code);
      if (!mounted) return;
      _code.clear();
      await showPersonSheet(context, person.id);
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final overview = ref.watch(friendsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('friends')),
      body: overview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AttendeeEmptyState(
          title: 'Couldn’t load your friends',
          message: '$error',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(friendsProvider),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(friendsProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                'Follow each other to see which events your friends are going to.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.muted),
              ),
              const SizedBox(height: 16),
              JolCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('your friend code', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tokens.muted)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            data.friendCode,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 2),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy',
                          icon: const Icon(Icons.copy),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: data.friendCode));
                            if (context.mounted) JolToast.show(context, 'Friend code copied.');
                          },
                        ),
                        IconButton(
                          tooltip: 'Share',
                          icon: const Icon(Icons.ios_share),
                          onPressed: () => SharePlus.instance.share(
                            ShareParams(
                              text: 'Add me on JOL so we can see each other’s plans. My friend code: ${data.friendCode}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _code,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(hintText: 'Friend’s code', isDense: true),
                            onSubmitted: (_) => _findByCode(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        JolButton(label: _busy ? '…' : 'Find', small: true, onPressed: _busy ? null : _findByCode),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Friends can see what I’m going to'),
                subtitle: const Text('Only people you both follow. Never strangers.'),
                value: data.showGoing,
                onChanged: (value) async {
                  try {
                    await ref.read(socialRepositoryProvider).setShowGoing(value);
                    ref.invalidate(friendsProvider);
                  } on ApiException catch (error) {
                    if (context.mounted) JolToast.show(context, error.message);
                  }
                },
              ),
              if (data.followBack.isNotEmpty) ...[
                const SizedBox(height: 8),
                AttendeeSectionTitle('follow back'),
                for (final face in data.followBack) _PersonRow(face: face, action: 'Follow back'),
              ],
              const SizedBox(height: 8),
              AttendeeSectionTitle('friends · ${data.friends.length}'),
              if (data.friends.isEmpty)
                Text(
                  'No friends yet. Share your code, or follow people from an event’s wall.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.muted),
                ),
              for (final face in data.friends) _PersonRow(face: face),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends ConsumerWidget {
  const _PersonRow({required this.face, this.action});

  final JolFriendFace face;
  final String? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: FriendAvatar(face: face, size: 40),
      title: Text(face.name),
      onTap: () => showPersonSheet(context, face.id),
      trailing: action == null
          ? const Icon(Icons.chevron_right)
          : JolButton(
              label: action!,
              small: true,
              onPressed: () async {
                try {
                  final (message, _) = await ref.read(socialRepositoryProvider).follow(face.id);
                  ref.invalidate(friendsProvider);
                  ref.invalidate(attendeeEventsProvider);
                  if (context.mounted) JolToast.show(context, message);
                } on ApiException catch (error) {
                  if (context.mounted) JolToast.show(context, error.message);
                }
              },
            ),
    );
  }
}

/// A person's first name and photo, a follow button, and (for friends) the
/// events they're going to.
Future<void> showPersonSheet(BuildContext context, String personId) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PersonSheet(personId: personId),
    );

class _PersonSheet extends ConsumerStatefulWidget {
  const _PersonSheet({required this.personId});

  final String personId;

  @override
  ConsumerState<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<_PersonSheet> {
  late Future<({PersonCard card, List<({String id, String title, DateTime? start})> goingTo})> _load;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load = ref.read(socialRepositoryProvider).person(widget.personId);
  }

  Future<void> _toggle(PersonCard card) async {
    setState(() => _busy = true);
    try {
      final (message, _) = await ref.read(socialRepositoryProvider).follow(card.id, follow: !card.iFollow);
      ref.invalidate(friendsProvider);
      ref.invalidate(attendeeEventsProvider);
      if (!mounted) return;
      JolToast.show(context, message);
      setState(() => _load = ref.read(socialRepositoryProvider).person(widget.personId));
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: FutureBuilder(
          future: _load,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(padding: const EdgeInsets.all(24), child: Text('${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
            }
            final (:card, :goingTo) = snapshot.requireData;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FriendAvatar(face: card.face, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.name, style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            card.isFriend
                                ? 'Friends on JOL'
                                : card.followsMe
                                ? 'Follows you'
                                : card.isHost
                                ? 'Hosts events on JOL'
                                : 'On JOL',
                            style: TextStyle(color: tokens.muted),
                          ),
                        ],
                      ),
                    ),
                    JolButton(
                      label: card.iFollow ? 'Following' : (card.followsMe ? 'Follow back' : 'Follow'),
                      small: true,
                      variant: card.iFollow ? JolButtonVariant.ghost : JolButtonVariant.primary,
                      onPressed: _busy ? null : () => _toggle(card),
                    ),
                  ],
                ),
                if (card.isFriend) ...[
                  const SizedBox(height: 18),
                  Text('going to', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  if (goingTo.isEmpty)
                    Text('Nothing coming up yet.', style: TextStyle(color: tokens.muted)),
                  for (final event in goingTo)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(event.title),
                      subtitle: event.start == null ? null : Text(formatEventDate(event.start!)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push('/event/${event.id}');
                      },
                    ),
                ] else if (card.iFollow) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Once ${card.name} follows you back you’ll see which events each other is going to.',
                    style: TextStyle(color: tokens.muted),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---- Event wall --------------------------------------------------------------

/// The latest posts on an event page, with a box to post if you're going.
class EventWallSection extends ConsumerWidget {
  const EventWallSection({super.key, required this.event});

  final JolEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final wall = ref.watch(eventWallProvider(event.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AttendeeSectionTitle(
          'the wall',
          trailing: TextButton(
            onPressed: () => context.push('/event/${event.id}/wall'),
            child: const Text('Open'),
          ),
        ),
        wall.when(
          loading: () => const SizedBox(height: 40),
          // Signed out, or a private event: just leave the wall out.
          error: (_, _) => Text(
            'Sign in to see what guests are saying.',
            style: TextStyle(color: tokens.muted),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.posts.isEmpty)
                Text(
                  data.canPost ? 'Be the first to hype this one up.' : 'No posts yet.',
                  style: TextStyle(color: tokens.muted),
                ),
              for (final post in data.posts.take(3)) _WallPostTile(event: event, post: post),
              if (data.canPost) ...[
                const SizedBox(height: 8),
                JolButton(
                  label: 'Write on the wall',
                  variant: JolButtonVariant.ghost,
                  small: true,
                  onPressed: () => context.push('/event/${event.id}/wall'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class EventWallScreen extends ConsumerStatefulWidget {
  const EventWallScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventWallScreen> createState() => _EventWallScreenState();
}

class _EventWallScreenState extends ConsumerState<EventWallScreen> {
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
      await ref.read(socialRepositoryProvider).post(widget.eventId, body);
      _text.clear();
      HapticFeedback.lightImpact();
      ref.invalidate(eventWallProvider(widget.eventId));
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final event = ref.watch(attendeeEventProvider(widget.eventId)).value;
    final wall = ref.watch(eventWallProvider(widget.eventId));
    return Scaffold(
      appBar: AppBar(title: Text(event?.title ?? 'the wall')),
      body: wall.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AttendeeEmptyState(
          title: 'Couldn’t load the wall',
          message: '$error',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(eventWallProvider(widget.eventId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(eventWallProvider(widget.eventId)),
          child: data.posts.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    AttendeeEmptyState(
                      title: 'Nothing yet',
                      message: data.canPost
                          ? 'Say hi, ask about the dress code, or hype it up.'
                          : (data.postProblem ?? 'No posts yet.'),
                    ),
                  ],
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  itemCount: data.posts.length,
                  itemBuilder: (context, index) => event == null
                      ? const SizedBox.shrink()
                      : _WallPostTile(event: event, post: data.posts[index]),
                ),
        ),
      ),
      bottomNavigationBar: wall.value?.canPost == true
          ? SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 8, 8 + MediaQuery.of(context).viewInsets.bottom),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        maxLength: 500,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Say something…', counterText: ''),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Post',
                      onPressed: _sending ? null : _send,
                      icon: Icon(Icons.send, color: tokens.accent),
                    ),
                  ],
                ),
              ),
            )
          : (wall.value?.postProblem == null
                ? null
                : SafeArea(
                    minimum: const EdgeInsets.all(16),
                    child: Text(
                      wall.value!.postProblem!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens.muted),
                    ),
                  )),
    );
  }
}

class _WallPostTile extends ConsumerWidget {
  const _WallPostTile({required this.event, required this.post});

  final JolEvent event;
  final WallPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: post.mine || post.authorIsHost ? null : () => showPersonSheet(context, post.author.id),
            child: FriendAvatar(face: post.author, size: 34),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.author.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (post.authorIsHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: tokens.accent, borderRadius: BorderRadius.circular(6)),
                        child: Text('HOST', style: TextStyle(color: tokens.onAccent, fontSize: 10, fontWeight: FontWeight.w800)),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Text(_ago(post.createdAt), style: TextStyle(color: tokens.muted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(post.body),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_horiz, color: tokens.muted, size: 18),
            onSelected: (action) async {
              final repository = ref.read(socialRepositoryProvider);
              try {
                if (action == 'remove') {
                  await repository.removePost(event.id, post.id);
                  ref.invalidate(eventWallProvider(event.id));
                } else {
                  await repository.reportPost(event.id, post.id);
                  if (context.mounted) JolToast.show(context, 'Reported. The JOL team will look at it.');
                }
              } on ApiException catch (error) {
                if (context.mounted) JolToast.show(context, error.message);
              }
            },
            itemBuilder: (context) => [
              if (post.canRemove) const PopupMenuItem(value: 'remove', child: Text('Remove')),
              if (!post.mine) const PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
    );
  }
}

// ---- Split the cost ----------------------------------------------------------

/// Asks how many ways to split, books for the group, and opens the booking.
Future<void> startSplitBooking(
  BuildContext context,
  WidgetRef ref, {
  required JolEvent event,
  required JolTicketTier tier,
  required int quantity,
  required int total,
  String? promoCode,
  String? tableName,
}) async {
  final people = tier.peoplePerTicket * (tier.isTable ? 1 : quantity);
  final maxShares = people < 2 ? 2 : (people > 10 ? 10 : people);
  var shares = maxShares;
  final chosen = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Split with friends'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We hold the $people ${people == 1 ? 'place' : 'places'} for 24 hours while everyone pays their share. If someone doesn’t pay in time, everyone who paid is refunded in full.'),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  onPressed: shares > 2 ? () => setState(() => shares--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Expanded(
                  child: Text(
                    '$shares ways · ${_rand(total / shares)} each',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: shares < maxShares ? () => setState(() => shares++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, shares), child: const Text('Book and split')),
        ],
      ),
    ),
  );
  if (chosen == null || !context.mounted) return;
  try {
    final user = await ref.read(currentUserProvider.future);
    final phone = user.phone;
    if (phone == null || phone.isEmpty) {
      throw const ApiException('Add a mobile number to your account before booking.');
    }
    final booking = await ref.read(socialRepositoryProvider).createSplit(
      eventId: event.id,
      tierId: tier.id,
      quantity: quantity,
      shares: chosen,
      guestName: user.name,
      guestPhone: phone,
      promoCode: promoCode,
      tableName: tableName,
    );
    if (context.mounted) context.go('/split/${booking.code}');
  } on ApiException catch (error) {
    if (context.mounted) JolToast.show(context, error.message);
  }
}

/// A group booking: who has paid, your share, and the link to send friends.
class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> with WidgetsBindingObserver {
  var _busy = false;

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

  // Back from the card payment page: show the new state.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(splitProvider(widget.code));
  }

  Future<void> _pay(SplitShare share) async {
    setState(() => _busy = true);
    final repository = ref.read(socialRepositoryProvider);
    try {
      final checkout = await repository.payShare(widget.code, share.id);
      if (checkout.gateway == 'fake') {
        await repository.completeTestPayment(checkout.url);
      } else if (checkout.url.isNotEmpty) {
        await launchUrl(Uri.parse(checkout.url), mode: LaunchMode.externalApplication);
      }
      ref.invalidate(splitProvider(widget.code));
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareLink(SplitBooking booking) async {
    final unpaid = booking.shares.where((share) => !share.isPaid).firstOrNull;
    final text =
        'I booked ${booking.eventTitle} for us 🎉 Your share is ${_rand(unpaid?.amount ?? booking.totalAmount / booking.shares.length)}. '
        'Pay it on JOL before ${formatEventDate(booking.expiresAt)}: ${booking.shareUrl}';
    final opened = await launchUrl(
      Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _cancel() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel the group booking?'),
        content: const Text('The places are released and everyone who paid gets a full refund.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel booking')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await ref.read(socialRepositoryProvider).cancelSplit(widget.code);
      ref.invalidate(splitProvider(widget.code));
    } on ApiException catch (error) {
      if (mounted) JolToast.show(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final result = ref.watch(splitProvider(widget.code));
    return Scaffold(
      appBar: AppBar(title: const Text('group booking')),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => '$error'.contains('Unauthenticated')
            ? AttendeeEmptyState(
                title: 'Sign in to pay your share',
                message: 'Log in or create a JOL account, then open the link again.',
                actionLabel: 'Log in',
                onAction: () => context.push('/login'),
              )
            : AttendeeEmptyState(
                title: 'Couldn’t open this booking',
                message: '$error',
                actionLabel: 'Try again',
                onAction: () => ref.invalidate(splitProvider(widget.code)),
              ),
        data: (booking) {
          final mine = booking.myShare;
          final nextUnpaid = booking.shares.where((share) => share.status == 'unpaid').firstOrNull;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(splitProvider(widget.code)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(booking.eventTitle, style: Theme.of(context).textTheme.headlineSmall),
                if (booking.eventStart != null)
                  Text(formatEventDate(booking.eventStart!), style: TextStyle(color: tokens.muted)),
                const SizedBox(height: 4),
                Text(
                  '${booking.tierName}${booking.tableName == null ? '' : ' · ${booking.tableName}'} · ${booking.people} people · ${_rand(booking.totalAmount)}',
                  style: TextStyle(color: tokens.muted),
                ),
                const SizedBox(height: 16),
                JolCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (booking.status) {
                          'complete' => 'Everyone paid. Tickets are in Tickets 🎉',
                          'expired' => 'Time ran out. Everyone who paid is refunded.',
                          'cancelled' => 'Cancelled. Everyone who paid is refunded.',
                          _ => '${booking.paidCount} of ${booking.shares.length} paid',
                        },
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: booking.shares.isEmpty ? 0 : booking.paidCount / booking.shares.length,
                        ),
                      ),
                      if (booking.isOpen) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Places held until ${formatEventDate(booking.expiresAt)}, ${booking.expiresAt.hour.toString().padLeft(2, '0')}:${booking.expiresAt.minute.toString().padLeft(2, '0')}.',
                          style: TextStyle(color: tokens.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final share in booking.shares)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: share.payerName == null
                        ? CircleAvatar(child: Text('${share.position}'))
                        : FriendAvatar(
                            face: JolFriendFace(id: '${share.position}', name: share.payerName!, avatarUrl: share.payerAvatarUrl),
                            size: 40,
                          ),
                    title: Text(share.mine ? 'You' : (share.payerName ?? 'Share ${share.position}')),
                    subtitle: Text(switch (share.status) {
                      'paid' => 'Paid',
                      'pending' => 'Paying now…',
                      'refunded' => 'Refunded',
                      _ => 'Not paid yet',
                    }),
                    trailing: Text(_rand(share.amount), style: Theme.of(context).textTheme.titleMedium),
                  ),
                const SizedBox(height: 16),
                if (booking.isOpen && mine != null && !mine.isPaid)
                  JolButton(
                    label: _busy ? 'Opening…' : 'Pay my share · ${_rand(mine.amount)}',
                    expanded: true,
                    variant: JolButtonVariant.purchase,
                    onPressed: _busy ? null : () => _pay(mine),
                  )
                else if (booking.isOpen && mine == null && nextUnpaid != null)
                  JolButton(
                    label: _busy ? 'Opening…' : 'Pay a share · ${_rand(nextUnpaid.amount)}',
                    expanded: true,
                    variant: JolButtonVariant.purchase,
                    onPressed: _busy ? null : () => _pay(nextUnpaid),
                  ),
                if (booking.isOpen && booking.isOrganiser) ...[
                  const SizedBox(height: 10),
                  JolButton(
                    label: 'Send the link on WhatsApp',
                    expanded: true,
                    variant: JolButtonVariant.secondary,
                    onPressed: () => _shareLink(booking),
                  ),
                  if (nextUnpaid != null && mine?.isPaid == true) ...[
                    const SizedBox(height: 10),
                    JolButton(
                      label: 'Cover a share for a friend',
                      expanded: true,
                      variant: JolButtonVariant.ghost,
                      onPressed: _busy ? null : () => _pay(nextUnpaid),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextButton(onPressed: _cancel, child: const Text('Cancel group booking')),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.verified_user_outlined, size: 18, color: tokens.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your money is held safely by JOL until the event happens.',
                        style: TextStyle(color: tokens.muted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Group bookings you organised or paid a share of.
class MySplitsScreen extends ConsumerWidget {
  const MySplitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final result = ref.watch(mySplitsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('group bookings')),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AttendeeEmptyState(
          title: 'Couldn’t load group bookings',
          message: '$error',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(mySplitsProvider),
        ),
        data: (bookings) => bookings.isEmpty
            ? const AttendeeEmptyState(
                title: 'No group bookings',
                message: 'At checkout, choose “Split with friends” to book for the group and let everyone pay their own share.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  for (final booking in bookings)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(booking.eventTitle),
                      subtitle: Text(
                        switch (booking.status) {
                          'complete' => 'Fully paid',
                          'expired' => 'Expired · refunded',
                          'cancelled' => 'Cancelled · refunded',
                          _ => '${booking.paidCount} of ${booking.shares.length} paid',
                        },
                        style: TextStyle(color: tokens.muted),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/split/${booking.code}'),
                    ),
                ],
              ),
      ),
    );
  }
}

// ---- The vibe: countdown, dress code, playlist, video ----------------------

/// The host's colour, or the app's accent.
Color eventAccent(BuildContext context, JolEvent event) =>
    event.themeColor == null ? JolTokens.of(context).accent : Color(event.themeColor!);

/// Countdown, dress code, playlist and video under the event title.
class EventVibe extends StatefulWidget {
  const EventVibe({super.key, required this.event, this.enabled = true});

  final JolEvent event;
  final bool enabled;

  @override
  State<EventVibe> createState() => _EventVibeState();
}

class _EventVibeState extends State<EventVibe> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? get _countdown {
    final start = widget.event.startsAt ?? widget.event.date;
    final left = start.difference(DateTime.now());
    if (!widget.event.showCountdown || left.isNegative) return null;
    final days = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;
    if (days > 30) return null;
    return [if (days > 0) '${days}d', '${hours}h', if (days == 0) '${minutes}m'].join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final accent = eventAccent(context, event);
    final countdown = _countdown;
    final chips = <Widget>[
      if (countdown != null)
        _VibeChip(icon: Icons.timer_outlined, label: 'Starts in $countdown', color: accent),
      if (event.dressCode != null)
        _VibeChip(icon: Icons.checkroom_outlined, label: event.dressCode!, color: accent),
      if (event.playlistUrl != null)
        _VibeChip(
          icon: Icons.queue_music,
          label: event.playlistService == null || event.playlistService == 'Playlist'
              ? 'Playlist'
              : 'Playlist on ${event.playlistService}',
          color: accent,
          onTap: widget.enabled
              ? () => launchUrl(Uri.parse(event.playlistUrl!), mode: LaunchMode.externalApplication)
              : null,
        ),
      if (event.coverVideoUrl != null)
        _VibeChip(
          icon: Icons.play_circle_outline,
          label: 'Watch the video',
          color: accent,
          onTap: widget.enabled
              ? () => launchUrl(Uri.parse(event.coverVideoUrl!), mode: LaunchMode.externalApplication)
              : null,
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }
}

class _VibeChip extends StatelessWidget {
  const _VibeChip({required this.icon, required this.label, required this.color, this.onTap});

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Material(
      color: color.withValues(alpha: .14),
      shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: .6))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: tokens.text, fontWeight: FontWeight.w600)),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.open_in_new, size: 13, color: tokens.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Polls -------------------------------------------------------------------

/// "What music?" polls: guests going vote, everyone sees results, the host adds.
class PollsSection extends ConsumerWidget {
  const PollsSection({super.key, required this.event});

  final JolEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(eventPollsProvider(event.id));
    final data = result.value;
    if (data == null || (data.polls.isEmpty && !data.canManage)) {
      return const SizedBox.shrink();
    }
    final accent = eventAccent(context, event);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: JolCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AttendeeSectionTitle(
              'polls',
              trailing: data.canManage && data.polls.length < 5
                  ? TextButton(
                      onPressed: () => _addPoll(context, ref),
                      child: const Text('Add poll'),
                    )
                  : null,
            ),
            if (data.polls.isEmpty)
              Text(
                'Ask guests something before the night, like “What music?”.',
                style: TextStyle(color: JolTokens.of(context).muted),
              ),
            for (final poll in data.polls)
              _PollCard(event: event, poll: poll, canVote: data.canVote, canManage: data.canManage, accent: accent),
          ],
        ),
      ),
    );
  }

  Future<void> _addPoll(BuildContext context, WidgetRef ref) async {
    final question = TextEditingController();
    final answers = List.generate(4, (_) => TextEditingController());
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New poll'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: question,
                maxLength: 140,
                decoration: const InputDecoration(labelText: 'Question', hintText: 'What music?'),
              ),
              for (var index = 0; index < answers.length; index++)
                TextField(
                  controller: answers[index],
                  maxLength: 60,
                  decoration: InputDecoration(
                    labelText: 'Answer ${index + 1}${index >= 2 ? ' (optional)' : ''}',
                    counterText: '',
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    final options = answers.map((answer) => answer.text.trim()).where((text) => text.isNotEmpty).toList();
    final text = question.text.trim();
    question.dispose();
    for (final answer in answers) {
      answer.dispose();
    }
    if (saved != true) return;
    if (text.isEmpty || options.length < 2) {
      if (context.mounted) JolToast.show(context, 'Add a question and at least two answers.');
      return;
    }
    try {
      await ref.read(socialRepositoryProvider).createPoll(event.id, text, options);
      ref.invalidate(eventPollsProvider(event.id));
    } on ApiException catch (error) {
      if (context.mounted) JolToast.show(context, error.message);
    }
  }
}

class _PollCard extends ConsumerWidget {
  const _PollCard({
    required this.event,
    required this.poll,
    required this.canVote,
    required this.canManage,
    required this.accent,
  });

  final JolEvent event;
  final EventPoll poll;
  final bool canVote;
  final bool canManage;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final showResults = poll.myVote != null || !poll.isOpen || !canVote;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(poll.question, style: Theme.of(context).textTheme.titleMedium)),
              if (canManage)
                IconButton(
                  tooltip: 'Remove poll',
                  icon: Icon(Icons.delete_outline, size: 18, color: tokens.muted),
                  onPressed: () async {
                    try {
                      await ref.read(socialRepositoryProvider).deletePoll(event.id, poll.id);
                      ref.invalidate(eventPollsProvider(event.id));
                    } on ApiException catch (error) {
                      if (context.mounted) JolToast.show(context, error.message);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < poll.options.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: canVote && poll.isOpen
                    ? () async {
                        HapticFeedback.selectionClick();
                        try {
                          await ref.read(socialRepositoryProvider).vote(event.id, poll.id, index);
                          ref.invalidate(eventPollsProvider(event.id));
                        } on ApiException catch (error) {
                          if (context.mounted) JolToast.show(context, error.message);
                        }
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: poll.myVote == index ? accent : tokens.line),
                  ),
                  child: Stack(
                    children: [
                      if (showResults)
                        Positioned.fill(
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: poll.options[index].percent / 100,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .18),
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Row(
                          children: [
                            if (poll.myVote == index) ...[
                              Icon(Icons.check_circle, size: 16, color: accent),
                              const SizedBox(width: 6),
                            ],
                            Expanded(child: Text(poll.options[index].label)),
                            if (showResults) Text('${poll.options[index].percent}%'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Text(
            [
              '${poll.totalVotes} ${poll.totalVotes == 1 ? 'vote' : 'votes'}',
              if (!poll.isOpen) 'closed',
              if (poll.isOpen && !canVote) 'RSVP or get a ticket to vote',
            ].join(' · '),
            style: TextStyle(color: tokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---- Trust -------------------------------------------------------------------

/// "Your money is protected until the party."
class MoneyProtectedBadge extends StatelessWidget {
  const MoneyProtectedBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    const green = Color(0xFF2E9E6A);
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: green.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: green.withValues(alpha: .45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user, color: green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your money is protected until the party',
                  style: TextStyle(color: tokens.text, fontWeight: FontWeight.w700),
                ),
                if (!compact) ...[
                  const SizedBox(height: 4),
                  Text(
                    'JOL holds ticket money and only pays the host after the event. '
                    'If it’s cancelled, you get a full refund.',
                    style: TextStyle(color: tokens.muted, fontSize: 13),
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

// ---- Shared album ------------------------------------------------------------

/// A strip of album photos on the event page, once doors have opened.
class EventAlbumSection extends ConsumerWidget {
  const EventAlbumSection({super.key, required this.event});

  final JolEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final start = event.startsAt ?? event.date;
    if (start.subtract(const Duration(hours: 1)).isAfter(DateTime.now())) {
      return const SizedBox.shrink();
    }
    final album = ref.watch(eventAlbumProvider(event.id)).value;
    if (album == null || (!album.canSee && album.count == 0)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: JolCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AttendeeSectionTitle(
              'the album · ${album.count}',
              trailing: album.canSee
                  ? TextButton(
                      onPressed: () => context.push('/event/${event.id}/album'),
                      child: const Text('Open'),
                    )
                  : null,
            ),
            if (!album.canSee)
              Text('Photos from the night, for people who went.', style: TextStyle(color: tokens.muted))
            else if (album.photos.isEmpty)
              Text(
                album.canAdd ? 'Add the first photo from the night.' : 'No photos yet.',
                style: TextStyle(color: tokens.muted),
              )
            else
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: album.photos.length > 12 ? 12 : album.photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => context.push('/event/${event.id}/album'),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(album.photos[index].thumbUrl, width: 92, height: 92, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            if (album.canAdd) ...[
              const SizedBox(height: 10),
              JolButton(
                label: 'Add photos',
                small: true,
                variant: JolButtonVariant.ghost,
                onPressed: () => context.push('/event/${event.id}/album'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EventAlbumScreen extends ConsumerStatefulWidget {
  const EventAlbumScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventAlbumScreen> createState() => _EventAlbumScreenState();
}

class _EventAlbumScreenState extends ConsumerState<EventAlbumScreen> {
  var _uploading = 0;

  Future<void> _add() async {
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1600, maxHeight: 1600, imageQuality: 82, limit: 10);
    if (picked.isEmpty || !mounted) return;
    setState(() => _uploading = picked.length);
    final repository = ref.read(socialRepositoryProvider);
    var added = 0;
    for (final file in picked) {
      try {
        await repository.addPhoto(widget.eventId, file.path);
        added++;
      } on ApiException catch (error) {
        if (mounted) JolToast.show(context, error.message);
        break;
      } finally {
        if (mounted) setState(() => _uploading--);
      }
    }
    if (!mounted) return;
    setState(() => _uploading = 0);
    ref.invalidate(eventAlbumProvider(widget.eventId));
    if (added > 0) {
      HapticFeedback.mediumImpact();
      JolToast.show(context, added == 1 ? 'Photo added.' : '$added photos added.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final result = ref.watch(eventAlbumProvider(widget.eventId));
    final event = ref.watch(attendeeEventProvider(widget.eventId)).value;
    final album = result.value;
    return Scaffold(
      appBar: AppBar(title: Text(event == null ? 'the album' : '${event.title} · album')),
      floatingActionButton: album?.canAdd == true
          ? FloatingActionButton.extended(
              onPressed: _uploading > 0 ? null : _add,
              icon: _uploading > 0
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_a_photo_outlined),
              label: Text(_uploading > 0 ? 'Uploading $_uploading…' : 'Add photos'),
            )
          : null,
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AttendeeEmptyState(
          title: 'Couldn’t load the album',
          message: '$error',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(eventAlbumProvider(widget.eventId)),
        ),
        data: (album) => !album.canSee
            ? const AttendeeEmptyState(title: 'For people who went', message: 'Only guests and the host can see this album.')
            : album.photos.isEmpty
            ? AttendeeEmptyState(
                title: 'No photos yet',
                message: album.canAdd ? 'Add your photos from the night.' : (album.addProblem ?? ''),
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(eventAlbumProvider(widget.eventId)),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 96),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
                  itemCount: album.photos.length,
                  itemBuilder: (context, index) {
                    final photo = album.photos[index];
                    return GestureDetector(
                      onTap: () => _open(context, album.photos, index),
                      child: Image.network(
                        photo.thumbUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => ColoredBox(color: tokens.surface2),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }

  void _open(BuildContext context, List<AlbumPhoto> photos, int start) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(eventId: widget.eventId, photos: photos, start: start),
      ),
    );
  }
}

class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({required this.eventId, required this.photos, required this.start});

  final String eventId;
  final List<AlbumPhoto> photos;
  final int start;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.start);
  late var _index = widget.start;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(photo.author.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (action) async {
              final repository = ref.read(socialRepositoryProvider);
              try {
                if (action == 'remove') {
                  await repository.removePhoto(widget.eventId, photo.id);
                  ref.invalidate(eventAlbumProvider(widget.eventId));
                  if (context.mounted) Navigator.of(context).pop();
                } else {
                  await repository.reportPhoto(widget.eventId, photo.id);
                  if (context.mounted) JolToast.show(context, 'Reported. The JOL team will look at it.');
                }
              } on ApiException catch (error) {
                if (context.mounted) JolToast.show(context, error.message);
              }
            },
            itemBuilder: (context) => [
              if (photo.canRemove) const PopupMenuItem(value: 'remove', child: Text('Remove')),
              if (!photo.mine) const PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) => InteractiveViewer(
          child: Center(child: Image.network(widget.photos[index].url, fit: BoxFit.contain)),
        ),
      ),
      bottomNavigationBar: photo.caption == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Text(photo.caption!, style: const TextStyle(color: Colors.white)),
            ),
    );
  }
}

// ---- Memories ----------------------------------------------------------------

/// Your past nights, with points, streak and badges on top.
class MemoriesScreen extends ConsumerWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = JolTokens.of(context);
    final memories = ref.watch(memoriesProvider);
    final achievements = ref.watch(achievementsProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('memories')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(memoriesProvider);
          ref.invalidate(achievementsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (achievements != null) ...[
              Row(
                children: [
                  _Stat(value: '${achievements.points}', label: 'points'),
                  _Stat(value: '${achievements.eventsAttended}', label: 'nights out'),
                  _Stat(
                    value: '${achievements.streakMonths}',
                    label: achievements.streakMonths == 1 ? 'month streak' : 'months streak',
                    icon: achievements.streakMonths >= 2 ? Icons.local_fire_department : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final badge in achievements.badges)
                    Tooltip(
                      message: badge.hint,
                      child: Chip(
                        avatar: Icon(
                          badge.earned ? Icons.emoji_events : Icons.lock_outline,
                          size: 16,
                          color: badge.earned ? tokens.accent : tokens.muted,
                        ),
                        label: Text(badge.label),
                        backgroundColor: badge.earned ? tokens.accent.withValues(alpha: .14) : tokens.surface2,
                        labelStyle: TextStyle(color: badge.earned ? tokens.text : tokens.muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            AttendeeSectionTitle('your nights'),
            ...memories.when(
              loading: () => [const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))],
              error: (error, _) => [Text('$error', style: TextStyle(color: tokens.muted))],
              data: (items) => items.isEmpty
                  ? [
                      Text(
                        'Events you go to show up here, with the photos from each night.',
                        style: TextStyle(color: tokens.muted),
                      ),
                    ]
                  : [
                      for (final memory in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: JolCard(
                            padding: const EdgeInsets.all(10),
                            child: InkWell(
                              onTap: () => context.push(
                                memory.photoCount > 0 ? '/event/${memory.eventId}/album' : '/event/${memory.eventId}',
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: memory.imageUrl == null
                                        ? Container(width: 72, height: 72, color: tokens.surface2, child: Icon(Icons.nightlife, color: tokens.muted))
                                        : Image.network(memory.imageUrl!, width: 72, height: 72, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(memory.title, style: Theme.of(context).textTheme.titleMedium),
                                        Text(
                                          [
                                            if (memory.start != null) formatEventDate(memory.start!),
                                            ?memory.place,
                                          ].join(' · '),
                                          style: TextStyle(color: tokens.muted),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if (memory.photoCount > 0) '${memory.photoCount} ${memory.photoCount == 1 ? 'photo' : 'photos'}',
                                            if (memory.myRating != null) '★' * memory.myRating!,
                                          ].join(' · '),
                                          style: TextStyle(color: tokens.text, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Expanded(
      child: JolCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) Icon(icon, color: tokens.accent, size: 20),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            Text(label, style: TextStyle(color: tokens.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ---- Confetti ----------------------------------------------------------------

/// A one-off burst of confetti over [child] (e.g. when a ticket is booked).
class Confetti extends StatefulWidget {
  const Confetti({super.key, required this.child, this.play = true});

  final Widget child;
  final bool play;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.play) {
      _controller.forward();
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.play)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => _controller.isCompleted
                    ? const SizedBox.shrink()
                    : CustomPaint(painter: _ConfettiPainter(_controller.value)),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);

  final double t;

  static const _colors = [Color(0xFFE8792E), Color(0xFFF2C94C), Color(0xFF7C5CE0), Color(0xFF2E9E6A), Color(0xFFE04F5F), Color(0xFF2F80ED)];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var index = 0; index < 90; index++) {
      // Fixed pseudo-random spread per piece, so each frame is consistent.
      final seed = (index * 9301 + 49297) % 233280 / 233280;
      final seed2 = (index * 4567 + 1234) % 9973 / 9973;
      final x = size.width * (.5 + (seed - .5) * (0.4 + 1.4 * t));
      final y = size.height * (.12 - .3 * seed2 * (1 - t) + 1.1 * t * t + .15 * seed * t);
      final angle = t * 12 * (seed2 + .2) + index;
      paint.color = _colors[index % _colors.length].withValues(alpha: (1 - t).clamp(0, 1).toDouble());
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(angle)
        ..drawRect(const Rect.fromLTWH(-4, -2.5, 8, 5), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

// ---- Wallet passes -----------------------------------------------------------

/// "Add to Apple Wallet" on iPhone, "Save to Google Wallet" on Android, when JOL
/// has them set up. The pass shows the same QR code as the app.
class WalletButtons extends ConsumerWidget {
  const WalletButtons({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(walletLinksProvider(ticketId)).value;
    final url = links == null ? null : (Platform.isIOS ? links.apple : links.google);
    if (url == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: Text(Platform.isIOS ? 'Add to Apple Wallet' : 'Save to Google Wallet'),
          onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        ),
      ),
    );
  }
}
