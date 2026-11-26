import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_client.dart';
import '../discover/models/jol_event.dart';

/// Friends (people who follow each other), the event wall, and group
/// bookings where each friend pays their own share.
final socialRepositoryProvider = Provider<SocialRepository>(
  (ref) => SocialRepository(ref.watch(apiClientProvider)),
);

final friendsProvider = FutureProvider.autoDispose<FriendsOverview>(
  (ref) => ref.watch(socialRepositoryProvider).friends(),
);

final eventWallProvider = FutureProvider.autoDispose.family<EventWall, String>(
  (ref, eventId) => ref.watch(socialRepositoryProvider).wall(eventId),
);

final splitProvider = FutureProvider.autoDispose.family<SplitBooking, String>(
  (ref, code) => ref.watch(socialRepositoryProvider).split(code),
);

final mySplitsProvider = FutureProvider.autoDispose<List<SplitBooking>>(
  (ref) => ref.watch(socialRepositoryProvider).mySplits(),
);

@immutable
class PersonCard {
  const PersonCard({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.isHost = false,
    this.iFollow = false,
    this.followsMe = false,
  });

  factory PersonCard.fromJson(Map<String, dynamic> json) => PersonCard(
    id: '${json['id']}',
    name: json['name'] as String? ?? 'Friend',
    avatarUrl: _url(json['avatar_url']),
    isHost: json['is_host'] == true,
    iFollow: json['i_follow'] == true,
    followsMe: json['follows_me'] == true,
  );

  final String id;
  final String name;
  final String? avatarUrl;
  final bool isHost;
  final bool iFollow;
  final bool followsMe;

  bool get isFriend => iFollow && followsMe;

  JolFriendFace get face => JolFriendFace(id: id, name: name, avatarUrl: avatarUrl);
}

@immutable
class FriendsOverview {
  const FriendsOverview({
    required this.friendCode,
    required this.showGoing,
    required this.friends,
    required this.followBack,
  });

  final String friendCode;
  final bool showGoing;
  final List<JolFriendFace> friends;

  /// People following you whom you haven't followed back.
  final List<JolFriendFace> followBack;
}

@immutable
class WallPost {
  const WallPost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
    required this.authorIsHost,
    required this.mine,
    required this.canRemove,
  });

  factory WallPost.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : const <String, dynamic>{};
    return WallPost(
      id: '${json['id']}',
      body: json['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      author: JolFriendFace(
        id: '${author['id']}',
        name: author['name'] as String? ?? 'Guest',
        avatarUrl: _url(author['avatar_url']),
      ),
      authorIsHost: author['is_host'] == true,
      mine: json['mine'] == true,
      canRemove: json['can_remove'] == true,
    );
  }

  final String id;
  final String body;
  final DateTime createdAt;
  final JolFriendFace author;
  final bool authorIsHost;
  final bool mine;
  final bool canRemove;
}

@immutable
class EventWall {
  const EventWall({
    required this.canPost,
    required this.postProblem,
    required this.posts,
  });

  final bool canPost;
  final String? postProblem;
  final List<WallPost> posts;
}

@immutable
class SplitShare {
  const SplitShare({
    required this.id,
    required this.position,
    required this.amount,
    required this.status,
    this.payerName,
    this.payerAvatarUrl,
    this.mine = false,
  });

  final String id;
  final int position;
  final double amount;

  /// unpaid, pending, paid or refunded.
  final String status;
  final String? payerName;
  final String? payerAvatarUrl;
  final bool mine;

  bool get isPaid => status == 'paid';
}

@immutable
class SplitBooking {
  const SplitBooking({
    required this.code,
    required this.status,
    required this.expiresAt,
    required this.organiserName,
    required this.isOrganiser,
    required this.eventId,
    required this.eventTitle,
    required this.eventStart,
    required this.coverImageUrl,
    required this.tierName,
    required this.people,
    required this.tableName,
    required this.totalAmount,
    required this.paidAmount,
    required this.shareUrl,
    required this.shares,
  });

  factory SplitBooking.fromJson(Map<String, dynamic> json) {
    final event = json['event'] is Map
        ? Map<String, dynamic>.from(json['event'] as Map)
        : const <String, dynamic>{};
    final organiser = json['organiser'] is Map
        ? Map<String, dynamic>.from(json['organiser'] as Map)
        : const <String, dynamic>{};
    return SplitBooking(
      code: json['code'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      organiserName: organiser['name'] as String? ?? 'A friend',
      isOrganiser: json['is_organiser'] == true,
      eventId: '${event['id']}',
      eventTitle: event['title'] as String? ?? 'Event',
      eventStart: DateTime.tryParse(event['start_time'] as String? ?? '')
          ?.toLocal(),
      coverImageUrl: _url(event['cover_image_url']),
      tierName: json['tier_name'] as String? ?? 'Tickets',
      people: (json['people'] as num?)?.toInt() ?? 0,
      tableName: json['table_name'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      shareUrl: json['share_url'] as String? ?? '',
      shares: (json['shares'] is List ? json['shares'] as List : const [])
          .whereType<Map>()
          .map((raw) {
            final share = Map<String, dynamic>.from(raw);
            final payer = share['payer'] is Map ? share['payer'] as Map : null;
            return SplitShare(
              id: '${share['id']}',
              position: (share['position'] as num?)?.toInt() ?? 0,
              amount: (share['amount'] as num?)?.toDouble() ?? 0,
              status: share['status'] as String? ?? 'unpaid',
              payerName: payer?['name'] as String?,
              payerAvatarUrl: _url(payer?['avatar_url']),
              mine: share['mine'] == true,
            );
          })
          .toList(growable: false),
    );
  }

  final String code;

  /// open, complete, expired or cancelled.
  final String status;
  final DateTime expiresAt;
  final String organiserName;
  final bool isOrganiser;
  final String eventId;
  final String eventTitle;
  final DateTime? eventStart;
  final String? coverImageUrl;
  final String tierName;
  final int people;
  final String? tableName;
  final double totalAmount;
  final double paidAmount;
  final String shareUrl;
  final List<SplitShare> shares;

  bool get isOpen => status == 'open';
  int get paidCount => shares.where((share) => share.isPaid).length;
  SplitShare? get myShare => shares.where((share) => share.mine).firstOrNull;
}

String? _url(Object? value) => value is String && value.isNotEmpty ? value : null;

class SocialRepository {
  const SocialRepository(this._dio);

  final Dio _dio;

  Future<T> _call<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is! Map) {
      throw const ApiException('The server response was not in the expected format.');
    }
    return Map<String, dynamic>.from(data);
  }

  // ---- Friends --------------------------------------------------------------

  Future<FriendsOverview> friends() => _call(() async {
    final data = _data(await _dio.get<Map<String, dynamic>>('/me/friends'));
    return FriendsOverview(
      friendCode: data['friend_code'] as String? ?? '',
      showGoing: data['show_going_to_friends'] != false,
      friends: JolFriendFace.listFrom(data['friends']),
      followBack: JolFriendFace.listFrom(data['follow_back']),
    );
  });

  Future<PersonCard> findByCode(String code) => _call(() async {
    final data = _data(
      await _dio.get<Map<String, dynamic>>(
        '/people/code/${Uri.encodeComponent(code.trim().toUpperCase())}',
      ),
    );
    return PersonCard.fromJson(data);
  });

  Future<({PersonCard card, List<({String id, String title, DateTime? start})> goingTo})>
  person(String id) => _call(() async {
    final data = _data(await _dio.get<Map<String, dynamic>>('/people/$id'));
    final going = (data['going_to'] is List ? data['going_to'] as List : const [])
        .whereType<Map>()
        .map(
          (event) => (
            id: '${event['id']}',
            title: event['title'] as String? ?? 'Event',
            start: DateTime.tryParse(event['start_time'] as String? ?? '')?.toLocal(),
          ),
        )
        .toList(growable: false);
    return (card: PersonCard.fromJson(data), goingTo: going);
  });

  /// Returns the server's message and the updated card.
  Future<(String, PersonCard)> follow(String id, {bool follow = true}) =>
      _call(() async {
        final response = follow
            ? await _dio.post<Map<String, dynamic>>('/people/$id/follow')
            : await _dio.delete<Map<String, dynamic>>('/people/$id/follow');
        return (
          response.data?['message'] as String? ?? '',
          PersonCard.fromJson(_data(response)),
        );
      });

  Future<void> setShowGoing(bool show) => _call(() async {
    await _dio.put<Map<String, dynamic>>(
      '/me/social',
      data: {'show_going_to_friends': show},
    );
  });

  // ---- Event wall -----------------------------------------------------------

  Future<EventWall> wall(String eventId) => _call(() async {
    final data = _data(
      await _dio.get<Map<String, dynamic>>(
        '/events/${Uri.encodeComponent(eventId)}/wall',
      ),
    );
    return EventWall(
      canPost: data['can_post'] == true,
      postProblem: data['post_problem'] as String?,
      posts: (data['posts'] is List ? data['posts'] as List : const [])
          .whereType<Map>()
          .map((post) => WallPost.fromJson(Map<String, dynamic>.from(post)))
          .toList(growable: false),
    );
  });

  Future<void> post(String eventId, String body) => _call(() async {
    await _dio.post<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/wall',
      data: {'body': body},
    );
  });

  Future<void> removePost(String eventId, String postId) => _call(() async {
    await _dio.delete<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/wall/$postId',
    );
  });

  Future<void> reportPost(String eventId, String postId) => _call(() async {
    await _dio.post<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/wall/$postId/report',
    );
  });

  // ---- Group bookings paid in shares --------------------------------------

  Future<SplitBooking> createSplit({
    required String eventId,
    required String tierId,
    required int quantity,
    required int shares,
    required String guestName,
    required String guestPhone,
    String? promoCode,
    String? tableName,
  }) => _call(() async {
    final data = _data(
      await _dio.post<Map<String, dynamic>>(
        '/events/${Uri.encodeComponent(eventId)}/splits',
        data: {
          'ticket_tier_id': int.tryParse(tierId) ?? tierId,
          'quantity': quantity,
          'shares': shares,
          'guest_name': guestName,
          'guest_phone': guestPhone,
          'promo_code': ?promoCode,
          'table_name': ?tableName,
        },
      ),
    );
    return SplitBooking.fromJson(data);
  });

  Future<SplitBooking> split(String code) => _call(() async {
    return SplitBooking.fromJson(
      _data(await _dio.get<Map<String, dynamic>>('/splits/${Uri.encodeComponent(code)}')),
    );
  });

  Future<List<SplitBooking>> mySplits() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/splits');
    final data = response.data?['data'];
    return (data is List ? data : const [])
        .whereType<Map>()
        .map((item) => SplitBooking.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  });

  /// Opens checkout for a share. Returns the checkout URL and gateway.
  Future<({String url, String gateway, String reference})> payShare(
    String code,
    String shareId,
  ) => _call(() async {
    final data = _data(
      await _dio.post<Map<String, dynamic>>(
        '/splits/${Uri.encodeComponent(code)}/shares/$shareId/pay',
      ),
    );
    final payment = data['payment'] is Map ? data['payment'] as Map : const {};
    return (
      url: data['checkout_url'] as String? ?? '',
      gateway: payment['payment_gateway'] as String? ?? '',
      reference: payment['reference'] as String? ?? '',
    );
  });

  /// Test payments only: completes the payment through the server's simulator.
  Future<void> completeTestPayment(String checkoutUrl) => _call(() async {
    await _dio.get<Map<String, dynamic>>(checkoutUrl);
  });

  Future<void> cancelSplit(String code) => _call(() async {
    await _dio.post<Map<String, dynamic>>('/splits/${Uri.encodeComponent(code)}/cancel');
  });
}
