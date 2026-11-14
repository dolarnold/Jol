import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/api/api_client.dart';
import '../../../data/booking/booking_repository.dart';
import '../../../ui/theme/jol_theme.dart';
import '../../../ui/widgets/jol_button.dart';
import '../../../ui/widgets/jol_card.dart';
import '../../../ui/widgets/jol_list_row.dart';
import '../../../ui/widgets/jol_toast.dart';
import '../../discover/data/event_repository.dart';
import '../../discover/models/jol_event.dart';
import '../../discover/screens/attendee_discovery_screens.dart';
import '../../discover/widgets/attendee_components.dart';
import '../../discover/widgets/jol_poster.dart';
import '../../maps/location_picker_screen.dart';
import '../../maps/maps_repository.dart';
import '../data/hosting_repository.dart';

/// Create a new event, or edit one ([existing]). Casual hosting limits:
/// at most R250 per ticket and 400 people.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.existing});

  final JolEvent? existing;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

/// Controllers for one ticket type the host is adding.
class _TierFields {
  _TierFields({String name = ''}) : name = TextEditingController(text: name);

  final TextEditingController name;
  final description = TextEditingController();
  final price = TextEditingController();
  final capacity = TextEditingController();
  final maxPerOrder = TextEditingController();

  int get priceValue => int.tryParse(price.text.trim()) ?? 0;
  int get capacityValue => int.tryParse(capacity.text.trim()) ?? 0;

  TierDraft toDraft() => TierDraft(
    name: name.text.trim(),
    description: description.text.trim(),
    price: priceValue,
    capacity: capacityValue,
    maxPerOrder: int.tryParse(maxPerOrder.text.trim()),
  );

  void dispose() {
    for (final controller in [name, description, price, capacity, maxPerOrder]) {
      controller.dispose();
    }
  }
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  static const _categories = ['nightlife', 'fitness', 'networking'];
  static const _maxPrice = 250;
  static const _maxPeople = 400;
  static const _maxTicketValue = 20000;
  static const _posterLabels = {
    'sunset': 'Sunset',
    'boldType': 'Bold type',
    'halftone': 'Halftone',
    'stripes': 'Stripes',
    'glow': 'Glow',
    'split': 'Split',
  };

  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _address = TextEditingController();
  final _description = TextEditingController();
  final _rsvpLimit = TextEditingController();
  final _studentDiscount = TextEditingController();
  final _commission = TextEditingController();
  final _fundTitle = TextEditingController(text: 'Food & drinks fund');
  final _fundDescription = TextEditingController();
  final _fundSuggested = TextEditingController();
  final _fundTarget = TextEditingController();
  final List<_TierFields> _tiers = [];

  var _category = _categories.first;
  DateTime? _date;
  TimeOfDay _start = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 23, minute: 0);
  double? _latitude;
  double? _longitude;
  XFile? _cover;
  String? _existingCoverUrl;
  String? _posterStyle;
  var _isPrivate = false;
  var _isAgeRestricted = false;
  var _cameraFilter = true;
  var _isPaid = false;
  var _allowTransfer = false;
  var _allowPlusOnes = true;
  var _maxPlusOnes = 1;
  TimeOfDay? _cutoff;
  var _hasFund = false;
  var _hadFund = false;
  var _commissionType = 'percentage';
  var _saving = false;
  String? _error;

  JolEvent? get _existing => widget.existing;
  bool get _isEdit => _existing != null;

  /// Tickets already on the event (edit only); kept as they are.
  List<JolTicketTier> get _existingTiers => _existing?.tiers ?? const [];

  @override
  void initState() {
    super.initState();
    final event = _existing;
    if (event == null) {
      _tiers.add(_TierFields(name: 'General'));
      return;
    }
    _title.text = event.title;
    if (_categories.contains(event.category)) _category = event.category;
    final starts = event.startsAt ?? event.date;
    final ends = event.endsAt ?? starts.add(const Duration(hours: 3));
    _date = DateTime(starts.year, starts.month, starts.day);
    _start = TimeOfDay.fromDateTime(starts);
    _end = TimeOfDay.fromDateTime(ends);
    _venue.text = event.locationName ?? '';
    _address.text = event.rawAddress ?? '';
    _latitude = event.latitude;
    _longitude = event.longitude;
    _description.text = event.description;
    _existingCoverUrl = event.coverImageUrl;
    _posterStyle = event.posterStyleName;
    _isPrivate = event.isPrivate;
    _isAgeRestricted = event.isAgeRestricted;
    _cameraFilter = event.cameraFilter;
    _isPaid = event.tiers.isNotEmpty;
    _allowTransfer = event.canTransfer;
    _allowPlusOnes = event.maxPlusOnes > 0;
    _maxPlusOnes = event.maxPlusOnes.clamp(1, 5);
    if (event.rsvpCapacity > 0) _rsvpLimit.text = '${event.rsvpCapacity}';
    if (event.guestlistCutoffAt != null) {
      _cutoff = TimeOfDay.fromDateTime(event.guestlistCutoffAt!);
    }
    if (event.studentDiscountPercent != null) {
      _studentDiscount.text = _number(event.studentDiscountPercent!);
    }
    if (event.promoterCommissionType != null &&
        event.promoterCommissionValue != null) {
      _commissionType = event.promoterCommissionType!;
      _commission.text = _number(event.promoterCommissionValue!);
    }
    if (event.fundTitle != null) {
      _hasFund = true;
      _hadFund = true;
      _fundTitle.text = event.fundTitle!;
      _fundDescription.text = event.fundDescription ?? '';
      if (event.fundSuggested > 0) _fundSuggested.text = '${event.fundSuggested}';
      if (event.fundGoal > 0) _fundTarget.text = '${event.fundGoal}';
    }
  }

  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';

  @override
  void dispose() {
    for (final controller in [
      _title,
      _venue,
      _address,
      _description,
      _rsvpLimit,
      _studentDiscount,
      _commission,
      _fundTitle,
      _fundDescription,
      _fundSuggested,
      _fundTarget,
    ]) {
      controller.dispose();
    }
    for (final tier in _tiers) {
      tier.dispose();
    }
    super.dispose();
  }

  DateTime _at(DateTime date, TimeOfDay time) =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  DateTime get _startAt => _at(_date!, _start);

  DateTime get _endAt {
    final end = _at(_date!, _end);
    return end.isAfter(_startAt) ? end : end.add(const Duration(days: 1));
  }

  /// A cutoff earlier than the start (e.g. 01:00 for a 22:00 party) means
  /// after midnight.
  DateTime? get _cutoffAt {
    final cutoff = _cutoff;
    if (cutoff == null || _date == null) return null;
    final value = _at(_date!, cutoff);
    return value.isBefore(_startAt) && cutoff.hour < 12
        ? value.add(const Duration(days: 1))
        : value;
  }

  int get _existingCapacity => _existingTiers.fold<int>(
    0,
    (sum, tier) => sum + (tier.remaining ?? 0),
  );

  int get _totalPeople =>
      _existingCapacity +
      _tiers.fold<int>(0, (sum, tier) => sum + tier.capacityValue);

  int get _totalValue =>
      _existingTiers.fold<int>(
        0,
        (sum, tier) => sum + tier.price * (tier.remaining ?? 0),
      ) +
      _tiers.fold<int>(
        0,
        (sum, tier) => sum + tier.priceValue * tier.capacityValue,
      );

  /// Ticket types with nothing typed in are ignored.
  List<_TierFields> get _filledTiers => _tiers
      .where(
        (tier) =>
            tier.name.text.trim().isNotEmpty ||
            tier.price.text.trim().isNotEmpty ||
            tier.capacity.text.trim().isNotEmpty,
      )
      .toList();

  String? _validate({required bool publishing}) {
    if (_title.text.trim().isEmpty) return 'Give your event a name.';
    if (_date == null) return 'Pick a date.';
    if (!_startAt.isAfter(DateTime.now())) {
      return 'The start time must be in the future.';
    }
    if (publishing && _venue.text.trim().isEmpty && _latitude == null) {
      return 'Add where the event is happening.';
    }
    if (_isPaid) {
      final tiers = _filledTiers;
      if (tiers.isEmpty && _existingTiers.isEmpty) {
        return 'Add at least one ticket type.';
      }
      for (final tier in tiers) {
        if (tier.name.text.trim().isEmpty) return 'Name each ticket type.';
        final label = tier.name.text.trim();
        if (tier.priceValue < 1) return 'Enter a price for $label.';
        if (tier.priceValue > _maxPrice) {
          return 'Tickets can be at most R$_maxPrice.';
        }
        if (tier.capacityValue < 1) return 'Enter how many $label tickets.';
        final max = tier.maxPerOrder.text.trim();
        if (max.isNotEmpty) {
          final value = int.tryParse(max);
          if (value == null || value < 1 || value > 50) {
            return 'Tickets per person must be between 1 and 50.';
          }
        }
      }
      if (_totalPeople > _maxPeople) {
        return 'You can sell at most $_maxPeople tickets in total.';
      }
      if (_totalValue > _maxTicketValue) {
        return 'Lower the prices or the number of tickets.';
      }
      final discount = _studentDiscount.text.trim();
      if (discount.isNotEmpty) {
        final value = double.tryParse(discount);
        if (value == null || value < 0 || value > 100) {
          return 'Student discount must be between 0 and 100%.';
        }
      }
      final commission = _commission.text.trim();
      if (commission.isNotEmpty) {
        final value = double.tryParse(commission);
        if (value == null || value < 0) {
          return 'Enter a valid promoter commission.';
        }
        if (_commissionType == 'percentage' && value > 100) {
          return 'Promoter commission can be at most 100%.';
        }
        final cheapest = [
          ..._existingTiers.map((tier) => tier.price),
          ...tiers.map((tier) => tier.priceValue),
        ].fold<int?>(null, (low, price) => low == null || price < low ? price : low);
        if (_commissionType == 'fixed' && cheapest != null && value > cheapest) {
          return 'Promoter commission can’t be more than the cheapest ticket.';
        }
      }
    } else {
      final limit = _rsvpLimit.text.trim();
      if (limit.isNotEmpty) {
        final value = int.tryParse(limit);
        if (value == null || value < 1) return 'Enter a valid guest limit.';
        if (value > _maxPeople) {
          return 'Free events can have at most $_maxPeople guests.';
        }
      }
      if (_hasFund) {
        if (_fundTitle.text.trim().isEmpty) return 'Name the fund.';
        final suggested = int.tryParse(_fundSuggested.text.trim());
        if (suggested == null || suggested < 1) {
          return 'Enter a suggested contribution.';
        }
        final target = _fundTarget.text.trim();
        if (target.isNotEmpty && (int.tryParse(target) ?? 0) < 1) {
          return 'Enter a valid fund goal.';
        }
      }
    }
    return null;
  }

  EventDraft _draft() {
    final commission = double.tryParse(_commission.text.trim());
    return EventDraft(
      title: _title.text.trim(),
      category: _category,
      start: _startAt,
      end: _endAt,
      description: _description.text.trim(),
      venue: _venue.text.trim(),
      address: _address.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      isPrivate: _isPrivate,
      isAgeRestricted: _isAgeRestricted,
      cameraFilter: _cameraFilter,
      posterStyle: _posterStyle,
      coverImagePath: _cover?.path,
      allowTicketTransfer: _isPaid && _allowTransfer,
      allowPlusOnes: !_isPaid && _allowPlusOnes,
      maxPlusOnes: _maxPlusOnes,
      rsvpCapacity: _isPaid ? null : int.tryParse(_rsvpLimit.text.trim()),
      guestlistCutoffAt: _isPaid ? null : _cutoffAt,
      studentDiscountPercent: _isPaid
          ? double.tryParse(_studentDiscount.text.trim())
          : null,
      promoterCommissionType: _isPaid && commission != null
          ? _commissionType
          : null,
      promoterCommissionValue: _isPaid ? commission : null,
    );
  }

  FundDraft? _fund() => !_isPaid && _hasFund
      ? FundDraft(
          title: _fundTitle.text.trim(),
          description: _fundDescription.text.trim(),
          suggestedAmount: int.parse(_fundSuggested.text.trim()),
          targetAmount: int.tryParse(_fundTarget.text.trim()),
        )
      : null;

  Future<void> _save({required String status}) async {
    final problem = _validate(publishing: status == 'published');
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(hostingRepositoryProvider)
          .saveEvent(
            eventId: _existing?.id,
            draft: _draft(),
            status: status,
            newTiers: _isPaid
                ? _filledTiers.map((tier) => tier.toDraft()).toList()
                : const [],
            fund: _fund(),
            removeFund: _hadFund && (_isPaid || !_hasFund),
          );
      ref.invalidate(myEventsProvider);
      ref.invalidate(attendeeEventsProvider);
      ref.invalidate(attendeeEventProvider(id));
      if (!mounted) return;
      JolToast.show(
        context,
        status == 'draft'
            ? 'Draft saved. Publish it from Hosting when you’re ready.'
            : _isEdit && !(_existing?.isDraft ?? false)
            ? 'Your changes are saved.'
            : 'Your event is live.',
      );
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _preview() {
    if (_title.text.trim().isEmpty || _date == null) {
      setState(() => _error = 'Add a name and date to preview your event.');
      return;
    }
    setState(() => _error = null);
    final tiers = [
      ..._existingTiers,
      if (_isPaid)
        for (final (index, tier) in _filledTiers.indexed)
          JolTicketTier(
            id: 'new-$index',
            name: tier.name.text.trim().isEmpty ? 'Ticket' : tier.name.text.trim(),
            price: tier.priceValue,
            description: tier.description.text.trim(),
            remaining: tier.capacityValue,
            maxPerOrder: int.tryParse(tier.maxPerOrder.text.trim()),
          ),
    ];
    final fund = _hasFund && !_isPaid && _fundTitle.text.trim().isNotEmpty
        ? FundDraft(
            title: _fundTitle.text.trim(),
            suggestedAmount: int.tryParse(_fundSuggested.text.trim()) ?? 0,
            targetAmount: int.tryParse(_fundTarget.text.trim()),
          )
        : null;
    final event = previewEvent(
      draft: _draft(),
      host: _existing?.host ?? 'You',
      tiers: _isPaid ? tiers : const [],
      fund: fund,
      existingCoverUrl: _cover == null ? _existingCoverUrl : null,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventPreviewScreen(
          event: event,
          coverFile: _cover == null ? null : File(_cover!.path),
        ),
      ),
    );
  }

  Future<void> _pickLocation() async {
    final initial = _latitude != null && _longitude != null
        ? PickedLocation(
            latitude: _latitude!,
            longitude: _longitude!,
            address: _address.text.trim(),
            area: 'Cape Town',
            name: _venue.text.trim().isEmpty ? null : _venue.text.trim(),
          )
        : null;
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: initial)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
      if (picked.address.isNotEmpty) _address.text = picked.address;
      if (picked.name != null && picked.name!.isNotEmpty) {
        _venue.text = picked.name!;
      }
    });
  }

  Future<void> _pickCover(ImageSource source) async {
    try {
      // Resize on the phone so uploads stay under the 5 MB server limit.
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (picked != null && mounted) setState(() => _cover = picked);
    } catch (_) {
      if (mounted) {
        JolToast.show(
          context,
          'Could not open your photos. Check app permissions.',
        );
      }
    }
  }

  void _chooseCover() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickCover(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickCover(ImageSource.camera);
              },
            ),
            if (_cover != null || _existingCoverUrl != null)
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Use a JOL poster instead'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _cover = null;
                    _existingCoverUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<TimeOfDay?> _time(TimeOfDay initial) =>
      showTimePicker(context: context, initialTime: initial);

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final theme = Theme.of(context);
    final isDraftOrNew = !_isEdit || (_existing?.isDraft ?? false);
    final hasPhoto = _cover != null || _existingCoverUrl != null;
    final previewDate = _date ?? DateTime.now();
    final posterStyle =
        JolPosterStyle.values
            .where((style) => style.name == _posterStyle)
            .firstOrNull ??
        JolPosterStyle.values[_category.codeUnits.fold<int>(
              0,
              (value, unit) => value + unit,
            ) %
            JolPosterStyle.values.length];

    Widget section(String title) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(title.toUpperCase(), style: theme.textTheme.labelSmall),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'edit event' : 'create event'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _preview,
            child: const Text('Preview'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          // ---- Poster ---------------------------------------------------
          AspectRatio(
            aspectRatio: 4 / 5,
            child: Material(
              color: tokens.surface2,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _saving ? null : _chooseCover,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    fit: StackFit.expand,
                    children: [
                      JolPoster(
                        style: posterStyle,
                        primary: const Color(0xFFE8792E),
                        secondary: const Color(0xFF16223F),
                        title: _title.text.trim().isEmpty
                            ? 'Your event'
                            : _title.text.trim(),
                        dateStamp: eventDateStamp(previewDate),
                        area: _address.text.split(',').last.trim().isEmpty
                            ? null
                            : _address.text.split(',').last.trim(),
                        size: constraints.biggest,
                        imageFile: _cover == null ? null : File(_cover!.path),
                        imageUrl: _existingCoverUrl,
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: FilledButton.tonalIcon(
                          onPressed: _saving ? null : _chooseCover,
                          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                          label: Text(hasPhoto ? 'Change photo' : 'Add photo'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!hasPhoto) ...[
            const SizedBox(height: 10),
            Text(
              'No photo? Pick a JOL poster style.',
              style: TextStyle(color: tokens.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Auto'),
                  selected: _posterStyle == null,
                  onSelected: (_) => setState(() => _posterStyle = null),
                ),
                for (final entry in _posterLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _posterStyle == entry.key,
                    onSelected: (_) =>
                        setState(() => _posterStyle = entry.key),
                  ),
              ],
            ),
          ],

          // ---- Basics ---------------------------------------------------
          section('the basics'),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Event name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in _categories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) => setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'About this event'),
          ),

          // ---- When -----------------------------------------------------
          section('when'),
          JolListRow(
            title: _date == null ? 'Pick a date' : formatEventDate(_date!),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: now.add(const Duration(days: 365)),
                initialDate: _date ?? now,
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          Row(
            children: [
              Expanded(
                child: JolListRow(
                  title: 'Starts ${_start.format(context)}',
                  onTap: () async {
                    final picked = await _time(_start);
                    if (picked != null) setState(() => _start = picked);
                  },
                ),
              ),
              Expanded(
                child: JolListRow(
                  title: 'Ends ${_end.format(context)}',
                  onTap: () async {
                    final picked = await _time(_end);
                    if (picked != null) setState(() => _end = picked);
                  },
                ),
              ),
            ],
          ),

          // ---- Where ----------------------------------------------------
          section('where'),
          JolCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: JolListRow(
              title: _latitude == null ? 'Pin it on the map' : 'Pinned on the map',
              subtitle: _latitude == null
                  ? 'Search an address or use your location'
                  : 'Tap to move the pin',
              trailing: Icon(
                _latitude == null ? Icons.add_location_alt_outlined : Icons.edit_location_alt_outlined,
              ),
              onTap: _saving ? null : _pickLocation,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _venue,
            decoration: const InputDecoration(labelText: 'Venue name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Address',
              helperText: 'End with the area, e.g. "12 Bree St, City Centre"',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Private event'),
            subtitle: const Text(
              'Only people with the invite code can find it. The exact '
              'location shows once they RSVP or get a ticket.',
            ),
            value: _isPrivate,
            onChanged: (value) => setState(() => _isPrivate = value),
          ),

          // ---- Entry ----------------------------------------------------
          section('entry'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('18+ event'),
            subtitle: const Text(
              'Shown on tickets. Door staff are told to check ID.',
            ),
            value: _isAgeRestricted,
            onChanged: (value) => setState(() => _isAgeRestricted = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Digital camera filter'),
            subtitle: const Text('Give guests’ photos the JOL cam look'),
            value: _cameraFilter,
            onChanged: (value) => setState(() => _cameraFilter = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sell tickets'),
            subtitle: Text(
              _existingTiers.isNotEmpty
                  ? 'This event already has tickets'
                  : 'Off means a free RSVP event',
            ),
            value: _isPaid,
            // Can't turn tickets off once ticket types exist.
            onChanged: _existingTiers.isNotEmpty
                ? null
                : (value) => setState(() => _isPaid = value),
          ),

          if (_isPaid) ..._ticketFields(tokens, theme) else ..._freeFields(tokens),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          JolButton(
            label: _saving
                ? 'Saving…'
                : isDraftOrNew
                ? 'Publish event'
                : 'Save changes',
            expanded: true,
            onPressed: _saving ? null : () => _save(status: 'published'),
          ),
          if (isDraftOrNew) ...[
            const SizedBox(height: 10),
            JolButton(
              label: 'Save as draft',
              expanded: true,
              variant: JolButtonVariant.ghost,
              onPressed: _saving ? null : () => _save(status: 'draft'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _ticketFields(JolTokens tokens, ThemeData theme) => [
    const SizedBox(height: 8),
    for (final tier in _existingTiers)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: JolCard(
          border: true,
          child: JolListRow(
            title: tier.name,
            subtitle:
                '${formatZar(tier.price)} · '
                '${tier.remaining == null ? 'no limit' : '${tier.remaining} left'}'
                '${tier.maxPerOrder == null ? '' : ' · max ${tier.maxPerOrder} each'}',
            trailing: Icon(Icons.lock_outline, color: tokens.muted, size: 18),
          ),
        ),
      ),
    for (final (index, tier) in _tiers.indexed)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: JolCard(
          border: true,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tier.name,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Ticket name',
                        hintText: index == 0 ? 'General' : 'e.g. VIP',
                      ),
                    ),
                  ),
                  if (_tiers.length > 1 || _existingTiers.isNotEmpty)
                    IconButton(
                      tooltip: 'Remove ticket type',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() {
                        _tiers.removeAt(index).dispose();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: tier.description,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'e.g. Entry before 10pm',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: tier.price,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixText: 'R ',
                        helperText: 'Up to R$_maxPrice',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: tier.capacity,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Tickets'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: tier.maxPerOrder,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max each',
                        helperText: 'Optional',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => _tiers.add(_TierFields())),
        icon: const Icon(Icons.add),
        label: const Text('Add ticket type'),
      ),
    ),
    Text(
      '$_totalPeople of $_maxPeople people · '
      'total ticket value ${formatZar(_totalValue)}',
      style: TextStyle(color: tokens.muted),
    ),
    const SizedBox(height: 8),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Allow ticket transfer'),
      subtitle: const Text('Guests can send their ticket to someone else'),
      value: _allowTransfer,
      onChanged: (value) => setState(() => _allowTransfer = value),
    ),
    const SizedBox(height: 4),
    TextField(
      controller: _studentDiscount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: 'Student discount (optional)',
        suffixText: '%',
        helperText: 'For verified students',
      ),
    ),
    const SizedBox(height: 16),
    Text('Promoter commission', style: theme.textTheme.titleSmall),
    const SizedBox(height: 8),
    SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'percentage', label: Text('% of ticket')),
        ButtonSegment(value: 'fixed', label: Text('R per ticket')),
      ],
      selected: {_commissionType},
      showSelectedIcon: false,
      onSelectionChanged: (value) =>
          setState(() => _commissionType = value.first),
    ),
    const SizedBox(height: 8),
    TextField(
      controller: _commission,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: _commissionType == 'percentage'
            ? 'Commission (optional)'
            : 'Amount per ticket (optional)',
        prefixText: _commissionType == 'fixed' ? 'R ' : null,
        suffixText: _commissionType == 'percentage' ? '%' : null,
        helperText: 'Leave empty to use the JOL default',
      ),
    ),
  ];

  List<Widget> _freeFields(JolTokens tokens) => [
    const SizedBox(height: 4),
    TextField(
      controller: _rsvpLimit,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Guest limit (optional)',
        helperText: 'Up to $_maxPeople, plus-ones count. Empty means no limit.',
      ),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Allow plus-ones'),
      value: _allowPlusOnes,
      onChanged: (value) => setState(() => _allowPlusOnes = value),
    ),
    if (_allowPlusOnes)
      DropdownButtonFormField<int>(
        initialValue: _maxPlusOnes,
        decoration: const InputDecoration(labelText: 'Plus-ones per guest'),
        items: [
          for (var count = 1; count <= 5; count++)
            DropdownMenuItem(value: count, child: Text('Up to $count')),
        ],
        onChanged: (value) =>
            setState(() => _maxPlusOnes = value ?? _maxPlusOnes),
      ),
    const SizedBox(height: 4),
    JolListRow(
      title: _cutoff == null
          ? 'RSVPs close: when the event starts'
          : 'RSVPs close at ${_cutoff!.format(context)}',
      subtitle: 'Guestlist cutoff',
      trailing: _cutoff == null
          ? const Icon(Icons.schedule)
          : IconButton(
              tooltip: 'Remove cutoff',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _cutoff = null),
            ),
      onTap: () async {
        final picked = await _time(_cutoff ?? _start);
        if (picked != null) setState(() => _cutoff = picked);
      },
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Contribution fund'),
      subtitle: const Text('Guests can chip in, e.g. for food and drinks'),
      value: _hasFund,
      onChanged: (value) => setState(() => _hasFund = value),
    ),
    if (_hasFund) ...[
      TextField(
        controller: _fundTitle,
        decoration: const InputDecoration(labelText: 'Fund name'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _fundDescription,
        decoration: const InputDecoration(
          labelText: 'What it’s for (optional)',
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _fundSuggested,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Suggested amount',
                prefixText: 'R ',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _fundTarget,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Goal (optional)',
                prefixText: 'R ',
              ),
            ),
          ),
        ],
      ),
    ],
  ];
}
