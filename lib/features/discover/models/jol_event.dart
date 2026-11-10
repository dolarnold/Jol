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
    this.isStudent = false,
    this.isSoldOut = false,
  });

  final String id;
  final String name;
  final int price;
  final String description;
  final int? remaining;
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

  String get address =>
      isPrivate ? '$area, Cape Town' : '$venue, $area, Cape Town';

  String get attendanceText {
    if (isSoldOut) return 'Sold out';
    if (!isPaid) return 'Free';
    return 'From ${formatZar(fromPrice)}';
  }
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
