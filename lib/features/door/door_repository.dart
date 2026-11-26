import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/api/api_client.dart';

/// The door of an event: scanning tickets, the guest list and door sales.
///
/// Everything works online through `/events/{id}/door/…`. For venues without
/// signal, [downloadList] saves the event's list on the phone: a salted
/// fingerprint of each ticket code (never the codes), the RSVP guest list and
/// the ticket types. Checks, check-ins and sales made without signal are kept
/// on the phone and sent with [sync]; the server has the final say.
final doorRepositoryProvider = Provider<DoorRepository>(
  (ref) => DoorRepository(ref.watch(apiClientProvider)),
);

class DoorException implements Exception {
  const DoorException(this.message, {this.offline = false});

  final String message;

  /// No signal: the request never reached the server.
  final bool offline;

  factory DoorException.fromDio(DioException error) => DoorException(
    ApiException.fromDio(error).message,
    offline: error.response == null &&
        const {
          DioExceptionType.connectionError,
          DioExceptionType.connectionTimeout,
          DioExceptionType.receiveTimeout,
          DioExceptionType.sendTimeout,
        }.contains(error.type),
  );

  @override
  String toString() => message;
}

/// "JOL-ABCD1234" from a QR code or typed text (also finds it inside a link).
String normalizeTicketCode(String raw) {
  final upper = raw.trim().toUpperCase();
  final match = RegExp(r'JOL-[A-Z0-9]{6,12}').firstMatch(upper);
  if (match != null) return match.group(0)!;
  final compact = upper.replaceAll(RegExp(r'\s+'), '');
  return compact.length > 64 ? compact.substring(0, 64) : compact;
}

int _int(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double _double(Object? value) => value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
DateTime? _date(Object? value) => value == null ? null : DateTime.tryParse('$value')?.toLocal();
Map<String, dynamic> _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _list(Object? value) => value is List
    ? value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
    : <Map<String, dynamic>>[];

/// Totals shown at the top of the door screen.
class DoorSummary {
  DoorSummary({
    this.ticketsSold = 0,
    this.ticketsIn = 0,
    this.guestPeople = 0,
    this.guestsIn = 0,
    this.inside = 0,
    this.doorSalesEnabled = false,
    this.doorSalesCount = 0,
    this.doorSalesTickets = 0,
    this.doorSalesTotal = 0,
    Map<String, double>? byMethod,
  }) : byMethod = byMethod ?? {};

  factory DoorSummary.fromJson(Map<String, dynamic> json) {
    final tickets = _map(json['tickets']);
    final guests = _map(json['guests']);
    final sales = _map(json['door_sales']);
    return DoorSummary(
      ticketsSold: _int(tickets['sold']),
      ticketsIn: _int(tickets['in']),
      guestPeople: _int(guests['people']),
      guestsIn: _int(guests['in']),
      inside: _int(json['inside']),
      doorSalesEnabled: sales['enabled'] == true,
      doorSalesCount: _int(sales['count']),
      doorSalesTickets: _int(sales['tickets']),
      doorSalesTotal: _double(sales['total']),
      byMethod: {
        for (final entry in _map(sales['by_method']).entries) entry.key: _double(entry.value),
      },
    );
  }

  int ticketsSold;
  int ticketsIn;
  int guestPeople;
  int guestsIn;
  int inside;
  bool doorSalesEnabled;
  int doorSalesCount;
  int doorSalesTickets;
  double doorSalesTotal;
  Map<String, double> byMethod;

  Map<String, dynamic> toJson() => {
    'tickets': {'sold': ticketsSold, 'in': ticketsIn},
    'guests': {'people': guestPeople, 'in': guestsIn},
    'inside': inside,
    'door_sales': {
      'enabled': doorSalesEnabled,
      'count': doorSalesCount,
      'tickets': doorSalesTickets,
      'total': doorSalesTotal,
      'by_method': byMethod,
    },
  };
}

/// A ticket type that can be sold at the door.
class DoorTier {
  DoorTier({required this.id, required this.name, required this.price, this.available});

  factory DoorTier.fromJson(Map<String, dynamic> json) => DoorTier(
    id: _int(json['id']),
    name: '${json['name'] ?? 'Ticket'}',
    price: _double(json['price']),
    available: json['available'] == null ? null : _int(json['available']),
  );

  final int id;
  final String name;
  final double price;

  /// Null means no limit.
  int? available;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'price': price, 'available': available};
}

/// Someone on the RSVP guest list.
class DoorGuest {
  DoorGuest({
    required this.id,
    required this.name,
    required this.status,
    required this.party,
    this.checkedInCount = 0,
    this.checkedInAt,
    this.walkIn = false,
    this.phoneEnd,
  });

  factory DoorGuest.fromJson(Map<String, dynamic> json) => DoorGuest(
    id: _int(json['id']),
    name: '${json['name'] ?? 'Guest'}',
    status: '${json['status'] ?? 'going'}',
    party: max(1, _int(json['party'])),
    checkedInCount: _int(json['checked_in_count']),
    checkedInAt: _date(json['checked_in_at']),
    walkIn: json['walk_in'] == true,
    phoneEnd: json['phone_end'] as String?,
  );

  final int id;
  final String name;
  String status;

  /// The guest plus their plus-ones.
  final int party;
  int checkedInCount;
  DateTime? checkedInAt;
  final bool walkIn;

  /// Last digits of their number, to tell two people with the same name apart.
  final String? phoneEnd;

  bool get isIn => checkedInCount > 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'status': status,
    'party': party,
    'checked_in_count': checkedInCount,
    'checked_in_at': checkedInAt?.toUtc().toIso8601String(),
    'walk_in': walkIn,
    'phone_end': phoneEnd,
  };
}

/// A ticket holder found by name (lost or flat phone).
class DoorTicketHolder {
  DoorTicketHolder({required this.id, required this.name, this.tier, required this.status, this.scannedAt});

  factory DoorTicketHolder.fromJson(Map<String, dynamic> json) => DoorTicketHolder(
    id: _int(json['id']),
    name: '${json['name'] ?? 'Ticket holder'}',
    tier: json['tier'] as String?,
    status: '${json['status'] ?? 'valid'}',
    scannedAt: _date(json['scanned_at']),
  );

  final int id;
  final String name;
  final String? tier;
  String status;
  DateTime? scannedAt;
}

/// A sale made at the door.
class DoorSaleRecord {
  const DoorSaleRecord({
    required this.id,
    this.tier,
    required this.quantity,
    required this.total,
    required this.method,
    this.buyerName,
    this.seller,
    this.soldAt,
    this.voided = false,
    this.overCapacity = false,
    this.canUndo = false,
  });

  factory DoorSaleRecord.fromJson(Map<String, dynamic> json) => DoorSaleRecord(
    id: _int(json['id']),
    tier: json['tier'] as String?,
    quantity: _int(json['quantity']),
    total: _double(json['total']),
    method: '${json['payment_method'] ?? 'cash'}',
    buyerName: json['buyer_name'] as String?,
    seller: json['seller'] as String?,
    soldAt: _date(json['sold_at']),
    voided: json['voided'] == true,
    overCapacity: json['over_capacity'] == true,
    canUndo: json['can_undo'] == true,
  );

  final int id;
  final String? tier;
  final int quantity;
  final double total;
  final String method;
  final String? buyerName;
  final String? seller;
  final DateTime? soldAt;
  final bool voided;
  final bool overCapacity;
  final bool canUndo;
}

/// What the door screen loads first.
class DoorInfo {
  DoorInfo({
    required this.title,
    required this.requiresIdCheck,
    required this.ticketed,
    required this.canManage,
    required this.summary,
    required this.tiers,
    required this.methods,
    required this.recentSales,
  });

  factory DoorInfo.fromJson(Map<String, dynamic> json) {
    final event = _map(json['event']);
    return DoorInfo(
      title: '${event['title'] ?? ''}',
      requiresIdCheck: event['requires_id_check'] == true,
      ticketed: event['ticketed'] == true,
      canManage: json['can_manage'] == true,
      summary: DoorSummary.fromJson(_map(json['summary'])),
      tiers: _list(json['tiers']).map(DoorTier.fromJson).toList(),
      methods: {
        for (final entry in _map(json['payment_methods']).entries) entry.key: '${entry.value}',
      },
      recentSales: _list(json['recent_sales']).map(DoorSaleRecord.fromJson).toList(),
    );
  }

  /// No signal when the door opened: work from the list saved on this phone.
  factory DoorInfo.fromList(DoorList list) => DoorInfo(
    title: list.title,
    requiresIdCheck: list.requiresIdCheck,
    ticketed: list.tickets.isNotEmpty || list.tiers.isNotEmpty,
    canManage: false,
    summary: list.summary,
    // Copies: the saved list counts its own sales.
    tiers: [
      for (final tier in list.tiers)
        DoorTier(id: tier.id, name: tier.name, price: tier.price, available: tier.available),
    ],
    methods: const {'cash': 'Cash', 'card': 'Card machine', 'other': 'Other'},
    recentSales: const [],
  );

  final String title;
  final bool requiresIdCheck;
  final bool ticketed;
  final bool canManage;
  DoorSummary summary;
  List<DoorTier> tiers;

  /// cash → "Cash", card → "Card machine", other → "Other (SnapScan, …)".
  final Map<String, String> methods;
  List<DoorSaleRecord> recentSales;
}

/// The answer for one ticket at the door.
class ScanOutcome {
  const ScanOutcome({
    required this.admit,
    required this.message,
    this.guest,
    this.tier,
    this.requiresIdCheck = false,
    this.offline = false,
  });

  factory ScanOutcome.fromJson(Map<String, dynamic> json) => ScanOutcome(
    admit: json['admit'] == true,
    message: '${json['message'] ?? ''}',
    guest: json['guest'] as String?,
    tier: json['tier'] as String?,
    requiresIdCheck: json['requires_id_check'] == true,
  );

  final bool admit;
  final String message;
  final String? guest;
  final String? tier;

  /// 18+ event: check the guest's ID before letting them in.
  final bool requiresIdCheck;

  /// Checked against the list saved on this phone, not the server.
  final bool offline;
}

/// A ticket on the saved list (only a fingerprint of its code is kept).
class OfflineTicket {
  OfflineTicket({this.tier, this.holder, required this.status, this.scannedAt});

  factory OfflineTicket.fromJson(Map<String, dynamic> json) => OfflineTicket(
    tier: json['tier'] as String?,
    holder: json['holder'] as String?,
    status: '${json['status'] ?? 'valid'}',
    scannedAt: _date(json['scanned_at']),
  );

  final String? tier;
  final String? holder;
  String status;
  DateTime? scannedAt;

  Map<String, dynamic> toJson() => {
    'tier': tier,
    'holder': holder,
    'status': status,
    'scanned_at': scannedAt?.toUtc().toIso8601String(),
  };
}

/// The list saved on the phone for venues without signal.
class DoorList {
  DoorList({
    required this.eventId,
    required this.title,
    required this.salt,
    required this.requiresIdCheck,
    required this.tickets,
    required this.guests,
    required this.tiers,
    required this.doorSales,
    required this.summary,
    this.useUntil,
    this.savedAt,
  });

  factory DoorList.fromJson(Map<String, dynamic> json) => DoorList(
    eventId: '${json['event_id']}',
    title: '${json['title'] ?? ''}',
    salt: '${json['salt']}',
    requiresIdCheck: json['requires_id_check'] == true,
    tickets: {
      for (final item in _list(json['tickets'])) '${item['h']}': OfflineTicket.fromJson(item),
    },
    guests: _list(json['rsvps']).map(DoorGuest.fromJson).toList(),
    tiers: _list(json['tiers']).map(DoorTier.fromJson).toList(),
    doorSales: json['door_sales_enabled'] == true,
    summary: DoorSummary.fromJson(_map(json['summary'])),
    useUntil: _date(json['use_until']),
    savedAt: _date(json['saved_at']),
  );

  final String eventId;
  final String title;
  final String salt;
  final bool requiresIdCheck;

  /// Keyed by sha256(salt + code in capitals).
  final Map<String, OfflineTicket> tickets;
  final List<DoorGuest> guests;
  final List<DoorTier> tiers;
  final bool doorSales;

  /// Totals when the list was saved, kept up to date on this phone.
  final DoorSummary summary;
  final DateTime? useUntil;
  final DateTime? savedAt;

  OfflineTicket? find(String code) => tickets[fingerprint(salt, code)];

  static String fingerprint(String salt, String code) =>
      sha256.convert(utf8.encode('$salt${normalizeTicketCode(code)}')).toString();

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'title': title,
    'salt': salt,
    'requires_id_check': requiresIdCheck,
    'tickets': [
      for (final entry in tickets.entries) {'h': entry.key, ...entry.value.toJson()},
    ],
    'rsvps': [for (final guest in guests) guest.toJson()],
    'tiers': [for (final tier in tiers) tier.toJson()],
    'door_sales_enabled': doorSales,
    'summary': summary.toJson(),
    'use_until': useUntil?.toUtc().toIso8601String(),
    'saved_at': savedAt?.toUtc().toIso8601String(),
  };
}

/// Things done without signal, waiting to be sent.
class DoorPending {
  DoorPending({List<Map<String, dynamic>>? scans, List<Map<String, dynamic>>? checkins, List<Map<String, dynamic>>? sales})
    : scans = scans ?? [],
      checkins = checkins ?? [],
      sales = sales ?? [];

  factory DoorPending.fromJson(Map<String, dynamic> json) => DoorPending(
    scans: _list(json['scans']),
    checkins: _list(json['checkins']),
    sales: _list(json['sales']),
  );

  final List<Map<String, dynamic>> scans;
  final List<Map<String, dynamic>> checkins;
  final List<Map<String, dynamic>> sales;

  int get count => scans.length + checkins.length + sales.length;

  Map<String, dynamic> toJson() => {'scans': scans, 'checkins': checkins, 'sales': sales};
}

/// What came back from [DoorRepository.sync].
class DoorSyncResult {
  const DoorSyncResult({required this.problems, this.summary});

  /// Things door staff should know, e.g. a ticket let in on two phones.
  final List<String> problems;
  final DoorSummary? summary;
}

/// A sale being made at the door.
class DoorSaleDraft {
  const DoorSaleDraft({
    required this.tierId,
    required this.quantity,
    required this.unitPrice,
    required this.method,
    this.buyerName,
    this.buyerPhone,
  });

  final int tierId;
  final int quantity;
  final double unitPrice;
  final String method;
  final String? buyerName;
  final String? buyerPhone;

  double get total => unitPrice * quantity;
}

class DoorRepository {
  DoorRepository(this._dio);

  final Dio _dio;
  final _random = Random.secure();

  String _path(String eventId, [String rest = '']) => '/events/${Uri.encodeComponent(eventId)}/door$rest';

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw DoorException.fromDio(error);
    }
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) => _map(response.data?['data']);

  // ---- Online -------------------------------------------------------------

  Future<DoorInfo> info(String eventId) => _call(() async {
    return DoorInfo.fromJson(_data(await _dio.get<Map<String, dynamic>>(_path(eventId))));
  });

  Future<(ScanOutcome, DoorSummary)> scan(String eventId, String code) => _call(() async {
    final data = _data(await _dio.post<Map<String, dynamic>>(_path(eventId, '/scan'), data: {'ticket_code': code}));
    return (ScanOutcome.fromJson(data), DoorSummary.fromJson(_map(data['summary'])));
  });

  Future<(List<DoorGuest>, List<DoorTicketHolder>, DoorSummary)> guests(String eventId, String query) => _call(() async {
    final data = _data(await _dio.get<Map<String, dynamic>>(_path(eventId, '/guests'), queryParameters: {'q': query}));
    return (
      _list(data['rsvps']).map(DoorGuest.fromJson).toList(),
      _list(data['tickets']).map(DoorTicketHolder.fromJson).toList(),
      DoorSummary.fromJson(_map(data['summary'])),
    );
  });

  Future<(DoorGuest, DoorSummary)> checkIn(String eventId, int guestId, int count) => _call(() async {
    final data = _data(await _dio.post<Map<String, dynamic>>(_path(eventId, '/guests/$guestId/check-in'), data: {'count': count}));
    return (DoorGuest.fromJson(_map(data['guest'])), DoorSummary.fromJson(_map(data['summary'])));
  });

  Future<(DoorGuest, DoorSummary)> undoCheckIn(String eventId, int guestId) => _call(() async {
    final data = _data(await _dio.delete<Map<String, dynamic>>(_path(eventId, '/guests/$guestId/check-in')));
    return (DoorGuest.fromJson(_map(data['guest'])), DoorSummary.fromJson(_map(data['summary'])));
  });

  Future<(DoorGuest, DoorSummary)> walkIn(String eventId, {required String name, String? phone, int count = 1}) => _call(() async {
    final data = _data(await _dio.post<Map<String, dynamic>>(
      _path(eventId, '/walk-ins'),
      data: {'name': name, 'phone': ?phone, 'count': count},
    ));
    return (DoorGuest.fromJson(_map(data['guest'])), DoorSummary.fromJson(_map(data['summary'])));
  });

  Future<(ScanOutcome, DoorSummary)> letIn(String eventId, int ticketId) => _call(() async {
    final data = _data(await _dio.post<Map<String, dynamic>>(_path(eventId, '/tickets/$ticketId/let-in')));
    return (ScanOutcome.fromJson(data), DoorSummary.fromJson(_map(data['summary'])));
  });

  Future<(DoorSummary, List<DoorTier>)> sell(String eventId, DoorSaleDraft sale) => _call(() async {
    final data = _data(await _dio.post<Map<String, dynamic>>(_path(eventId, '/sales'), data: _saleJson(sale)));
    return (DoorSummary.fromJson(_map(data['summary'])), _list(data['tiers']).map(DoorTier.fromJson).toList());
  });

  Future<DoorInfo> voidSale(String eventId, int saleId) => _call(() async {
    await _dio.delete<Map<String, dynamic>>(_path(eventId, '/sales/$saleId'));
    return DoorInfo.fromJson(_data(await _dio.get<Map<String, dynamic>>(_path(eventId))));
  });

  Future<DoorSummary> setDoorSales(String eventId, bool enabled) => _call(() async {
    final data = _data(await _dio.put<Map<String, dynamic>>(_path(eventId, '/settings'), data: {'door_sales_enabled': enabled}));
    return DoorSummary.fromJson(_map(data['summary']));
  });

  Map<String, dynamic> _saleJson(DoorSaleDraft sale) => {
    'ticket_tier_id': sale.tierId,
    'quantity': sale.quantity,
    'unit_price': sale.unitPrice,
    'payment_method': sale.method,
    'buyer_name': ?sale.buyerName,
    'buyer_phone': ?sale.buyerPhone,
    'client_ref': _clientRef(),
  };

  /// A random id made on the phone, so a sale sent twice is only recorded once.
  String _clientRef() => List.generate(16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  // ---- Saved for no signal ------------------------------------------------

  Future<File> _file(String name) async {
    final folder = await getApplicationSupportDirectory();
    return File('${folder.path}/$name');
  }

  String _safe(String eventId) => eventId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Downloads the event's list and keeps it on this phone.
  Future<DoorList> downloadList(String eventId) => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      _path(eventId, '/manifest'),
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    );
    final data = _data(response)..['saved_at'] = DateTime.now().toUtc().toIso8601String();
    final list = DoorList.fromJson(data);
    // Keep what this phone did without signal that the server hasn't seen yet.
    final pending = await loadPending(eventId);
    for (final scan in pending.scans) {
      final ticket = list.find('${scan['ticket_code']}');
      if (ticket != null && ticket.status == 'valid') {
        ticket
          ..status = 'used'
          ..scannedAt = _date(scan['scanned_at']);
      }
    }
    await saveList(list);
    return list;
  });

  Future<DoorList?> loadList(String eventId) async {
    try {
      final file = await _file('door_list_${_safe(eventId)}.json');
      if (!await file.exists()) return null;
      final list = DoorList.fromJson(_map(jsonDecode(await file.readAsString())));
      if (list.useUntil != null && DateTime.now().isAfter(list.useUntil!)) {
        await file.delete();
        return null;
      }
      return list;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveList(DoorList list) async {
    final file = await _file('door_list_${_safe(list.eventId)}.json');
    await file.writeAsString(jsonEncode(list.toJson()), flush: true);
  }

  Future<DoorPending> loadPending(String eventId) async {
    try {
      final file = await _file('door_pending_${_safe(eventId)}.json');
      if (!await file.exists()) return DoorPending();
      return DoorPending.fromJson(_map(jsonDecode(await file.readAsString())));
    } catch (_) {
      return DoorPending();
    }
  }

  Future<void> savePending(String eventId, DoorPending pending) async {
    final file = await _file('door_pending_${_safe(eventId)}.json');
    await file.writeAsString(jsonEncode(pending.toJson()), flush: true);
  }

  /// Checks a ticket against the saved list and, if it's good, lets it in on this phone.
  Future<ScanOutcome> checkOffline(String eventId, DoorList list, String rawCode) async {
    final code = normalizeTicketCode(rawCode);
    final ticket = list.find(code);
    if (ticket == null) {
      return const ScanOutcome(
        admit: false,
        offline: true,
        message: 'Not on the saved list. If it was bought just now, check again when there’s signal.',
      );
    }
    if (ticket.status == 'used') {
      final at = ticket.scannedAt;
      return ScanOutcome(
        admit: false,
        offline: true,
        guest: ticket.holder,
        tier: ticket.tier,
        message: at == null ? 'Already let in.' : 'Already let in at ${_hhmm(at)}.',
      );
    }
    if (ticket.status != 'valid') {
      return ScanOutcome(admit: false, offline: true, guest: ticket.holder, tier: ticket.tier, message: 'This ticket was ${ticket.status}.');
    }

    final now = DateTime.now();
    ticket
      ..status = 'used'
      ..scannedAt = now;
    final pending = await loadPending(eventId);
    pending.scans.add({'ticket_code': code, 'scanned_at': now.toUtc().toIso8601String()});
    await savePending(eventId, pending);
    await saveList(list);
    return ScanOutcome(
      admit: true,
      offline: true,
      guest: ticket.holder,
      tier: ticket.tier,
      requiresIdCheck: list.requiresIdCheck,
      message: 'Valid ticket.',
    );
  }

  /// Ticks a guest off on this phone (count 0 = undo).
  Future<void> checkInOffline(String eventId, DoorList? list, DoorGuest guest, int count) async {
    final now = DateTime.now();
    guest
      ..checkedInCount = count
      ..checkedInAt = count > 0 ? (guest.checkedInAt ?? now) : null;
    if (list != null) {
      for (final saved in list.guests.where((item) => item.id == guest.id)) {
        saved
          ..checkedInCount = guest.checkedInCount
          ..checkedInAt = guest.checkedInAt;
      }
      await saveList(list);
    }
    final pending = await loadPending(eventId);
    pending.checkins.add({'rsvp_id': guest.id, 'count': count, 'at': now.toUtc().toIso8601String()});
    await savePending(eventId, pending);
  }

  /// Records a door sale on this phone, to send later.
  Future<void> sellOffline(String eventId, DoorList list, DoorSaleDraft sale) async {
    final pending = await loadPending(eventId);
    pending.sales.add({..._saleJson(sale), 'sold_at': DateTime.now().toUtc().toIso8601String()});
    await savePending(eventId, pending);
    for (final tier in list.tiers.where((item) => item.id == sale.tierId)) {
      if (tier.available != null) tier.available = max(0, tier.available! - sale.quantity);
    }
    await saveList(list);
  }

  /// Sends everything done without signal. Returns what needs a look.
  Future<DoorSyncResult> sync(String eventId) async {
    final pending = await loadPending(eventId);
    if (pending.count == 0) return const DoorSyncResult(problems: []);
    final scans = pending.scans.take(500).toList();
    final checkins = pending.checkins.take(500).toList();
    final sales = pending.sales.take(200).toList();

    final data = await _call(() async => _data(await _dio.post<Map<String, dynamic>>(
      _path(eventId, '/sync'),
      data: {'scans': scans, 'checkins': checkins, 'sales': sales},
    )));

    // Drop only what was sent: more may have been added meanwhile.
    final latest = await loadPending(eventId);
    latest.scans.removeRange(0, min(scans.length, latest.scans.length));
    latest.checkins.removeRange(0, min(checkins.length, latest.checkins.length));
    latest.sales.removeRange(0, min(sales.length, latest.sales.length));
    await savePending(eventId, latest);

    final problems = <String>[
      for (final scan in _list(data['scans']))
        if (scan['result'] == 'duplicate')
          '${scan['guest'] ?? scan['ticket_code']} was also let in on another phone.'
        else if (scan['result'] == 'not_found')
          '${scan['ticket_code']} isn’t a ticket for this event.'
        else if (scan['result'] == 'invalid')
          '${scan['guest'] ?? scan['ticket_code']}’s ticket was ${scan['status']}.',
      for (final sale in _list(data['sales']))
        if (sale['result'] == 'failed')
          'A door sale couldn’t be saved: ${sale['message']}'
        else if (sale['over_capacity'] == true)
          'A door sale went over the ticket limit (it sold out on another phone).',
    ];
    return DoorSyncResult(problems: problems, summary: DoorSummary.fromJson(_map(data['summary'])));
  }

  static String _hhmm(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
