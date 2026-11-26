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

final eventPollsProvider = FutureProvider.autoDispose.family<EventPolls, String>(
  (ref, eventId) => ref.watch(socialRepositoryProvider).polls(eventId),
);

final eventAlbumProvider = FutureProvider.autoDispose.family<EventAlbum, String>(
  (ref, eventId) => ref.watch(socialRepositoryProvider).album(eventId),
);

final memoriesProvider = FutureProvider.autoDispose<List<Memory>>(
  (ref) => ref.watch(socialRepositoryProvider).memories(),
);

final achievementsProvider = FutureProvider.autoDispose<Achievements>(
  (ref) => ref.watch(socialRepositoryProvider).achievements(),
);

final walletLinksProvider = FutureProvider.autoDispose.family<({String? apple, String? google}), String>(
  (ref, ticketId) => ref.watch(socialRepositoryProvider).walletLinks(ticketId),
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

@immutable
class PollOption {
  const PollOption({required this.label, required this.votes, required this.percent});

  final String label;
  final int votes;
  final int percent;
}

@immutable
class EventPoll {
  const EventPoll({
    required this.id,
    required this.question,
    required this.isOpen,
    required this.totalVotes,
    required this.myVote,
    required this.options,
  });

  factory EventPoll.fromJson(Map<String, dynamic> json) => EventPoll(
    id: '${json['id']}',
    question: json['question'] as String? ?? '',
    isOpen: json['is_open'] == true,
    totalVotes: (json['total_votes'] as num?)?.toInt() ?? 0,
    myVote: (json['my_vote'] as num?)?.toInt(),
    options: (json['options'] is List ? json['options'] as List : const [])
        .whereType<Map>()
        .map(
          (option) => PollOption(
            label: option['label'] as String? ?? '',
            votes: (option['votes'] as num?)?.toInt() ?? 0,
            percent: (option['percent'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList(growable: false),
  );

  final String id;
  final String question;
  final bool isOpen;
  final int totalVotes;
  final int? myVote;
  final List<PollOption> options;
}

@immutable
class EventPolls {
  const EventPolls({required this.canVote, required this.canManage, required this.polls});

  final bool canVote;
  final bool canManage;
  final List<EventPoll> polls;
}

@immutable
class AlbumPhoto {
  const AlbumPhoto({
    required this.id,
    required this.url,
    required this.thumbUrl,
    required this.caption,
    required this.author,
    required this.mine,
    required this.canRemove,
  });

  final String id;
  final String url;
  final String thumbUrl;
  final String? caption;
  final JolFriendFace author;
  final bool mine;
  final bool canRemove;
}

@immutable
class EventAlbum {
  const EventAlbum({
    required this.canSee,
    required this.canAdd,
    required this.addProblem,
    required this.count,
    required this.photos,
  });

  final bool canSee;
  final bool canAdd;
  final String? addProblem;
  final int count;
  final List<AlbumPhoto> photos;
}

@immutable
class Memory {
  const Memory({
    required this.eventId,
    required this.title,
    required this.start,
    required this.place,
    required this.imageUrl,
    required this.photoCount,
    required this.myRating,
  });

  final String eventId;
  final String title;
  final DateTime? start;
  final String? place;

  /// An album photo from the night, else the event cover.
  final String? imageUrl;
  final int photoCount;
  final int? myRating;
}

@immutable
class JolBadge {
  const JolBadge({required this.label, required this.hint, required this.earned});

  final String label;
  final String hint;
  final bool earned;
}

@immutable
class Achievements {
  const Achievements({
    required this.points,
    required this.eventsAttended,
    required this.eventsHosted,
    required this.streakMonths,
    required this.badges,
  });

  final int points;
  final int eventsAttended;
  final int eventsHosted;
  final int streakMonths;
  final List<JolBadge> badges;
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

  // ---- Album, memories and badges -----------------------------------------

  Future<EventAlbum> album(String eventId) => _call(() async {
    final data = _data(
      await _dio.get<Map<String, dynamic>>('/events/${Uri.encodeComponent(eventId)}/photos'),
    );
    return EventAlbum(
      canSee: data['can_see'] == true,
      canAdd: data['can_add'] == true,
      addProblem: data['add_problem'] as String?,
      count: (data['count'] as num?)?.toInt() ?? 0,
      photos: (data['photos'] is List ? data['photos'] as List : const [])
          .whereType<Map>()
          .map((raw) {
            final photo = Map<String, dynamic>.from(raw);
            final author = photo['author'] is Map ? photo['author'] as Map : const {};
            return AlbumPhoto(
              id: '${photo['id']}',
              url: photo['url'] as String? ?? '',
              thumbUrl: photo['thumb_url'] as String? ?? photo['url'] as String? ?? '',
              caption: photo['caption'] as String?,
              author: JolFriendFace(
                id: '${author['id']}',
                name: author['name'] as String? ?? 'Guest',
                avatarUrl: _url(author['avatar_url']),
              ),
              mine: photo['mine'] == true,
              canRemove: photo['can_remove'] == true,
            );
          })
          .toList(growable: false),
    );
  });

  Future<void> addPhoto(String eventId, String path, {String? caption}) =>
      _call(() async {
        await _dio.post<Map<String, dynamic>>(
          '/events/${Uri.encodeComponent(eventId)}/photos',
          data: FormData.fromMap({
            'photo': await MultipartFile.fromFile(path),
            'caption': ?caption,
          }),
          options: Options(sendTimeout: const Duration(seconds: 90)),
        );
      });

  Future<void> removePhoto(String eventId, String photoId) => _call(() async {
    await _dio.delete<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/photos/$photoId',
    );
  });

  Future<void> reportPhoto(String eventId, String photoId) => _call(() async {
    await _dio.post<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/photos/$photoId/report',
    );
  });

  Future<List<Memory>> memories() => _call(() async {
    final response = await _dio.get<Map<String, dynamic>>('/me/memories');
    final data = response.data?['data'];
    return (data is List ? data : const [])
        .whereType<Map>()
        .map(
          (item) => Memory(
            eventId: '${item['id']}',
            title: item['title'] as String? ?? 'Event',
            start: DateTime.tryParse(item['start_time'] as String? ?? '')?.toLocal(),
            place: item['location_name'] as String?,
            imageUrl: _url(item['album_thumb_url']) ?? _url(item['cover_image_url']),
            photoCount: (item['photo_count'] as num?)?.toInt() ?? 0,
            myRating: (item['my_rating'] as num?)?.toInt(),
          ),
        )
        .toList(growable: false);
  });

  Future<Achievements> achievements() => _call(() async {
    final data = _data(await _dio.get<Map<String, dynamic>>('/me/achievements'));
    return Achievements(
      points: (data['points'] as num?)?.toInt() ?? 0,
      eventsAttended: (data['events_attended'] as num?)?.toInt() ?? 0,
      eventsHosted: (data['events_hosted'] as num?)?.toInt() ?? 0,
      streakMonths: (data['streak_months'] as num?)?.toInt() ?? 0,
      badges: (data['badges'] is List ? data['badges'] as List : const [])
          .whereType<Map>()
          .map(
            (badge) => JolBadge(
              label: badge['label'] as String? ?? '',
              hint: badge['hint'] as String? ?? '',
              earned: badge['earned'] == true,
            ),
          )
          .toList(growable: false),
    );
  });

  // ---- Wallet passes -------------------------------------------------------

  /// Links for Apple Wallet and Google Wallet; null when JOL hasn't set one up.
  Future<({String? apple, String? google})> walletLinks(String ticketId) =>
      _call(() async {
        final data = _data(
          await _dio.get<Map<String, dynamic>>('/tickets/$ticketId/wallet'),
        );
        return (apple: _url(data['apple_url']), google: _url(data['google_url']));
      });

  // ---- Polls -----------------------------------------------------------------

  Future<EventPolls> polls(String eventId) => _call(() async {
    final data = _data(
      await _dio.get<Map<String, dynamic>>('/events/${Uri.encodeComponent(eventId)}/polls'),
    );
    return EventPolls(
      canVote: data['can_vote'] == true,
      canManage: data['can_manage'] == true,
      polls: (data['polls'] is List ? data['polls'] as List : const [])
          .whereType<Map>()
          .map((poll) => EventPoll.fromJson(Map<String, dynamic>.from(poll)))
          .toList(growable: false),
    );
  });

  Future<void> vote(String eventId, String pollId, int option) => _call(() async {
    await _dio.post<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/polls/$pollId/vote',
      data: {'option': option},
    );
  });

  Future<void> createPoll(String eventId, String question, List<String> options) =>
      _call(() async {
        await _dio.post<Map<String, dynamic>>(
          '/events/${Uri.encodeComponent(eventId)}/polls',
          data: {'question': question, 'options': options},
        );
      });

  Future<void> deletePoll(String eventId, String pollId) => _call(() async {
    await _dio.delete<Map<String, dynamic>>(
      '/events/${Uri.encodeComponent(eventId)}/polls/$pollId',
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
