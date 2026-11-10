import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AttendeeSearchTab { all, events, organisers, people }

enum AppAccessMode { attendee, host, staff }

enum MockPaymentOutcome { success, declined, pending }

@immutable
class AttendeeState {
  const AttendeeState({
    this.selectedDate,
    this.location = 'Cape Town',
    this.currentEventId = 'sundowner',
    this.selectedTierId = 'general',
    this.quantity = 2,
    this.searchQuery = '',
    this.searchTab = AttendeeSearchTab.all,
    this.paymentOutcome = MockPaymentOutcome.success,
    this.paymentMethod = 'Card',
    this.isStudentVerified = false,
    this.studentEmail = 'lerato@myuct.ac.za',
    this.selectedInterests = const {'nightlife', 'networking'},
    this.followedOrganisers = const {},
    this.followedPeople = const {},
    this.savedEvents = const {},
    this.joinedGuestlists = const {},
    this.rsvpEvents = const {},
    this.privacyPublicProfile = true,
    this.privacyGuestlists = true,
    this.privacyAttending = false,
    this.ticketIndex = 0,
    this.scannedTickets = const {},
    this.transferredTickets = const {},
    this.guestlistPlusOne = false,
    this.rsvpPlusOne = 1,
    this.contributionAmount = 100,
    this.contributionAnonymous = false,
    this.isOffline = false,
    this.accessMode = AppAccessMode.attendee,
  });

  final DateTime? selectedDate;
  final String location;
  final String currentEventId;
  final String selectedTierId;
  final int quantity;
  final String searchQuery;
  final AttendeeSearchTab searchTab;
  final MockPaymentOutcome paymentOutcome;
  final String paymentMethod;
  final bool isStudentVerified;
  final String studentEmail;
  final Set<String> selectedInterests;
  final Set<String> followedOrganisers;
  final Set<String> followedPeople;
  final Set<String> savedEvents;
  final Set<String> joinedGuestlists;
  final Set<String> rsvpEvents;
  final bool privacyPublicProfile;
  final bool privacyGuestlists;
  final bool privacyAttending;
  final int ticketIndex;
  final Set<String> scannedTickets;
  final Set<String> transferredTickets;
  final bool guestlistPlusOne;
  final int rsvpPlusOne;
  final int contributionAmount;
  final bool contributionAnonymous;
  final bool isOffline;
  final AppAccessMode accessMode;

  AttendeeState copyWith({
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    String? location,
    String? currentEventId,
    String? selectedTierId,
    int? quantity,
    String? searchQuery,
    AttendeeSearchTab? searchTab,
    MockPaymentOutcome? paymentOutcome,
    String? paymentMethod,
    bool? isStudentVerified,
    String? studentEmail,
    Set<String>? selectedInterests,
    Set<String>? followedOrganisers,
    Set<String>? followedPeople,
    Set<String>? savedEvents,
    Set<String>? joinedGuestlists,
    Set<String>? rsvpEvents,
    bool? privacyPublicProfile,
    bool? privacyGuestlists,
    bool? privacyAttending,
    int? ticketIndex,
    Set<String>? scannedTickets,
    Set<String>? transferredTickets,
    bool? guestlistPlusOne,
    int? rsvpPlusOne,
    int? contributionAmount,
    bool? contributionAnonymous,
    bool? isOffline,
    AppAccessMode? accessMode,
  }) {
    return AttendeeState(
      selectedDate: clearSelectedDate
          ? null
          : selectedDate ?? this.selectedDate,
      location: location ?? this.location,
      currentEventId: currentEventId ?? this.currentEventId,
      selectedTierId: selectedTierId ?? this.selectedTierId,
      quantity: quantity ?? this.quantity,
      searchQuery: searchQuery ?? this.searchQuery,
      searchTab: searchTab ?? this.searchTab,
      paymentOutcome: paymentOutcome ?? this.paymentOutcome,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isStudentVerified: isStudentVerified ?? this.isStudentVerified,
      studentEmail: studentEmail ?? this.studentEmail,
      selectedInterests: selectedInterests ?? this.selectedInterests,
      followedOrganisers: followedOrganisers ?? this.followedOrganisers,
      followedPeople: followedPeople ?? this.followedPeople,
      savedEvents: savedEvents ?? this.savedEvents,
      joinedGuestlists: joinedGuestlists ?? this.joinedGuestlists,
      rsvpEvents: rsvpEvents ?? this.rsvpEvents,
      privacyPublicProfile: privacyPublicProfile ?? this.privacyPublicProfile,
      privacyGuestlists: privacyGuestlists ?? this.privacyGuestlists,
      privacyAttending: privacyAttending ?? this.privacyAttending,
      ticketIndex: ticketIndex ?? this.ticketIndex,
      scannedTickets: scannedTickets ?? this.scannedTickets,
      transferredTickets: transferredTickets ?? this.transferredTickets,
      guestlistPlusOne: guestlistPlusOne ?? this.guestlistPlusOne,
      rsvpPlusOne: rsvpPlusOne ?? this.rsvpPlusOne,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      contributionAnonymous:
          contributionAnonymous ?? this.contributionAnonymous,
      isOffline: isOffline ?? this.isOffline,
      accessMode: accessMode ?? this.accessMode,
    );
  }
}

final attendeeControllerProvider =
    NotifierProvider<AttendeeController, AttendeeState>(AttendeeController.new);

class AttendeeController extends Notifier<AttendeeState> {
  @override
  AttendeeState build() => const AttendeeState();

  void setDate(DateTime? date) {
    state = state.copyWith(selectedDate: date, clearSelectedDate: date == null);
  }

  void setLocation(String location) {
    state = state.copyWith(location: location);
  }

  void setEvent(String id, {String? initialTierId}) {
    state = state.copyWith(
      currentEventId: id,
      selectedTierId: initialTierId ?? 'general',
      quantity: 2,
      ticketIndex: 0,
    );
  }

  void setInterests(Set<String> interests) {
    state = state.copyWith(selectedInterests: Set.unmodifiable(interests));
  }

  void toggleInterest(String interest) {
    final next = {...state.selectedInterests};
    if (!next.add(interest)) next.remove(interest);
    state = state.copyWith(selectedInterests: Set.unmodifiable(next));
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSearchTab(AttendeeSearchTab tab) {
    state = state.copyWith(searchTab: tab);
  }

  void selectTier(String tierId) {
    state = state.copyWith(selectedTierId: tierId, quantity: 1);
  }

  void setQuantity(int quantity) {
    state = state.copyWith(quantity: quantity.clamp(1, 6));
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void setPaymentOutcome(MockPaymentOutcome outcome) {
    state = state.copyWith(paymentOutcome: outcome);
  }

  void verifyStudent(String email) {
    state = state.copyWith(isStudentVerified: true, studentEmail: email.trim());
  }

  void toggleFollowOrganiser(String organiser) {
    final next = {...state.followedOrganisers};
    if (!next.add(organiser)) next.remove(organiser);
    state = state.copyWith(followedOrganisers: Set.unmodifiable(next));
  }

  void toggleFollowPerson(String username) {
    final next = {...state.followedPeople};
    if (!next.add(username)) next.remove(username);
    state = state.copyWith(followedPeople: Set.unmodifiable(next));
  }

  void toggleSavedEvent(String eventId) {
    final next = {...state.savedEvents};
    if (!next.add(eventId)) next.remove(eventId);
    state = state.copyWith(savedEvents: Set.unmodifiable(next));
  }

  void joinGuestlist(String eventId, {required bool plusOne}) {
    state = state.copyWith(
      joinedGuestlists: Set.unmodifiable({...state.joinedGuestlists, eventId}),
      guestlistPlusOne: plusOne,
    );
  }

  void rsvp(String eventId, {required int plusOne}) {
    state = state.copyWith(
      rsvpEvents: Set.unmodifiable({...state.rsvpEvents, eventId}),
      rsvpPlusOne: plusOne,
    );
  }

  void setGuestlistPlusOne(bool value) {
    state = state.copyWith(guestlistPlusOne: value);
  }

  void setRsvpPlusOne(int value) {
    state = state.copyWith(rsvpPlusOne: value.clamp(0, 1));
  }

  void setTicketIndex(int index) {
    state = state.copyWith(ticketIndex: index.clamp(0, 1));
  }

  void markTicketScanned(String ticketId) {
    state = state.copyWith(
      scannedTickets: Set.unmodifiable({...state.scannedTickets, ticketId}),
    );
  }

  void transferTicket(String ticketId) {
    state = state.copyWith(
      transferredTickets: Set.unmodifiable({
        ...state.transferredTickets,
        ticketId,
      }),
    );
  }

  void setContributionAmount(int amount) {
    state = state.copyWith(contributionAmount: amount.clamp(1, 200));
  }

  void setContributionAnonymous(bool value) {
    state = state.copyWith(contributionAnonymous: value);
  }

  void setPrivacy({bool? publicProfile, bool? guestlists, bool? attending}) {
    state = state.copyWith(
      privacyPublicProfile: publicProfile,
      privacyGuestlists: guestlists,
      privacyAttending: attending,
    );
  }

  void resetSession() {
    state = const AttendeeState();
  }

  void setAccessMode(AppAccessMode mode) {
    state = state.copyWith(accessMode: mode);
  }

  void setOffline(bool value) {
    state = state.copyWith(isOffline: value);
  }
}
