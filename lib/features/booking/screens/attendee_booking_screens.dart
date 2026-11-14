import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/api/api_client.dart';
import '../../../data/auth/profile_repository.dart';
import '../../../data/booking/booking_repository.dart';
import '../../../features/discover/data/event_repository.dart';
import '../../../features/attendee/state/attendee_controller.dart';
import '../../../features/discover/models/jol_event.dart';
import '../../../features/discover/widgets/attendee_components.dart';
import '../../../features/discover/widgets/jol_poster.dart';
import '../../../ui/theme/jol_theme.dart';
import '../../../ui/widgets/jol_button.dart';
import '../../../ui/widgets/jol_card.dart';
import '../../../ui/widgets/jol_list_row.dart';
import '../../../ui/widgets/jol_segmented.dart';
import '../../../ui/widgets/jol_sheet.dart';
import '../../../ui/widgets/jol_toast.dart';
import '../../auth/student_email_validator.dart';

class TicketSelectionScreen extends ConsumerStatefulWidget {
  const TicketSelectionScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketSelectionScreen> createState() =>
      _TicketSelectionScreenState();
}

class _TicketSelectionScreenState extends ConsumerState<TicketSelectionScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(attendeeEventProvider(widget.eventId).future).then((event) {
      if (mounted && event.tiers.isNotEmpty) {
        ref
            .read(attendeeControllerProvider.notifier)
            .setEvent(
              event.id,
              initialTierId: event.tiers
                  .firstWhere(
                    (tier) => !tier.isSoldOut,
                    orElse: () => event.tiers.first,
                  )
                  .id,
            );
      }
    }).ignore();
  }

  @override
  Widget build(BuildContext context) {
    final eventResult = ref.watch(attendeeEventProvider(widget.eventId));
    final gate = _eventGate(
      eventResult,
      title: 'Tickets unavailable',
      message: 'This event could not be found.',
    );
    if (gate != null) return gate;
    final event = eventResult.requireValue;
    if (event.tiers.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const AttendeeEmptyState(
          title: 'Tickets unavailable',
          message: 'Ticket details are not available for this event.',
        ),
      );
    }

    final state = ref.watch(attendeeControllerProvider);
    final controller = ref.read(attendeeControllerProvider.notifier);
    final tokens = JolTokens.of(context);
    final selectedTier = event.tiers.firstWhere(
      (tier) => tier.id == state.selectedTierId,
      orElse: () => event.tiers.firstWhere(
        (tier) => !tier.isSoldOut,
        orElse: () => event.tiers.first,
      ),
    );
    final limit = [
      6,
      ?selectedTier.remaining,
      ?selectedTier.maxPerOrder,
    ].reduce((a, b) => a < b ? a : b).clamp(1, 6);

    return Scaffold(
      appBar: AppBar(title: const Text('choose tickets')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
        children: [
          Text(event.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            '${formatEventDate(event.date)} · ${event.startTime} · ${event.area}',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 22),
          AttendeeSectionTitle('select a ticket'),
          for (final tier in event.tiers) ...[
            _TierTile(
              tier: tier,
              selected: state.selectedTierId == tier.id,
              onTap: tier.isSoldOut
                  ? null
                  : () => controller.selectTier(tier.id),
            ),
            const SizedBox(height: 10),
          ],
          if (selectedTier.isStudent && !state.isStudentVerified)
            JolCard(
              border: true,
              child: Row(
                children: [
                  const Icon(Icons.school_outlined),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Verify your student email to use this ticket.',
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/student-verify'),
                    child: const Text('Verify now'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          JolCard(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Quantity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _QuantityStepper(
                  value: state.quantity.clamp(1, limit),
                  min: 1,
                  max: limit,
                  onChanged: controller.setQuantity,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Ticket money is paid out to the host after the event.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: JolButton(
          label: selectedTier.isStudent && !state.isStudentVerified
              ? 'Verify to continue'
              : selectedTier.price == 0
              ? 'Continue · free'
              : 'Continue · ${formatZar(selectedTier.price * state.quantity.clamp(1, limit))}',
          expanded: true,
          variant: JolButtonVariant.purchase,
          onPressed: selectedTier.isSoldOut
              ? null
              : selectedTier.isStudent && !state.isStudentVerified
              ? () => context.push('/student-verify')
              : () => context.push('/checkout/${event.id}'),
        ),
      ),
    );
  }
}

class _TierTile extends StatelessWidget {
  const _TierTile({
    required this.tier,
    required this.selected,
    required this.onTap,
  });

  final JolTicketTier tier;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label:
          '${tier.name}, ${tier.isSoldOut ? 'sold out' : formatZar(tier.price)}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: JolCard(
          border: selected,
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? tokens.text : tokens.muted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: tier.isSoldOut
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (tier.description.isNotEmpty)
                      Text(
                        tier.description,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: tokens.muted),
                      ),
                    if (tier.remaining != null)
                      Text(
                        '${tier.remaining} left',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: tokens.muted),
                      ),
                  ],
                ),
              ),
              Text(
                tier.isSoldOut ? 'Sold out' : formatZar(tier.price),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tier.isSoldOut ? tokens.muted : tokens.text,
                  decoration: tier.isSoldOut
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Remove one',
          onPressed: value <= min ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value', style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          tooltip: 'Add one',
          onPressed: value >= max ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  Timer? _timer;
  var _secondsRemaining = 8 * 60;
  var _isPaying = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsRemaining > 0 && mounted) {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventResult = ref.watch(attendeeEventProvider(widget.eventId));
    final gate = _eventGate(
      eventResult,
      title: 'Checkout unavailable',
      message: 'This event could not be found.',
    );
    if (gate != null) return gate;
    final event = eventResult.requireValue;
    final state = ref.watch(attendeeControllerProvider);
    final tokens = JolTokens.of(context);
    final tier = event.tiers.firstWhere(
      (item) => item.id == state.selectedTierId,
      orElse: () => event.tiers.first,
    );
    final total = tier.price * state.quantity;
    final minutes = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(title: const Text('checkout')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          JolCard(
            border: true,
            child: Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _secondsRemaining == 0
                        ? 'Ticket hold expired'
                        : 'Your tickets are held for $minutes:$seconds',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AttendeeSectionTitle('order summary'),
          JolCard(
            child: Column(
              children: [
                JolListRow(
                  title: tier.name,
                  subtitle: '${event.title} · ${state.quantity} ticket(s)',
                  trailing: Text(formatZar(total)),
                ),
                const Divider(height: 18),
                JolListRow(
                  title: 'Total',
                  trailing: Text(
                    formatZar(total),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          AttendeeSectionTitle('payment method'),
          JolCard(
            child: Column(
              children: [
                for (final method in ['Card', 'Instant EFT', 'Mobile payment'])
                  Semantics(
                    button: true,
                    selected: state.paymentMethod == method,
                    child: InkWell(
                      onTap: () => ref
                          .read(attendeeControllerProvider.notifier)
                          .setPaymentMethod(method),
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          children: [
                            Icon(
                              state.paymentMethod == method
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Text(method)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your tickets appear in Tickets as soon as payment is confirmed.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: JolButton(
          label: _isPaying
              ? 'Processing…'
              : total == 0
              ? 'Get free tickets'
              : 'Pay ${formatZar(total)}',
          expanded: true,
          variant: JolButtonVariant.purchase,
          onPressed: _isPaying || _secondsRemaining == 0
              ? null
              : () => _pay(event, total),
        ),
      ),
    );
  }

  Future<void> _pay(JolEvent event, int total) async {
    setState(() => _isPaying = true);
    final state = ref.read(attendeeControllerProvider);
    final tier = event.tiers.firstWhere(
      (item) => item.id == state.selectedTierId,
      orElse: () => event.tiers.first,
    );
    PurchaseResult result;
    try {
      final user = await ref.read(currentUserProvider.future);
      final phone = user.phone;
      if (phone == null || phone.isEmpty) {
        throw const ApiException(
          'Add a mobile number to your account before buying tickets.',
        );
      }
      result = await ref
          .read(bookingRepositoryProvider)
          .purchaseTickets(
            eventId: event.id,
            tierId: tier.id,
            quantity: state.quantity,
            guestName: user.name,
            guestPhone: phone,
            openCheckout: (url) =>
                launchUrl(url, mode: LaunchMode.externalApplication),
          );
    } on ApiException catch (error) {
      result = PurchaseResult(
        outcome: PurchaseOutcome.declined,
        completed: 0,
        requested: state.quantity,
        message: error.message,
      );
    }
    if (!mounted) return;
    ref.read(lastPurchaseProvider.notifier).set(result);
    ref
        .read(attendeeControllerProvider.notifier)
        .setPaymentOutcome(switch (result.outcome) {
          PurchaseOutcome.success => MockPaymentOutcome.success,
          PurchaseOutcome.pending => MockPaymentOutcome.pending,
          PurchaseOutcome.declined => MockPaymentOutcome.declined,
        });
    ref.invalidate(myTicketsProvider);
    ref.invalidate(attendeeEventProvider(event.id));
    setState(() => _isPaying = false);
    context.go('/payment-result/${event.id}');
  }
}

class PaymentResultScreen extends ConsumerWidget {
  const PaymentResultScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventResult = ref.watch(attendeeEventProvider(eventId));
    final state = ref.watch(attendeeControllerProvider);
    final purchase = ref.watch(lastPurchaseProvider);
    final tokens = JolTokens.of(context);
    final gate = _eventGate(
      eventResult,
      title: 'Order not found',
      message: 'Return to Discover to choose an event.',
    );
    if (gate != null) return gate;
    final event = eventResult.requireValue;
    final (icon, title, description) = switch (state.paymentOutcome) {
      MockPaymentOutcome.success => (
        Icons.check_circle_outline,
        'you’re in',
        purchase != null && purchase.completed < purchase.requested
            ? '${purchase.completed} of ${purchase.requested} tickets were '
                  'paid. The rest were not charged.'
            : 'Your payment was successful. Your ticket is ready.',
      ),
      MockPaymentOutcome.declined => (
        Icons.credit_card_off_outlined,
        'payment declined',
        purchase?.message ??
            'You haven’t been charged. Try again or use another method.',
      ),
      MockPaymentOutcome.pending => (
        Icons.hourglass_bottom,
        'payment pending',
        'Please don’t pay again. Your ticket shows in Tickets once '
            'the payment is confirmed.',
      ),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(icon, size: 64, color: tokens.text),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: tokens.muted),
              ),
              const SizedBox(height: 24),
              if (state.paymentOutcome == MockPaymentOutcome.success) ...[
                JolButton(
                  label: 'View ticket',
                  expanded: true,
                  onPressed: () => context.go('/ticket/${event.id}'),
                ),
                const SizedBox(height: 10),
                JolButton(
                  label: 'Add to calendar',
                  expanded: true,
                  variant: JolButtonVariant.secondary,
                  onPressed: () => JolToast.show(
                    context,
                    'Calendar details for ${event.title} are ready.',
                  ),
                ),
                const SizedBox(height: 10),
                JolButton(
                  label: 'Share event',
                  expanded: true,
                  variant: JolButtonVariant.ghost,
                  onPressed: () => context.push('/share/${event.id}'),
                ),
              ] else if (state.paymentOutcome ==
                  MockPaymentOutcome.declined) ...[
                JolButton(
                  label: 'Try again',
                  expanded: true,
                  onPressed: () => context.go('/checkout/${event.id}'),
                ),
                const SizedBox(height: 10),
                JolButton(
                  label: 'Use another method',
                  expanded: true,
                  variant: JolButtonVariant.secondary,
                  onPressed: () => context.go('/checkout/${event.id}'),
                ),
              ] else ...[
                JolButton(
                  label: 'View order in Tickets',
                  expanded: true,
                  onPressed: () => context.go('/tickets'),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.go('/discover'),
                child: const Text('Back to Discover'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TicketsScreen extends ConsumerStatefulWidget {
  const TicketsScreen({super.key});

  @override
  ConsumerState<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends ConsumerState<TicketsScreen> {
  var _selectedTab = 'Upcoming';

  @override
  Widget build(BuildContext context) {
    final ticketsResult = ref.watch(myTicketsProvider);
    final rsvpsResult = ref.watch(myRsvpsProvider);
    final tokens = JolTokens.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final tickets = ticketsResult.asData?.value ?? const <JolTicket>[];
    final rsvps = rsvpsResult.asData?.value ?? const <JolRsvp>[];

    // One row per event, counting that event's tickets.
    final ticketItems = <({JolEvent event, String kind, String ticketId})>[];
    final byEvent = <String, List<JolTicket>>{};
    for (final ticket in tickets) {
      final event = ticket.event;
      if (event == null) continue;
      if (ticket.status == 'cancelled' || ticket.status == 'refunded') continue;
      byEvent.putIfAbsent(event.id, () => []).add(ticket);
    }
    for (final group in byEvent.values) {
      final first = group.first;
      final pending = group.where((ticket) => ticket.isPending).length;
      final ready = group.length - pending;
      final tier = first.tierName ?? 'Ticket';
      ticketItems.add((
        event: first.event!,
        kind: ready > 0
            ? '$ready ticket${ready == 1 ? '' : 's'} · $tier'
                  '${pending > 0 ? ' · $pending awaiting payment' : ''}'
            : '$pending awaiting payment · $tier',
        ticketId: first.id,
      ));
    }
    final rsvpItems = [
      for (final rsvp in rsvps)
        (
          event: rsvp.event,
          kind: rsvp.plusOnes > 0 ? 'RSVP · +${rsvp.plusOnes}' : 'RSVP confirmed',
          ticketId: 'rsvp-${rsvp.id}',
        ),
    ];

    bool isPast(JolEvent event) => event.date.isBefore(today);
    final visibleItems = (switch (_selectedTab) {
      'Past' => [...ticketItems, ...rsvpItems].where((i) => isPast(i.event)).toList(),
      'Guestlist' => rsvpItems.where((i) => !isPast(i.event)).toList(),
      _ => [...ticketItems, ...rsvpItems].where((i) => !isPast(i.event)).toList(),
    })..sort((a, b) => a.event.date.compareTo(b.event.date));

    final isLoading =
        (ticketsResult.isLoading && ticketsResult.asData == null) ||
        (rsvpsResult.isLoading && rsvpsResult.asData == null);
    final error = ticketsResult.error ?? rsvpsResult.error;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTicketsProvider);
          ref.invalidate(myRsvpsProvider);
          await ref.read(myTicketsProvider.future).catchError((_) => <JolTicket>[]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
          children: [
            Text('tickets', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Tickets and passes, ready when you are.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: 18),
            JolSegmented(
              options: const ['Upcoming', 'Past', 'Guestlist'],
              selected: _selectedTab,
              onSelectionChanged: (value) => setState(() {
                _selectedTab = value;
              }),
            ),
            const SizedBox(height: 18),
            AttendeeSectionTitle(_selectedTab.toLowerCase()),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null && visibleItems.isEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your tickets could not be loaded: $error'),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(myTicketsProvider);
                      ref.invalidate(myRsvpsProvider);
                    },
                    child: const Text('Try again'),
                  ),
                ],
              )
            else if (visibleItems.isEmpty)
              SizedBox(
                height: 190,
                child: AttendeeEmptyState(
                  title: _selectedTab == 'Guestlist'
                      ? 'No guestlist passes yet'
                      : 'Nothing here yet',
                  message: _selectedTab == 'Guestlist'
                      ? 'Guestlist passes appear here after you join.'
                      : 'Tickets and passes will appear here.',
                ),
              )
            else
              for (final item in visibleItems) ...[
                _TicketListCard(
                  event: item.event,
                  kind: item.kind,
                  ticketId: item.ticketId,
                  onTap: () => context.push('/ticket/${item.event.id}'),
                ),
                const SizedBox(height: 12),
              ],
            AttendeeSectionTitle('need a plan?'),
            JolCard(
              child: JolListRow(
                title: 'Find something for this week',
                subtitle: 'Discover events around Cape Town.',
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => context.go('/discover'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketListCard extends ConsumerWidget {
  const _TicketListCard({
    required this.event,
    required this.kind,
    required this.ticketId,
    required this.onTap,
  });

  final JolEvent event;
  final String kind;
  final String ticketId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(attendeeControllerProvider);
    final transferred = state.transferredTickets.contains(ticketId);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: JolCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            JolPoster(
              style: event.posterStyle,
              primary: Color(event.posterPrimary),
              secondary: Color(event.posterSecondary),
              title: event.title,
              dateStamp: eventDateStamp(event.date),
              imageUrl: event.coverImageUrl,
              size: const Size(82, 100),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatEventDate(event.date).toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontFamily: 'ArchivoExpanded'),
                  ),
                  Text(kind),
                  if (transferred)
                    const Text('Transferred · QR inactive')
                  else
                    Text(
                      'Open ticket',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward),
          ],
        ),
      ),
    );
  }
}

class TicketQrScreen extends ConsumerStatefulWidget {
  const TicketQrScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<TicketQrScreen> createState() => _TicketQrScreenState();
}

class _TicketQrScreenState extends ConsumerState<TicketQrScreen> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final eventResult = ref.watch(attendeeEventProvider(widget.eventId));
    final ticketsResult = ref.watch(myTicketsProvider);
    final rsvps = ref.watch(myRsvpsProvider).asData?.value ?? const <JolRsvp>[];
    final gate = _eventGate(
      eventResult,
      title: 'Ticket unavailable',
      message: 'This ticket is no longer available.',
    );
    if (gate != null) return gate;
    final event = eventResult.requireValue;
    if (ticketsResult.isLoading && ticketsResult.asData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tickets = (ticketsResult.asData?.value ?? const <JolTicket>[])
        .where(
          (ticket) =>
              ticket.event?.id == event.id &&
              (ticket.isValid || ticket.isUsed || ticket.isPending),
        )
        .toList();
    final rsvp = rsvps.where((item) => item.event.id == event.id).firstOrNull;
    final tokens = JolTokens.of(context);
    final index = tickets.isEmpty ? 0 : _index.clamp(0, tickets.length - 1);
    final ticket = tickets.isEmpty ? null : tickets[index];

    return Scaffold(
      appBar: AppBar(title: const Text('your ticket')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myTicketsProvider);
          await ref.read(myTicketsProvider.future).catchError((_) => <JolTicket>[]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            JolPoster(
              style: event.posterStyle,
              primary: Color(event.posterPrimary),
              secondary: Color(event.posterSecondary),
              title: event.title,
              area: event.area,
              dateStamp: eventDateStamp(event.date),
              imageUrl: event.coverImageUrl,
              size: Size(MediaQuery.sizeOf(context).width - 40, 210),
            ),
            const SizedBox(height: 16),
            Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${formatEventDate(event.date)} · ${event.startTime} · ${event.area}',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: tokens.muted),
            ),
            const SizedBox(height: 18),
            JolCard(
              child: ticket == null
                  ? Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        rsvp != null
                            ? 'You’re on the list'
                                  '${rsvp.plusOnes > 0 ? ' with +${rsvp.plusOnes}' : ''}. '
                                  'Give your name at the door.'
                            : 'No ticket for this event on your account.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: [
                        if (ticket.isPending)
                          const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'Awaiting payment. Your QR code appears once the '
                              'payment is confirmed.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        else ...[
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(10),
                            child: QrImageView(
                              data: ticket.code,
                              version: QrVersions.auto,
                              size: 220,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(ticket.code),
                          Text(
                            '${ticket.tierName ?? 'Ticket'} · ${ticket.guestName}',
                          ),
                          Text(
                            'Turn your brightness up at the door.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.muted),
                          ),
                          if (ticket.isUsed) ...[
                            const SizedBox(height: 8),
                            const Text('Checked in'),
                          ],
                        ],
                      ],
                    ),
            ),
            if (ticket != null &&
                event.canTransfer &&
                ticket.isValid) ...[
              const SizedBox(height: 14),
              JolButton(
                label: 'Transfer ticket',
                expanded: true,
                variant: JolButtonVariant.ghost,
                onPressed: () =>
                    _showTransferSheet(context, ref, event, ticket.id),
              ),
            ],
            if (event.isAgeRestricted) ...[
              const SizedBox(height: 14),
              Text(
                '18+ event · bring a valid ID.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (tickets.length > 1) ...[
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous ticket',
                    onPressed: index == 0
                        ? null
                        : () => setState(() => _index = index - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Ticket ${index + 1} of ${tickets.length}'),
                  IconButton(
                    tooltip: 'Next ticket',
                    onPressed: index == tickets.length - 1
                        ? null
                        : () => setState(() => _index = index + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showTransferSheet(
  BuildContext context,
  WidgetRef ref,
  JolEvent event,
  String ticketId,
) async {
  await JolSheet.show<void>(
    context: context,
    title: 'transfer ticket',
    child: _TransferForm(event: event, ticketId: ticketId),
  );
}

class _TransferForm extends ConsumerStatefulWidget {
  const _TransferForm({required this.event, required this.ticketId});

  final JolEvent event;
  final String ticketId;

  @override
  ConsumerState<_TransferForm> createState() => _TransferFormState();
}

/// Sends POST /tickets/{id}/transfer. The ticket moves to the other person's
/// JOL account with a new code, so this phone's QR stops working.
class _TransferFormState extends ConsumerState<_TransferForm> {
  final _recipient = TextEditingController();
  var _sending = false;
  String? _sentTo;
  String? _error;

  @override
  void dispose() {
    _recipient.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final recipient = _recipient.text.trim();
    final looksValid =
        recipient.contains('@') ||
        RegExp(r'^\+?[0-9\s()-]{9,}$').hasMatch(recipient);
    if (!looksValid) {
      setState(() => _error = 'Enter their email or mobile number.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Transfer this ticket?'),
        content: Text(
          'Your ticket to ${widget.event.title} goes to $recipient. '
          'This can’t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final name = await ref
          .read(bookingRepositoryProvider)
          .transferTicket(widget.ticketId, recipient);
      ref.read(attendeeControllerProvider.notifier).transferTicket(widget.ticketId);
      ref.invalidate(myTicketsProvider);
      if (mounted) setState(() => _sentTo = name ?? recipient);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    if (_sentTo != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ticket sent to $_sentTo. It’s in their Tickets tab now.'),
            const SizedBox(height: 8),
            Text(
              'Your QR code no longer works.',
              style: TextStyle(color: tokens.muted),
            ),
            const SizedBox(height: 16),
            JolButton(
              label: 'Done',
              expanded: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Send it to the email or mobile number on their JOL account. '
          'They need to sign up first if they don’t have one.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _recipient,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            labelText: 'Email or mobile number',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'This can’t be undone. Your QR stops working once the ticket is sent.',
          style: TextStyle(color: tokens.muted),
        ),
        const SizedBox(height: 12),
        JolButton(
          label: _sending ? 'Sending…' : 'Transfer ticket',
          expanded: true,
          onPressed: _sending || _recipient.text.trim().isEmpty
              ? null
              : _confirm,
        ),
      ],
    );
  }
}

class FundScreen extends ConsumerStatefulWidget {
  const FundScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends ConsumerState<FundScreen> {
  final _message = TextEditingController();
  final _customAmount = TextEditingController();

  @override
  void dispose() {
    _message.dispose();
    _customAmount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventResult = ref.watch(attendeeEventProvider(widget.eventId));
    final gate = _eventGate(
      eventResult,
      title: 'Contribution unavailable',
      message: 'This event could not be found.',
    );
    if (gate != null) return gate;
    final event = eventResult.requireValue;
    final state = ref.watch(attendeeControllerProvider);
    final controller = ref.read(attendeeControllerProvider.notifier);
    final tokens = JolTokens.of(context);
    final amount = int.tryParse(_customAmount.text) ?? state.contributionAmount;
    final boundedAmount = amount.clamp(1, 200);
    return Scaffold(
      appBar: AppBar(title: const Text('contribute')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            event.fundTitle ?? 'Support this event',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${formatZar(event.fundRaised)} raised of ${formatZar(event.fundGoal)}',
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: event.fundGoal == 0
                  ? 0
                  : (event.fundRaised / event.fundGoal).clamp(0, 1),
              minHeight: 8,
              color: tokens.text,
              backgroundColor: tokens.surface2,
            ),
          ),
          const SizedBox(height: 20),
          AttendeeSectionTitle('choose an amount'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final value in [50, 100, 150, 200])
                ChoiceChip(
                  label: Text(formatZar(value)),
                  selected: state.contributionAmount == value,
                  onSelected: (_) {
                    controller.setContributionAmount(value);
                    _customAmount.clear();
                    setState(() {});
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _customAmount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Other amount',
              prefixText: 'R ',
              helperText: 'Maximum R200',
            ),
            onChanged: (value) {
              final parsed = int.tryParse(value);
              if (parsed != null) controller.setContributionAmount(parsed);
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _message,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Add a message (optional)',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide my name'),
            value: state.contributionAnonymous,
            onChanged: controller.setContributionAnonymous,
          ),
          Text(
            'Contributions go to the host straight away.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          JolButton(
            label: 'Continue · ${formatZar(boundedAmount)}',
            expanded: true,
            variant: JolButtonVariant.purchase,
            onPressed: () {
              controller.setContributionAmount(boundedAmount);
              JolToast.show(
                context,
                'Contributions aren’t available in the app yet.',
              );
            },
          ),
        ],
      ),
    );
  }
}

class ShareEventScreen extends ConsumerWidget {
  const ShareEventScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventResult = ref.watch(attendeeEventProvider(eventId));
    final gate = _eventGate(
      eventResult,
      title: 'Event not found',
      message: 'Return to Discover to share another event.',
    );
    if (gate != null) return gate;
    final event = eventResult.requireValue;
    final shareUrl = event.shareUrl ?? 'https://jol.app/events/${event.id}';
    final shareText =
        '${event.title} · ${formatEventDate(event.date)} · '
        'Cape Town\n$shareUrl';
    return Scaffold(
      appBar: AppBar(title: const Text('share event')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          JolCard(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                JolPoster(
                  style: event.posterStyle,
                  primary: Color(event.posterPrimary),
                  secondary: Color(event.posterSecondary),
                  title: event.title,
                  area: event.area,
                  dateStamp: eventDateStamp(event.date),
                  imageUrl: event.coverImageUrl,
                  size: const Size(100, 126),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('${formatEventDate(event.date)} · ${event.area}'),
                      const SizedBox(height: 6),
                      Text(event.attendanceText),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (final platform in [
            'WhatsApp',
            'Instagram',
            'TikTok',
            'X',
            'Facebook',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: JolCard(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: JolListRow(
                  title: platform,
                  trailing: const Icon(Icons.ios_share),
                  onTap: () => _shareText(context, shareText),
                ),
              ),
            ),
          JolButton(
            label: 'Copy link',
            expanded: true,
            variant: JolButtonVariant.ghost,
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: shareUrl),
              );
              if (context.mounted) JolToast.show(context, 'Event link copied.');
            },
          ),
          const SizedBox(height: 18),
          JolCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'promoter link',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text('Share your link to see clicks and tickets sold.'),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => JolToast.show(
                    context,
                    'Promoter links are not connected in this prototype.',
                  ),
                  child: const Text('Create promoter link'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareText(BuildContext context, String shareText) async {
    await SharePlus.instance.share(ShareParams(text: shareText));
  }
}

class StudentVerificationScreen extends ConsumerStatefulWidget {
  const StudentVerificationScreen({super.key});

  @override
  ConsumerState<StudentVerificationScreen> createState() =>
      _StudentVerificationScreenState();
}

class _StudentVerificationScreenState
    extends ConsumerState<StudentVerificationScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  var _codeSent = false;
  var _error = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(attendeeControllerProvider);
    final tokens = JolTokens.of(context);
    if (state.isStudentVerified) {
      return Scaffold(
        appBar: AppBar(title: const Text('student status')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.school_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'verified',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(state.studentEmail),
                const SizedBox(height: 18),
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
      appBar: AppBar(title: const Text('student verification')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'verify your student status',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _codeSent
                ? 'Enter the 6-digit code sent to ${_email.text.trim()}.'
                : 'Use your university email ending in .ac.za.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 18),
          if (!_codeSent)
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'University email',
                errorText: _error
                    ? "That isn't a student email. Use your university address ending in .ac.za, like name@myuct.ac.za."
                    : null,
              ),
            )
          else
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '6-digit code'),
            ),
          const SizedBox(height: 12),
          JolButton(
            label: _codeSent ? 'Verify code' : 'Send code',
            expanded: true,
            onPressed: () {
              if (!_codeSent) {
                if (!isValidStudentEmail(_email.text)) {
                  setState(() => _error = true);
                  return;
                }
                setState(() {
                  _error = false;
                  _codeSent = true;
                });
                JolToast.show(
                  context,
                  'Verification code sent to ${_email.text.trim()}.',
                );
                return;
              }
              if (_code.text.trim().length != 6) {
                JolToast.show(context, 'Enter the 6-digit code.');
                return;
              }
              if (!_code.text.trim().contains(RegExp(r'^\d{6}$'))) {
                JolToast.show(context, 'Enter the 6-digit code.');
                return;
              }

              ref
                  .read(attendeeControllerProvider.notifier)
                  .verifyStudent(_email.text);
              JolToast.show(context, 'Student verification complete.');
            },
          ),
          if (_codeSent) ...[
            TextButton(
              onPressed: () {
                JolToast.show(
                  context,
                  'A fresh verification code has been sent to ${_email.text.trim()}.',
                );
              },
              child: const Text('Send a new code'),
            ),
            TextButton(
              onPressed: () => setState(() => _codeSent = false),
              child: const Text('Change email'),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Your student email is used only for verification.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: tokens.muted),
          ),
        ],
      ),
    );
  }
}

/// Loading / error screen while an event loads from the API, or null once
/// the event is available.
Widget? _eventGate(
  AsyncValue<JolEvent> result, {
  required String title,
  required String message,
}) {
  if (result.asData != null) return null;
  if (result.isLoading) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
  return Scaffold(
    appBar: AppBar(),
    body: AttendeeEmptyState(
      title: title,
      message: result.hasError ? result.error.toString() : message,
    ),
  );
}
