import 'package:flutter/foundation.dart';

enum JolPosterStyle { sunset, boldType, halftone, stripes, glow, split }

@immutable
class JolTicketTier {
  const JolTicketTier({
    required this.id,
    required this.name,
    required this.price,
    this.description = '',
    this.remaining,
    this.maxPerOrder,
    this.isStudent = false,
    this.isSoldOut = false,
  });

  final String id;
  final String name;
  final int price;
  final String description;
  final int? remaining;

  /// Most tickets of this type one person may hold (null = no limit).
  final int? maxPerOrder;
  final bool isStudent;
  final bool isSoldOut;
}

@immutable
class JolEvent {
  const JolEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.venue,
    required this.area,
    required this.host,
    required this.hostInitials,
    required this.attending,
    required this.description,
    required this.entryRules,
    required this.posterStyle,
    required this.posterPrimary,
    required this.posterSecondary,
    this.isPaid = false,
    this.fromPrice = 0,
    this.isPrivate = false,
    this.isSoldOut = false,
    this.isAgeRestricted = false,
    this.isVerifiedHost = false,
    this.hostEventCount = 1,
    this.rsvpCapacity = 0,
    this.allowsPlusOne = false,
    this.guestlistCutoff,
    this.guestlistSpots = 0,
    this.canTransfer = false,
    this.tiers = const [],
    this.fundTitle,
    this.fundRaised = 0,
    this.fundGoal = 0,
    this.fundContributors = 0,
    this.isApiBacked = false,
    this.shareUrl,
    this.coverImageUrl,
    this.studentDiscountPercent,
    this.latitude,
    this.longitude,
    this.locationHidden = false,
    this.locationName,
    this.rawAddress,
    this.status = 'published',
    this.maxPlusOnes = 1,
    this.guestlistCutoffAt,
    this.viewerIsHost = false,
    this.startsAt,
    this.endsAt,
    this.cameraFilter = true,
    this.posterStyleName,
    this.promoterCommissionType,
    this.promoterCommissionValue,
    this.fundId,
    this.fundSuggested = 0,
    this.fundDescription,
  });

  final String id;
  final String title;
  final String category;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String venue;
  final String area;
  final String host;
  final String hostInitials;
  final int attending;
  final String description;
  final String entryRules;
  final JolPosterStyle posterStyle;
  final int posterPrimary;
  final int posterSecondary;
  final bool isPaid;
  final int fromPrice;
  final bool isPrivate;
  final bool isSoldOut;
  final bool isAgeRestricted;
  final bool isVerifiedHost;
  final int hostEventCount;
  final int rsvpCapacity;
  final bool allowsPlusOne;
  final String? guestlistCutoff;
  final int guestlistSpots;
  final bool canTransfer;
  final List<JolTicketTier> tiers;
  final String? fundTitle;
  final int fundRaised;
  final int fundGoal;
  final int fundContributors;
  final bool isApiBacked;
  final String? shareUrl;

  /// Host-uploaded cover photo; null means the generated poster is used.
  final String? coverImageUrl;
  final double? studentDiscountPercent;

  /// Map pin; null when not set or hidden (private event, no RSVP yet).
  final double? latitude;
  final double? longitude;

  /// True when the server withheld the exact location from this viewer.
  final bool locationHidden;

  /// Raw venue name and address as the host entered them (null when hidden).
  final String? locationName;
  final String? rawAddress;

  /// "draft", "published", "cancelled" or "completed".
  final String status;
  final int maxPlusOnes;
  final DateTime? guestlistCutoffAt;
  final bool viewerIsHost;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool cameraFilter;

  /// Poster style the host chose (null = picked from the category).
  final String? posterStyleName;
  final String? promoterCommissionType;
  final double? promoterCommissionValue;
  final String? fundId;
  final int fundSuggested;
  final String? fundDescription;

  bool get isDraft => status == 'draft';
  bool get hasPin => latitude != null && longitude != null;

  /// RSVPs are closed once the guestlist cutoff has passed.
  bool get rsvpClosed =>
      guestlistCutoffAt != null && DateTime.now().isAfter(guestlistCutoffAt!);

  factory JolEvent.fromApi(Map<String, dynamic> json, {int attending = 0}) {
    final startTime = DateTime.parse(json['start_time'] as String).toLocal();
    final rawEndTime = json['end_time'];
    final endTime = rawEndTime is String
        ? DateTime.parse(rawEndTime).toLocal()
        : startTime.add(const Duration(hours: 2));
    final category = (json['category'] as String? ?? 'general').toLowerCase();
    final isPrivate = json['is_private'] == true;
    final address = json['address'] as String?;
    final rawTiers = json['ticket_tiers'];
    final tiers = rawTiers is List
        ? rawTiers
              .map((item) {
                if (item is! Map) {
                  throw const FormatException(
                    'Invalid ticket tier in event data.',
                  );
                }
                final tier = Map<String, dynamic>.from(item);
                final remaining = tier['remaining'] as int?;
                return JolTicketTier(
                  id: tier['id'].toString(),
                  name: tier['name'] as String? ?? 'Ticket',
                  price: _apiPrice(tier['price']),
                  description: tier['description'] as String? ?? '',
                  remaining: remaining,
                  maxPerOrder: (tier['max_per_order'] as num?)?.toInt(),
                  isSoldOut: remaining == 0,
                );
              })
              .toList(growable: false)
        : const <JolTicketTier>[];
    final hostData = json['host'];
    final host = hostData is Map
        ? Map<String, dynamic>.from(hostData)['name'] as String? ?? 'JOL host'
        : 'JOL host';
    final contributionData = json['contribution_pot'];
    final contribution = contributionData is Map
        ? Map<String, dynamic>.from(contributionData)
        : null;
    final colors = _posterColors(category);
    final locationHidden = json['location_hidden'] == true;
    final locationName = json['location_name'] as String?;
    final apiArea = json['area'] as String?;
    final venue = locationHidden
        ? 'Private event'
        : (locationName?.isNotEmpty == true
              ? locationName!
              : (address ?? 'Location TBA'));
    final area = apiArea?.isNotEmpty == true
        ? apiArea!
        : address?.split(',').last.trim().isNotEmpty == true
        ? address!.split(',').last.trim()
        : 'Cape Town';
    final posterStyleName = json['poster_style'] as String?;
    final chosenStyle = JolPosterStyle.values
        .where((style) => style.name == posterStyleName)
        .firstOrNull;
    final rawCutoff = json['guestlist_cutoff_at'];
    final cutoff = rawCutoff is String
        ? DateTime.tryParse(rawCutoff)?.toLocal()
        : null;
    final commissionType = json['promoter_commission_type'] as String?;
    final commissionValue = commissionType == 'fixed'
        ? (json['promoter_commission_amount'] as num?)?.toDouble()
        : (json['promoter_commission_percent'] as num?)?.toDouble();

    return JolEvent(
      id: json['id'].toString(),
      title: json['title'] as String? ?? 'Untitled event',
      category: category,
      date: startTime,
      startTime: _formatTime(startTime),
      endTime: _formatTime(endTime),
      venue: venue,
      area: area,
      host: host,
      hostInitials: _initials(host),
      attending: attending,
      description: json['description'] as String? ?? '',
      entryRules: '',
      posterStyle:
          chosenStyle ??
          JolPosterStyle.values[category.codeUnits.fold<int>(
                0,
                (value, unit) => value + unit,
              ) %
              JolPosterStyle.values.length],
      posterPrimary: colors.$1,
      posterSecondary: colors.$2,
      isPaid: tiers.isNotEmpty,
      fromPrice: tiers.isEmpty
          ? 0
          : tiers.map((tier) => tier.price).reduce((a, b) => a < b ? a : b),
      isPrivate: isPrivate,
      isSoldOut: tiers.isNotEmpty && tiers.every((tier) => tier.isSoldOut),
      isVerifiedHost: false,
      isAgeRestricted: json['is_age_restricted'] == true,
      canTransfer: json['allow_ticket_transfer'] == true,
      allowsPlusOne: json['allow_plus_ones'] != false,
      rsvpCapacity: (json['rsvp_capacity'] as num?)?.toInt() ?? 0,
      guestlistCutoff: cutoff == null ? null : _formatTime(cutoff),
      tiers: tiers,
      fundTitle: contribution?['title'] as String?,
      fundRaised: _apiPrice(contribution?['current_amount']),
      fundGoal: _apiPrice(contribution?['target_amount']),
      isApiBacked: true,
      shareUrl: json['share_url'] as String?,
      coverImageUrl: switch (json['cover_image_url']) {
        final String url when url.isNotEmpty => url,
        _ => null,
      },
      studentDiscountPercent: (json['student_discount_percent'] as num?)
          ?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationHidden: locationHidden,
      locationName: locationName,
      rawAddress: address,
      status: json['status'] as String? ?? 'published',
      maxPlusOnes: json['allow_plus_ones'] == false
          ? 0
          : (json['max_plus_ones'] as num?)?.toInt() ?? 1,
      guestlistCutoffAt: cutoff,
      viewerIsHost: json['viewer_is_host'] == true,
      startsAt: startTime,
      endsAt: rawEndTime is String ? endTime : null,
      cameraFilter: json['is_digital_camera_filter'] != false,
      posterStyleName: chosenStyle?.name,
      promoterCommissionType: commissionValue == null ? null : commissionType,
      promoterCommissionValue: commissionValue,
      fundId: contribution?['id']?.toString(),
      fundSuggested: _apiPrice(contribution?['suggested_amount']),
      fundDescription: contribution?['description'] as String?,
    );
  }

  String get address =>
      locationHidden ? '$area, Cape Town' : '$venue, $area, Cape Town';

  String get attendanceText {
    if (isSoldOut) return 'Sold out';
    if (!isPaid) return 'Free';
    if (fromPrice == 0) return 'Free tickets';
    return 'From ${formatZar(fromPrice)}';
  }
}

int _apiPrice(Object? value) {
  if (value is num) return value.round();
  return 0;
}

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty);
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

(int, int) _posterColors(String category) {
  const palettes = [
    (0xFFE8792E, 0xFF4A0E1C),
    (0xFFC69A62, 0xFF16223F),
    (0xFF7C5CE0, 0xFF7E9786),
    (0xFFE9B872, 0xFF6E4366),
    (0xFF55A899, 0xFF183D46),
  ];
  final index =
      category.codeUnits.fold<int>(0, (value, unit) => value + unit) %
      palettes.length;
  return palettes[index];
}

String formatZar(int amount) {
  final digits = amount.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = (end - 3).clamp(0, end);
    groups.insert(0, digits.substring(start, end));
  }
  return 'R${groups.join(' ')}';
}

String formatEventDate(DateTime date, {bool short = false}) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  return short ? '$weekday ${date.day} $month' : '$weekday ${date.day} $month';
}
