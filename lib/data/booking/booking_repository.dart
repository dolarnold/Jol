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
    );
  }

  final String id;
  final String code;

  /// pending_payment, valid, used, refunded or cancelled.
  final String status;
  final String guestName;
  final String? tierName;
  final int tierPrice;
  final JolEvent? event;
  final DateTime? scannedAt;

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
  });

  final JolEvent event;

  /// "host" or "staff".
  final String role;
  final int goingCount;
  final int ticketsSold;
  final int checkedIn;
  final double ticketRevenue;

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

  /// Buys [quantity] tickets one at a time (the API creates one ticket per
  /// purchase). With the "fake" gateway the payment is completed through the
  /// simulate-payment URL; any other gateway hands back its checkout page.
  Future<PurchaseResult> purchaseTickets({
    required String eventId,
    required String tierId,
    required int quantity,
    required String guestName,
    required String guestPhone,
    Future<void> Function(Uri checkoutUrl)? openCheckout,
  }) async {
    var completed = 0;
    var pending = 0;
    String? lastError;
    for (var index = 0; index < quantity; index++) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          '/events/${Uri.encodeComponent(eventId)}/purchase-ticket',
          data: {
            'ticket_tier_id': int.tryParse(tierId) ?? tierId,
            'guest_name': guestName,
            'guest_phone': guestPhone,
          },
        );
        final data = response.data?['data'];
        final payment = data is Map ? data['payment'] : null;
        final checkoutUrl = data is Map ? data['checkout_url'] as String? : null;
        final gateway = payment is Map ? payment['payment_gateway'] as String? : null;

        final ticket = data is Map ? data['ticket'] : null;
        if (checkoutUrl == null) {
          // Free tickets come back already valid, with no payment.
          ticket is Map && ticket['status'] == 'valid' ? completed++ : pending++;
        } else if (gateway == 'fake') {
          final status = await _completeFakePayment(checkoutUrl);
          status == 'completed' ? completed++ : pending++;
        } else {
          pending++;
          await openCheckout?.call(Uri.parse(checkoutUrl));
          break; // A real gateway checkout has to finish before buying more.
        }
      } on DioException catch (error) {
        lastError = ApiException.fromDio(error).message;
        if (completed == 0 && pending == 0) {
          return PurchaseResult(
            outcome: PurchaseOutcome.declined,
            completed: 0,
            requested: quantity,
            message: lastError,
          );
        }
        break;
      }
    }
    return PurchaseResult(
      outcome: completed > 0 ? PurchaseOutcome.success : PurchaseOutcome.pending,
      completed: completed,
      requested: quantity,
      message: lastError,
    );
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
}

/// Remembers the last checkout so the payment result screen can describe it.
class LastPurchaseNotifier extends Notifier<PurchaseResult?> {
  @override
  PurchaseResult? build() => null;

  void set(PurchaseResult? result) => state = result;
}

final lastPurchaseProvider =
    NotifierProvider<LastPurchaseNotifier, PurchaseResult?>(
      LastPurchaseNotifier.new,
    );
