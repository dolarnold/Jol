import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/discover/models/jol_event.dart';
import '../api/api_client.dart';

/// A ticket from GET /my-tickets or a purchase.
@immutable
class JolTicket {
  const JolTicket({
    required this.id,
    required this.code,
    required this.status,
    required this.guestName,
    this.tierName,
    this.tierPrice = 0,
    this.event,
    this.scannedAt,
    this.ticketPageUrl,
    this.refundStatus,
    this.tableName,
    this.isGroupGuest = false,
  });

  factory JolTicket.fromApi(Map<String, dynamic> json) {
    final event = json['event'];
    final tier = json['ticket_tier'];
    final scannedAt = json['scanned_at'];
    return JolTicket(
      id: '${json['id']}',
      code: json['ticket_code'] as String? ?? '',
      status: json['status'] as String? ?? 'pending_payment',
      guestName: json['guest_name'] as String? ?? '',
      tierName: tier is Map ? tier['name'] as String? : null,
      tierPrice: tier is Map && tier['price'] is num
          ? (tier['price'] as num).round()
          : 0,
      event: event is Map && event['start_time'] is String
          ? JolEvent.fromApi(Map<String, dynamic>.from(event))
          : null,
      scannedAt: scannedAt is String
          ? DateTime.tryParse(scannedAt)?.toLocal()
          : null,
      ticketPageUrl: json['ticket_page_url'] as String?,
      refundStatus: json['refund_request'] is Map
          ? (json['refund_request'] as Map)['status'] as String?
          : null,
      tableName: json['table_name'] as String?,
      isGroupGuest: json['lead_ticket_id'] != null,
    );
  }

  /// The table, for a table booking.
  final String? tableName;

  /// One of the other tickets of a group deal or table (not the buyer's).
  final bool isGroupGuest;

  final String id;
  final String code;

  /// pending_payment, valid, used, refunded or cancelled.
  final String status;
  final String guestName;
  final String? tierName;
  final int tierPrice;
  final JolEvent? event;
  final DateTime? scannedAt;

  /// Printable ticket page (QR code, save as PDF, add to calendar).
  final String? ticketPageUrl;

  /// pending, approved or declined when a refund was asked for.
  final String? refundStatus;

  bool get isValid => status == 'valid';
  bool get isUsed => status == 'used';
  bool get isPending => status == 'pending_payment';
}

/// One of the signed-in user's RSVPs, from GET /my-rsvps.
@immutable
class JolRsvp {
  const JolRsvp({
    required this.id,
    required this.status,
    required this.plusOnes,
    required this.event,
  });

  final String id;
  final String status;
  final int plusOnes;
  final JolEvent event;
}

/// An event the signed-in user hosts or works at, from GET /my-events.
@immutable
class HostedEvent {
  const HostedEvent({
    required this.event,
    required this.role,
    required this.goingCount,
    required this.ticketsSold,
    required this.checkedIn,
    required this.ticketRevenue,
    this.guestsCheckedIn = 0,
  });

  final JolEvent event;

  /// "host" or "staff".
  final String role;
  final int goingCount;
  final int ticketsSold;
  /// Tickets let in at the door.
  final int checkedIn;
  final double ticketRevenue;

  /// RSVP guests let in from the door guest list (plus-ones included).
  final int guestsCheckedIn;

  bool get isHost => role == 'host';
}

@immutable
class ScanResult {
  const ScanResult({
    required this.success,
    required this.message,
    this.guestName,
    this.requiresIdCheck = false,
  });

  final bool success;
  final String message;
  final String? guestName;

  /// 18+ event: door staff must check the guest's ID before letting them in.
  final bool requiresIdCheck;
}

enum PurchaseOutcome { success, pending, declined }

@immutable
class PurchaseResult {
  const PurchaseResult({
    required this.outcome,
    required this.completed,
    required this.requested,
    this.message,
  });

  final PurchaseOutcome outcome;
  final int completed;
  final int requested;
  final String? message;
}

final bookingRepositoryProvider = Provider<BookingRepository>(
  (ref) => BookingRepository(ref.watch(apiClientProvider)),
);

final myTicketsProvider = FutureProvider<List<JolTicket>>(
  (ref) => ref.watch(bookingRepositoryProvider).myTickets(),
);

final myRsvpsProvider = FutureProvider<List<JolRsvp>>(
  (ref) => ref.watch(bookingRepositoryProvider).myRsvps(),
);

/// Unread warnings from the JOL team, shown on the Me tab.
final accountWarningsProvider =
    FutureProvider<List<({String id, String reason, DateTime createdAt})>>(
      (ref) => ref.watch(bookingRepositoryProvider).unreadWarnings(),
    );

final myEventsProvider = FutureProvider<List<HostedEvent>>(
  (ref) => ref.watch(bookingRepositoryProvider).myEvents(),
);

class BookingRepository {
  const BookingRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) {
      throw const ApiException('The server response was not in the expected format.');
    }
    return value
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
  }

  // ---- RSVPs and reports ---------------------------------------------------

  Future<void> rsvp(
    String eventId, {
    String status = 'going',
    int plusOnes = 0,
    String? guestName,
    String? note,
  }) => _call(() async {
    await _dio.post<void>(
      '/events/${Uri.encodeComponent(eventId)}/rsvp',
      data: {
        'status': status,
        'plus_ones': plusOnes,
        if (guestName != null && guestName.trim().isNotEmpty)
          'guest_name': guestName.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  });

  Future<void> report(String eventId, {required String reason, String? details}) =>
      _call(() async {
        await _dio.post<void>(
          '/events/${Uri.encodeComponent(eventId)}/report',
          data: {
            'reason': reason,
            if (details != null && details.trim().isNotEmpty)
              'details': details.trim(),
          },
        );
      });

  Future<List<JolRsvp>> myRsvps() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/my-rsvps');
    return _list(response.data?['data'])
        .where((item) => item['event'] is Map)
        .map((item) {
          final rsvp = Map<String, dynamic>.from(item['rsvp'] as Map);
          return JolRsvp(
            id: '${rsvp['id']}',
            status: rsvp['status'] as String? ?? 'going',
            plusOnes: (rsvp['plus_ones'] as num?)?.toInt() ?? 0,
            event: JolEvent.fromApi(Map<String, dynamic>.from(item['event'] as Map)),
          );
        })
        .toList(growable: false);
  });

  // ---- Tickets -------------------------------------------------------------

  Future<List<JolTicket>> myTickets() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/my-tickets');
    return _list(response.data?['data']).map(JolTicket.fromApi).toList(growable: false);
  });

  /// Buys [quantity] tickets in one purchase (one payment). With the "fake"
  /// gateway the payment is completed through the simulate-payment URL;
  /// Paystack hands back its checkout page, opened with [openCheckout].
  Future<PurchaseResult> purchaseTickets({
    required String eventId,
    required String tierId,
    required int quantity,
    required String guestName,
    required String guestPhone,
    String? promoCode,
    String? tableName,
    bool useCredit = false,
    Future<void> Function(Uri checkoutUrl)? openCheckout,
  }) async {
    // One request for all of them: one payment and one checkout.
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/events/${Uri.encodeComponent(eventId)}/purchase-ticket',
        data: {
          'ticket_tier_id': int.tryParse(tierId) ?? tierId,
          'guest_name': guestName,
          'guest_phone': guestPhone,
          'quantity': quantity,
          'promo_code': ?promoCode,
          'table_name': ?tableName,
          // Paid with JOL credit: no card, the tickets are valid straight away.
          if (useCredit) 'use_credit': true,
        },
      );
      final data = response.data?['data'];
      final payment = data is Map ? data['payment'] : null;
      final checkoutUrl = data is Map ? data['checkout_url'] as String? : null;
      final gateway = payment is Map ? payment['payment_gateway'] as String? : null;
      final ticket = data is Map ? data['ticket'] : null;

      var paid = false;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        // Free or JOL credit: already valid, no payment page.
        paid = ticket is Map && ticket['status'] == 'valid';
      } else if (gateway == 'fake') {
        paid = await _completeFakePayment(checkoutUrl) == 'completed';
      } else {
        // Paystack opens in the browser; the tickets turn valid once it's paid.
        await openCheckout?.call(Uri.parse(checkoutUrl));
      }
      return PurchaseResult(
        outcome: paid ? PurchaseOutcome.success : PurchaseOutcome.pending,
        completed: paid ? quantity : 0,
        requested: quantity,
      );
    } on DioException catch (error) {
      return PurchaseResult(
        outcome: PurchaseOutcome.declined,
        completed: 0,
        requested: quantity,
        message: ApiException.fromDio(error).message,
      );
    }
  }

  Future<String> _completeFakePayment(String checkoutUrl) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(checkoutUrl);
      final data = response.data?['data'];
      final payment = data is Map ? data['payment'] : null;
      return payment is Map ? payment['status'] as String? ?? 'pending' : 'pending';
    } on DioException {
      // Simulation is switched off on this server: leave the ticket pending.
      return 'pending';
    }
  }

  // ---- Hosting -------------------------------------------------------------

  Future<List<HostedEvent>> myEvents() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/my-events');
    return _list(response.data?['data']).map((item) {
      final stats = item['stats'] is Map
          ? Map<String, dynamic>.from(item['stats'] as Map)
          : const <String, dynamic>{};
      int count(String key) => (stats[key] as num?)?.toInt() ?? 0;
      return HostedEvent(
        event: JolEvent.fromApi(
          Map<String, dynamic>.from(item['event'] as Map),
          attending: count('going_count'),
        ),
        role: item['role'] as String? ?? 'host',
        goingCount: count('going_count'),
        ticketsSold: count('tickets_sold'),
        checkedIn: count('checked_in'),
        ticketRevenue: (stats['ticket_revenue'] as num?)?.toDouble() ?? 0,
        guestsCheckedIn: count('guests_checked_in'),
      );
    }).toList(growable: false);
  });

  /// Host or staff only: GET /events/{id}/guests.
  Future<List<({String name, String status, int plusOnes})>> guests(
    String eventId,
  ) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/guests',
    );
    final data = response.data?['data'];
    return _list(data is Map ? data['all_rsvps'] : null)
        .map(
          (rsvp) => (
            name: rsvp['guest_name'] as String? ?? 'Guest',
            status: rsvp['status'] as String? ?? 'going',
            plusOnes: (rsvp['plus_ones'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false);
  });

  /// Sends a ticket to another JOL account by email or mobile number.
  /// Returns the recipient's name.
  Future<String?> transferTicket(String ticketId, String recipient) =>
      _call(() async {
        final response = await _dio.post<Map<String, dynamic>>(
          '/tickets/${Uri.encodeComponent(ticketId)}/transfer',
          data: {'recipient': recipient.trim()},
        );
        final data = response.data?['data'];
        return data is Map ? data['recipient_name'] as String? : null;
      });

  /// "Contact organiser": JOL relays the message so emails stay private.
  Future<void> contactOrganiser(
    String eventId, {
    required String topic,
    required String body,
  }) => _call(() async {
    await _dio.post<void>(
      '/events/${Uri.encodeComponent(eventId)}/contact',
      data: {'topic': topic, 'body': body.trim()},
    );
  });

  Future<void> requestToPromote(String eventId, {String? message}) =>
      _call(() async {
        await _dio.post<void>(
          '/events/${Uri.encodeComponent(eventId)}/promote-request',
          data: {
            if (message != null && message.trim().isNotEmpty)
              'message': message.trim(),
          },
        );
      });

  /// Asks to scan tickets at the event with [inviteCode]. Returns its title.
  Future<String> requestStaffAccess({
    required String inviteCode,
    required String name,
    required String phone,
    String? note,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/staff-requests',
      data: {
        'invite_code': inviteCode.trim(),
        'name': name.trim(),
        'phone': phone.trim(),
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    final data = response.data?['data'];
    final request = data is Map ? data['staff_request'] : null;
    final event = request is Map ? request['event'] : null;
    return event is Map ? event['title'] as String? ?? 'the event' : 'the event';
  });

  Future<List<({String id, String reason, DateTime createdAt})>>
  unreadWarnings() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/account/warnings');
    return _list(response.data?['data'])
        .where((item) => item['acknowledged'] != true)
        .map(
          (item) => (
            id: '${item['id']}',
            reason: item['reason'] as String? ?? '',
            createdAt:
                DateTime.tryParse('${item['created_at']}')?.toLocal() ??
                DateTime.now(),
          ),
        )
        .toList(growable: false);
  });

  Future<void> acknowledgeWarning(String id) => _call(() async {
    await _dio.post<void>(
      '/account/warnings/${Uri.encodeComponent(id)}/acknowledge',
    );
  });

  Future<void> cancelEvent(String eventId) => _call(() async {
    await _dio.delete<void>('/events/${Uri.encodeComponent(eventId)}');
  });

  // ---- Door scanning -------------------------------------------------------

  Future<ScanResult> scanTicket(String eventId, String code) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/events/${Uri.encodeComponent(eventId)}/scan-ticket',
        data: {'ticket_code': code.trim()},
      );
      final data = response.data?['data'];
      final ticket = data is Map ? data['ticket'] : null;
      return ScanResult(
        success: true,
        message: 'Ticket verified',
        guestName: ticket is Map ? ticket['guest_name'] as String? : null,
        requiresIdCheck: data is Map && data['requires_id_check'] == true,
      );
    } on DioException catch (error) {
      final data = error.response?.data;
      final ticket = data is Map && data['data'] is Map ? data['data']['ticket'] : null;
      return ScanResult(
        success: false,
        message: ApiException.fromDio(error).message,
        guestName: ticket is Map ? ticket['guest_name'] as String? : null,
      );
    }
  }

  // ---- Promo codes, waitlists, refunds, following, reviews ----

  /// Checks a promo code. Returns the price with it applied.
  Future<PromoQuote> checkPromo({
    required String eventId,
    required String tierId,
    required String code,
  }) => _call(() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/promo-check',
      data: {'ticket_tier_id': int.tryParse(tierId) ?? tierId, 'code': code},
    );
    final data = Map<String, dynamic>.from(response.data?['data'] as Map);
    return PromoQuote(
      code: '${data['code']}',
      label: '${data['label']}',
      amount: (data['amount'] as num).toDouble(),
      discount: (data['discount'] as num).toDouble(),
    );
  });

  Future<String> joinWaitlist(String eventId, String tierId) =>
      _message(() => _dio.post<Map<String, dynamic>>(
        '/events/${Uri.encodeComponent(eventId)}/waitlist',
        data: {'ticket_tier_id': int.tryParse(tierId) ?? tierId},
      ));

  Future<String> requestRefund(String ticketId, String reason) =>
      _message(() => _dio.post<Map<String, dynamic>>(
        '/tickets/${Uri.encodeComponent(ticketId)}/refund-request',
        data: {'reason': reason},
      ));

  /// Asks the JOL team to step in on a payment (cancelled event, not let in,
  /// charged twice…). While it's open, the host isn't paid for that sale.
  Future<String> reportPaymentProblem(
    String ticketId, {
    required String reason,
    required String details,
  }) =>
      _message(() => _dio.post<Map<String, dynamic>>(
        '/tickets/${Uri.encodeComponent(ticketId)}/dispute',
        data: {'reason': reason, 'details': details},
      ));

  Future<String> setFollowing(String hostId, {required bool follow}) =>
      _message(() => follow
          ? _dio.post<Map<String, dynamic>>('/hosts/$hostId/follow')
          : _dio.delete<Map<String, dynamic>>('/hosts/$hostId/follow'));

  Future<String> rateEvent(String eventId, int rating, String? comment) =>
      _message(() => _dio.post<Map<String, dynamic>>(
        '/events/${Uri.encodeComponent(eventId)}/reviews',
        data: {
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        },
      ));

  Future<String> _message(
    Future<Response<Map<String, dynamic>>> Function() request,
  ) => _call(() async {
    final response = await request();
    return '${response.data?['message'] ?? 'Done.'}';
  });
}

/// The last checkout, for the payment result screen.
final lastPurchaseProvider =
    NotifierProvider<LastPurchaseNotifier, PurchaseResult?>(
      LastPurchaseNotifier.new,
    );

/// Remembers the last checkout so the payment result screen can describe it.
class LastPurchaseNotifier extends Notifier<PurchaseResult?> {
  @override
  PurchaseResult? build() => null;

  void set(PurchaseResult? result) => state = result;

}

@immutable
class PromoQuote {
  const PromoQuote({
    required this.code,
    required this.label,
    required this.amount,
    required this.discount,
  });

  final String code;
  final String label;

  /// Price of one ticket with the code applied.
  final double amount;
  final double discount;
}
