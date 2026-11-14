import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/api/api_client.dart';
import '../../discover/models/jol_event.dart';

/// A ticket type the host is adding to an event.
@immutable
class TierDraft {
  const TierDraft({
    required this.name,
    required this.price,
    required this.capacity,
    this.description = '',
    this.maxPerOrder,
  });

  final String name;
  final int price;
  final int capacity;
  final String description;
  final int? maxPerOrder;

  Map<String, Object> toJson() => {
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'price': price,
    'is_free': price <= 0 ? 1 : 0,
    'capacity': capacity,
    'max_per_order': ?maxPerOrder,
  };
}

/// Contribution fund on a free event.
@immutable
class FundDraft {
  const FundDraft({
    required this.title,
    required this.suggestedAmount,
    this.targetAmount,
    this.description = '',
  });

  final String title;
  final int suggestedAmount;
  final int? targetAmount;
  final String description;

  Map<String, Object> toJson() => {
    'title': title,
    if (description.isNotEmpty) 'description': description,
    'suggested_amount': suggestedAmount,
    'target_amount': ?targetAmount,
  };
}

/// Everything on the create/edit event form, in API field names.
@immutable
class EventDraft {
  const EventDraft({
    required this.title,
    required this.category,
    required this.start,
    required this.end,
    this.description = '',
    this.venue = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.isPrivate = false,
    this.isAgeRestricted = false,
    this.cameraFilter = true,
    this.posterStyle,
    this.coverImagePath,
    this.allowTicketTransfer = false,
    this.allowPlusOnes = true,
    this.maxPlusOnes = 1,
    this.rsvpCapacity,
    this.guestlistCutoffAt,
    this.studentDiscountPercent,
    this.promoterCommissionType,
    this.promoterCommissionValue,
  });

  final String title;
  final String category;
  final DateTime start;
  final DateTime end;
  final String description;
  final String venue;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isPrivate;
  final bool isAgeRestricted;
  final bool cameraFilter;

  /// One of [JolPosterStyle] names, or null to pick from the category.
  final String? posterStyle;

  /// Local file to upload as the cover photo (null = keep the current one).
  final String? coverImagePath;
  final bool allowTicketTransfer;
  final bool allowPlusOnes;
  final int maxPlusOnes;
  final int? rsvpCapacity;
  final DateTime? guestlistCutoffAt;
  final double? studentDiscountPercent;

  /// "percentage" or "fixed"; null uses the JOL default.
  final String? promoterCommissionType;
  final double? promoterCommissionValue;

  Map<String, Object?> toJson() => {
    'title': title,
    'type': 'casual',
    'category': category,
    'start_time': start.toUtc().toIso8601String(),
    'end_time': end.toUtc().toIso8601String(),
    'description': description.isEmpty ? null : description,
    'location_name': venue.isEmpty ? null : venue,
    'address': address.isEmpty ? null : address,
    'latitude': latitude,
    'longitude': longitude,
    // Laravel's boolean rule accepts 1/0 in both JSON and multipart.
    'is_private': isPrivate ? 1 : 0,
    'is_age_restricted': isAgeRestricted ? 1 : 0,
    'is_digital_camera_filter': cameraFilter ? 1 : 0,
    'poster_style': posterStyle,
    'allow_ticket_transfer': allowTicketTransfer ? 1 : 0,
    'allow_plus_ones': allowPlusOnes ? 1 : 0,
    'max_plus_ones': allowPlusOnes ? maxPlusOnes : 0,
    'rsvp_capacity': rsvpCapacity,
    'guestlist_cutoff_at': guestlistCutoffAt?.toUtc().toIso8601String(),
    'student_discount_percent': studentDiscountPercent,
    'promoter_commission_type': promoterCommissionType,
    if (promoterCommissionType == 'fixed')
      'promoter_commission_amount': promoterCommissionValue
    else if (promoterCommissionType == 'percentage')
      'promoter_commission_percent': promoterCommissionValue,
  };
}

final hostingRepositoryProvider = Provider<HostingRepository>(
  (ref) => HostingRepository(ref.watch(apiClientProvider)),
);

class HostingRepository {
  const HostingRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  /// Creates a new event ([eventId] null) or updates an existing one, then
  /// adds any new ticket types and saves or removes the contribution fund.
  /// Returns the event id.
  Future<String> saveEvent({
    String? eventId,
    required EventDraft draft,
    required String status,
    List<TierDraft> newTiers = const [],
    FundDraft? fund,
    bool removeFund = false,
  }) => _call(() async {
    final fields = <String, Object?>{...draft.toJson(), 'status': status};
    final path = draft.coverImagePath;
    final Object body;
    if (path == null) {
      body = fields;
    } else {
      // Multipart can't send nulls. Laravel turns empty strings into null,
      // so send '' to clear a field.
      final multipart = <String, Object>{
        for (final entry in fields.entries) entry.key: entry.value ?? '',
        'cover_image': await MultipartFile.fromFile(path),
        // PHP only parses multipart bodies on POST, so updates use
        // method spoofing.
        if (eventId != null) '_method': 'PUT',
      };
      body = FormData.fromMap(multipart);
    }
    final options = path == null
        ? null
        : Options(sendTimeout: const Duration(seconds: 90));
    final Response<Map<String, dynamic>> response;
    if (eventId == null) {
      response = await _dio.post('/events', data: body, options: options);
    } else if (path == null) {
      response = await _dio.put(
        '/events/${Uri.encodeComponent(eventId)}',
        data: body,
      );
    } else {
      response = await _dio.post(
        '/events/${Uri.encodeComponent(eventId)}',
        data: body,
        options: options,
      );
    }
    final data = response.data?['data'];
    final event = data is Map ? data['event'] : null;
    if (event is! Map) {
      throw const ApiException(
        'The event was saved but the response was unexpected.',
      );
    }
    final id = '${event['id']}';
    for (final tier in newTiers) {
      await _dio.post<void>('/events/$id/ticket-tiers', data: tier.toJson());
    }
    if (fund != null) {
      await _dio.put<void>('/events/$id/contribution-pot', data: fund.toJson());
    } else if (removeFund) {
      await _dio.delete<void>('/events/$id/contribution-pot');
    }
    return id;
  });

  Future<void> publish(String eventId) => _call(() async {
    await _dio.put<void>(
      '/events/${Uri.encodeComponent(eventId)}',
      data: {'status': 'published'},
    );
  });
}

/// Builds a [JolEvent] for the preview screen from what's on the form.
JolEvent previewEvent({
  required EventDraft draft,
  required String host,
  required List<JolTicketTier> tiers,
  FundDraft? fund,
  String? existingCoverUrl,
}) {
  String time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
  final parts = draft.address
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  final style = JolPosterStyle.values
          .where((style) => style.name == draft.posterStyle)
          .firstOrNull ??
      JolPosterStyle.values[draft.category.codeUnits.fold<int>(
            0,
            (value, unit) => value + unit,
          ) %
          JolPosterStyle.values.length];
  return JolEvent(
    id: 'preview',
    title: draft.title.isEmpty ? 'Untitled event' : draft.title,
    category: draft.category,
    date: draft.start,
    startTime: time(draft.start),
    endTime: time(draft.end),
    venue: draft.venue.isNotEmpty ? draft.venue : 'Location TBA',
    area: parts.isEmpty ? 'Cape Town' : parts.last,
    host: host,
    hostInitials: host.isEmpty ? 'J' : host[0].toUpperCase(),
    attending: 0,
    description: draft.description,
    entryRules: draft.isAgeRestricted ? '18+ · bring a valid ID.' : '',
    posterStyle: style,
    posterPrimary: 0xFFE8792E,
    posterSecondary: 0xFF16223F,
    isPaid: tiers.isNotEmpty,
    fromPrice: tiers.isEmpty
        ? 0
        : tiers.map((tier) => tier.price).reduce((a, b) => a < b ? a : b),
    isPrivate: draft.isPrivate,
    isAgeRestricted: draft.isAgeRestricted,
    rsvpCapacity: draft.rsvpCapacity ?? 0,
    allowsPlusOne: draft.allowPlusOnes,
    maxPlusOnes: draft.allowPlusOnes ? draft.maxPlusOnes : 0,
    canTransfer: draft.allowTicketTransfer,
    tiers: tiers,
    fundTitle: fund?.title,
    fundGoal: fund?.targetAmount ?? 0,
    fundSuggested: fund?.suggestedAmount ?? 0,
    coverImageUrl: existingCoverUrl,
    latitude: draft.latitude,
    longitude: draft.longitude,
    locationName: draft.venue,
    rawAddress: draft.address,
    guestlistCutoffAt: draft.guestlistCutoffAt,
    guestlistCutoff: draft.guestlistCutoffAt == null
        ? null
        : time(draft.guestlistCutoffAt!),
    posterStyleName: draft.posterStyle,
    status: 'draft',
    viewerIsHost: true,
    isApiBacked: true,
  );
}
