import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme/jol_theme.dart';
import '../../ui/widgets/jol_button.dart';
import '../../ui/widgets/jol_card.dart';
import '../../ui/widgets/jol_list_row.dart';
import '../../ui/widgets/jol_toast.dart';
import 'door_repository.dart';
import 'qr_scanner_view.dart';

/// The door of one event: scan tickets, tick guests off the list and sell at
/// the door. Once the list is saved on the phone it keeps working without
/// signal and sends everything when the signal is back.
class DoorScreen extends ConsumerStatefulWidget {
  const DoorScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<DoorScreen> createState() => _DoorScreenState();
}

class _DoorScreenState extends ConsumerState<DoorScreen> {
  DoorInfo? _info;
  String? _loadError;
  DoorList? _list;
  var _pending = 0;
  var _online = true;
  var _busyList = false;
  var _syncing = false;
  Timer? _timer;

  // Scan
  final _code = TextEditingController();
  var _checking = false;
  ScanOutcome? _result;
  final _history = <_Checked>[];

  // Guest list
  final _search = TextEditingController();
  Timer? _searchDebounce;
  var _guests = <DoorGuest>[];
  var _holders = <DoorTicketHolder>[];
  var _guestsLoading = false;

  // Sell
  int? _tierId;
  var _quantity = 1;
  final _price = TextEditingController();
  var _method = 'cash';
  final _buyerName = TextEditingController();
  final _buyerPhone = TextEditingController();
  var _selling = false;

  DoorRepository get _repo => ref.read(doorRepositoryProvider);
  String get _eventId => widget.eventId;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchDebounce?.cancel();
    _code.dispose();
    _search.dispose();
    _price.dispose();
    _buyerName.dispose();
    _buyerPhone.dispose();
    super.dispose();
  }

  // ---- Loading, saving the list and syncing --------------------------------

  Future<void> _load() async {
    final list = await _repo.loadList(_eventId);
    final pending = await _repo.loadPending(_eventId);
    if (!mounted) return;
    setState(() {
      _list = list;
      _pending = pending.count;
    });
    try {
      final info = await _repo.info(_eventId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _online = true;
        _loadError = null;
        _pickTier(info.tiers);
      });
      if (_pending > 0) unawaited(_sync(quiet: true));
    } on DoorException catch (error) {
      if (!mounted) return;
      setState(() {
        _online = !error.offline;
        _loadError = error.message;
        // No signal but a saved list: work from it.
        if (list != null) {
          _info = DoorInfo.fromList(list);
          _pickTier(list.tiers);
        }
      });
    }
    unawaited(_loadGuests());
  }

  void _pickTier(List<DoorTier> tiers) {
    if (tiers.isEmpty) return;
    final current = tiers.where((tier) => tier.id == _tierId).firstOrNull;
    final tier = current ?? tiers.first;
    _tierId = tier.id;
    if (current == null) _price.text = _plain(tier.price);
  }

  Future<void> _refreshPending() async {
    final pending = await _repo.loadPending(_eventId);
    if (mounted) setState(() => _pending = pending.count);
  }

  void _tick() {
    if (_pending > 0) unawaited(_sync(quiet: true));
    final savedAt = _list?.savedAt;
    // A saved list goes stale (new sales, transfers): refresh it quietly.
    if (_list != null && _online && (savedAt == null || DateTime.now().difference(savedAt) > const Duration(minutes: 10))) {
      unawaited(_download(quiet: true));
    }
    if (!_online) unawaited(_probe());
  }

  /// Is the signal back?
  Future<void> _probe() async {
    try {
      final info = await _repo.info(_eventId);
      if (!mounted) return;
      setState(() {
        _online = true;
        _loadError = null;
        _info = info;
      });
      if (_pending > 0) unawaited(_sync(quiet: true));
    } on DoorException {
      // Still no signal.
    }
  }

  Future<void> _download({bool quiet = false}) async {
    if (_busyList) return;
    setState(() => _busyList = true);
    try {
      if (_pending > 0) await _sync(quiet: true);
      final list = await _repo.downloadList(_eventId);
      if (!mounted) return;
      setState(() {
        _list = list;
        _online = true;
        _info ??= DoorInfo.fromList(list);
        _info!.summary = list.summary;
      });
      if (!quiet) {
        JolToast.show(context, 'Saved on this phone: ${list.tickets.length} tickets, ${list.guests.length} guests.');
      }
    } on DoorException catch (error) {
      if (!mounted) return;
      setState(() => _online = !error.offline);
      if (!quiet) {
        JolToast.show(context, error.offline ? 'No signal. Try again when you have signal.' : error.message);
      }
    } finally {
      if (mounted) setState(() => _busyList = false);
    }
  }

  Future<void> _sync({bool quiet = false}) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final result = await _repo.sync(_eventId);
      await _refreshPending();
      if (!mounted) return;
      setState(() {
        _online = true;
        final summary = result.summary;
        if (summary != null) _info?.summary = summary;
      });
      if (result.problems.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.problems.length == 1 ? '1 thing needs a look' : '${result.problems.length} things need a look'),
            content: SingleChildScrollView(child: Text(result.problems.join('\n\n'))),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      } else if (!quiet && mounted) {
        JolToast.show(context, 'Synced.');
      }
      unawaited(_loadGuests());
    } on DoorException catch (error) {
      if (mounted) setState(() => _online = !error.offline);
      if (!quiet && mounted) {
        JolToast.show(context, error.offline ? 'No signal. It syncs when the signal is back.' : error.message);
      }
    } finally {
      _syncing = false;
    }
  }

  // ---- Scanning -----------------------------------------------------------

  Future<void> _check(String raw) async {
    final code = normalizeTicketCode(raw);
    if (code.isEmpty || _checking) return;
    setState(() => _checking = true);

    ScanOutcome? online;
    if (_online || _list == null) {
      try {
        final (outcome, summary) = await _repo.scan(_eventId, code);
        online = outcome;
        _online = true;
        _info?.summary = summary;
      } on DoorException catch (error) {
        if (error.offline) {
          _online = false;
        } else {
          online = ScanOutcome(admit: false, message: error.message);
        }
      }
    }

    final ScanOutcome result;
    if (online != null) {
      result = online;
    } else {
      final list = _list;
      result = list == null
          ? const ScanOutcome(admit: false, offline: true, message: 'No signal and no saved list. Save the list when you have signal.')
          : await _repo.checkOffline(_eventId, list, code);
      if (result.admit) _countIn(tickets: 1);
      await _refreshPending();
    }

    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
      _history.insert(0, _Checked(code: code, outcome: result, at: DateTime.now()));
      if (_history.length > 12) _history.removeLast();
      if (result.admit) _code.clear();
    });
    unawaited(result.admit ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact());
  }

  /// Keeps the totals right while there's no signal.
  void _countIn({int tickets = 0, int guests = 0}) {
    final summary = _info?.summary;
    if (summary == null) return;
    summary
      ..ticketsIn += tickets
      ..guestsIn += guests
      ..inside += tickets + guests;
  }

  // ---- Guest list ---------------------------------------------------------

  void _onSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _loadGuests);
  }

  Future<void> _loadGuests() async {
    if (!mounted) return;
    final query = _search.text.trim();
    if (_online) {
      setState(() => _guestsLoading = true);
      try {
        final (guests, holders, summary) = await _repo.guests(_eventId, query);
        if (!mounted) return;
        setState(() {
          _guests = guests;
          _holders = holders;
          _info?.summary = summary;
          _guestsLoading = false;
        });
        return;
      } on DoorException catch (error) {
        if (!error.offline) {
          if (mounted) setState(() => _guestsLoading = false);
          return;
        }
        _online = false;
      }
    }
    // No signal: search the saved list.
    final q = query.toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    final rows = (_list?.guests ?? const <DoorGuest>[])
        .where((guest) => q.isEmpty || guest.name.toLowerCase().contains(q) || (digits.length >= 2 && (guest.phoneEnd ?? '').contains(digits)))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _guestsLoading = false;
      _guests = rows;
      _holders = [];
    });
  }

  Future<void> _letGuestIn(DoorGuest guest) async {
    var count = guest.party;
    if (guest.party > 1) {
      final chosen = await showDialog<int>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text('How many of ${guest.name}’s party are here?'),
          children: [
            for (var n = guest.party; n >= 1; n--)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, n),
                child: Text(n == guest.party ? 'All $n' : '$n'),
              ),
          ],
        ),
      );
      if (chosen == null || !mounted) return;
      count = chosen;
    }
    await _setCheckIn(guest, count);
  }

  Future<void> _undoGuest(DoorGuest guest) async {
    final sure = await _confirm('Undo letting ${guest.name} in?', 'Undo');
    if (sure) await _setCheckIn(guest, 0);
  }

  Future<void> _setCheckIn(DoorGuest guest, int count) async {
    if (_online) {
      try {
        final (updated, summary) = count == 0
            ? await _repo.undoCheckIn(_eventId, guest.id)
            : await _repo.checkIn(_eventId, guest.id, count);
        if (!mounted) return;
        setState(() {
          guest
            ..checkedInCount = updated.checkedInCount
            ..checkedInAt = updated.checkedInAt
            ..status = updated.status;
          _info?.summary = summary;
        });
        if (count > 0) unawaited(HapticFeedback.mediumImpact());
        return;
      } on DoorException catch (error) {
        if (!error.offline) {
          if (mounted) JolToast.show(context, error.message);
          return;
        }
        _online = false;
      }
    }
    final change = count - guest.checkedInCount;
    await _repo.checkInOffline(_eventId, _list, guest, count);
    _countIn(guests: change);
    await _refreshPending();
    if (!mounted) return;
    setState(() {});
    if (count > 0) JolToast.show(context, '${guest.name} let in (saved on this phone).');
  }

  Future<void> _addWalkIn() async {
    final draft = await showDialog<_WalkIn>(context: context, builder: (_) => const _WalkInDialog());
    if (draft == null || !mounted) return;
    try {
      final (guest, summary) = await _repo.walkIn(_eventId, name: draft.name, phone: draft.phone, count: draft.count);
      if (!mounted) return;
      setState(() {
        _guests = [guest, ..._guests];
        _info?.summary = summary;
      });
      JolToast.show(context, '${guest.name} added and let in.');
    } on DoorException catch (error) {
      if (mounted) JolToast.show(context, error.offline ? 'Adding walk-ins needs signal.' : error.message);
    }
  }

  Future<void> _letHolderIn(DoorTicketHolder holder) async {
    final sure = await _confirm('Have you checked their ID says ${holder.name}?', 'Let in');
    if (!sure) return;
    try {
      final (outcome, summary) = await _repo.letIn(_eventId, holder.id);
      if (!mounted) return;
      setState(() {
        _info?.summary = summary;
        _result = outcome;
        if (outcome.admit) {
          holder
            ..status = 'used'
            ..scannedAt = DateTime.now();
        }
      });
      JolToast.show(context, outcome.message);
    } on DoorException catch (error) {
      if (mounted) JolToast.show(context, error.offline ? 'Letting in by name needs signal.' : error.message);
    }
  }

  // ---- Door sales ---------------------------------------------------------

  Future<void> _setDoorSales(bool enabled) async {
    try {
      final summary = await _repo.setDoorSales(_eventId, enabled);
      if (!mounted) return;
      setState(() => _info?.summary = summary);
      JolToast.show(context, enabled ? 'Door sales are on.' : 'Door sales are off.');
    } on DoorException catch (error) {
      if (mounted) JolToast.show(context, error.offline ? 'Needs signal.' : error.message);
    }
  }

  Future<void> _sell() async {
    final info = _info;
    final tier = info?.tiers.where((item) => item.id == _tierId).firstOrNull;
    if (info == null || tier == null || _selling) return;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? tier.price;
    final sale = DoorSaleDraft(
      tierId: tier.id,
      quantity: _quantity,
      unitPrice: price < 0 ? 0.0 : price,
      method: _method,
      buyerName: _buyerName.text.trim().isEmpty ? null : _buyerName.text.trim(),
      buyerPhone: _buyerPhone.text.trim().isEmpty ? null : _buyerPhone.text.trim(),
    );
    final methodLabel = _methodLabel(info, _method);
    final sure = await _confirm('Sell $_quantity × ${tier.name} for ${_rand(sale.total)} ($methodLabel)?', 'Sell');
    if (!sure || !mounted) return;

    setState(() => _selling = true);
    try {
      if (_online) {
        try {
          final (summary, tiers) = await _repo.sell(_eventId, sale);
          if (!mounted) return;
          setState(() {
            info
              ..summary = summary
              ..tiers = tiers;
          });
          _afterSale(tier, sale, offline: false);
          unawaited(_refreshSales());
          return;
        } on DoorException catch (error) {
          if (!error.offline) {
            if (mounted) JolToast.show(context, error.message);
            return;
          }
          _online = false;
        }
      }
      final list = _list;
      if (list == null || !list.doorSales) {
        if (mounted) JolToast.show(context, 'No signal and no saved list. Save the list when you have signal to sell without signal.');
        return;
      }
      await _repo.sellOffline(_eventId, list, sale);
      final summary = info.summary;
      summary
        ..doorSalesTotal += sale.total
        ..doorSalesCount += 1
        ..doorSalesTickets += sale.quantity
        ..ticketsSold += sale.quantity;
      summary.byMethod[sale.method] = (summary.byMethod[sale.method] ?? 0) + sale.total;
      _countIn(tickets: sale.quantity);
      for (final item in info.tiers.where((item) => item.id == tier.id)) {
        final left = item.available;
        if (left != null) item.available = left > sale.quantity ? left - sale.quantity : 0;
      }
      await _refreshPending();
      _afterSale(tier, sale, offline: true);
    } finally {
      if (mounted) setState(() => _selling = false);
    }
  }

  void _afterSale(DoorTier tier, DoorSaleDraft sale, {required bool offline}) {
    if (!mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    JolToast.show(context, 'Sold ${sale.quantity} × ${tier.name}. Let them in.${offline ? ' (Saved on this phone.)' : ''}');
    setState(() {
      _quantity = 1;
      _buyerName.clear();
      _buyerPhone.clear();
    });
  }

  Future<void> _refreshSales() async {
    try {
      final info = await _repo.info(_eventId);
      if (mounted) setState(() => _info = info);
    } on DoorException {
      // Not important: the list catches up next time.
    }
  }

  Future<void> _voidSale(DoorSaleRecord sale) async {
    final sure = await _confirm('Undo this sale? Its tickets stop working. Give the money back if they paid.', 'Undo sale');
    if (!sure) return;
    try {
      final info = await _repo.voidSale(_eventId, sale.id);
      if (!mounted) return;
      setState(() => _info = info);
      JolToast.show(context, 'Sale undone.');
    } on DoorException catch (error) {
      if (mounted) JolToast.show(context, error.offline ? 'Undoing a sale needs signal.' : error.message);
    }
  }

  // ---- Helpers ------------------------------------------------------------

  Future<bool> _confirm(String question, String action) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(question),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    return answer == true;
  }

  static String _methodLabel(DoorInfo info, String key) =>
      (info.methods[key] ?? key).split(' (').first;

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  /// R1 250 or R85.50
  static String _rand(double value) {
    final whole = value.truncate().abs().toString();
    final grouped = whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ');
    final cents = ((value.abs() - value.abs().truncate()) * 100).round();
    return '${value < 0 ? '-' : ''}R$grouped${cents == 0 ? '' : '.${cents.toString().padLeft(2, '0')}'}';
  }

  static String _time(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('door')),
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      JolButton(label: 'Try again', onPressed: _load),
                    ],
                  ),
                ),
        ),
      );
    }

    final tabs = <(String, Widget)>[
      if (info.ticketed) ('Scan', _scanTab(info)),
      ('Guest list', _guestTab(info)),
      if (info.ticketed) ('Sell', _sellTab(info)),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(info.title.isEmpty ? 'door' : info.title, overflow: TextOverflow.ellipsis),
          bottom: TabBar(tabs: [for (final tab in tabs) Tab(text: tab.$1)]),
        ),
        body: Column(
          children: [
            _header(info),
            Expanded(child: TabBarView(children: [for (final tab in tabs) tab.$2])),
          ],
        ),
      ),
    );
  }

  Widget _header(DoorInfo info) {
    final tokens = JolTokens.of(context);
    final summary = info.summary;
    final list = _list;
    return Container(
      color: tokens.background,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Stat(label: 'inside', value: '${summary.inside}'),
              if (info.ticketed) _Stat(label: 'tickets in', value: '${summary.ticketsIn}/${summary.ticketsSold}'),
              _Stat(label: 'guests in', value: '${summary.guestsIn}/${summary.guestPeople}'),
              if (info.ticketed && (summary.doorSalesEnabled || summary.doorSalesTotal > 0))
                _Stat(label: 'door', value: _rand(summary.doorSalesTotal)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_online ? Icons.wifi : Icons.wifi_off, size: 16, color: _online ? Colors.green.shade700 : Colors.orange.shade800),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  [
                    _online ? 'Online' : 'No signal',
                    if (list != null) 'list saved ${_time(list.savedAt)}' else 'no list saved',
                    if (_pending > 0) '$_pending waiting to sync',
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_pending > 0)
                TextButton(onPressed: _syncing ? null : () => _sync(), child: const Text('Sync')),
              TextButton(
                onPressed: _busyList ? null : () => _download(),
                child: Text(_busyList ? 'Saving…' : (list == null ? 'Save list' : 'Refresh list')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanTab(DoorInfo info) {
    final tokens = JolTokens.of(context);
    final result = _result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        QrScannerView(paused: _checking, onCode: _check),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: _check,
                decoration: const InputDecoration(labelText: 'Or type the code', hintText: 'JOL-XXXXXXXX'),
              ),
            ),
            const SizedBox(width: 10),
            JolButton(label: _checking ? '…' : 'Check', onPressed: _checking ? null : () => _check(_code.text)),
          ],
        ),
        if (result != null) ...[
          const SizedBox(height: 14),
          _ResultCard(result: result),
        ],
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('On this phone, latest first', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final item in _history)
            JolListRow(
              title: [item.outcome.guest ?? item.code, ?item.outcome.tier].join(' · '),
              subtitle: '${item.outcome.admit ? 'In' : 'Refused'} ${_time(item.at)}${item.outcome.offline ? ' · no signal' : ''}',
              trailing: Icon(
                item.outcome.admit ? Icons.check_circle_outline : Icons.block,
                color: item.outcome.admit ? Colors.green.shade700 : tokens.muted,
              ),
            ),
        ],
      ],
    );
  }

  Widget _guestTab(DoorInfo info) {
    final tokens = JolTokens.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Name or last digits of their number',
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Add walk-in',
              onPressed: _addWalkIn,
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_guestsLoading && _guests.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_guests.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _search.text.trim().isEmpty ? 'No RSVPs yet.' : 'No one on the guest list by that name.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.muted),
            ),
          )
        else
          JolCard(
            border: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Column(
              children: [
                for (final guest in _guests) _guestRow(guest),
              ],
            ),
          ),
        if (info.ticketed && _search.text.trim().length >= 2) ...[
          const SizedBox(height: 18),
          Text('ticket holders by that name', style: Theme.of(context).textTheme.titleSmall),
          Text(
            'Lost or flat phone? Check their ID matches, then let them in.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.muted),
          ),
          const SizedBox(height: 6),
          if (_holders.isEmpty)
            Text(_online ? 'No tickets in that name.' : 'Searching tickets by name needs signal.', style: TextStyle(color: tokens.muted))
          else
            for (final holder in _holders)
              JolListRow(
                title: holder.name,
                subtitle: [?holder.tier, holder.status == 'used' ? 'In ${_time(holder.scannedAt)}' : 'Not in yet'].join(' · '),
                trailing: holder.status == 'valid'
                    ? JolButton(label: 'Let in', small: true, onPressed: () => _letHolderIn(holder))
                    : const Icon(Icons.check_circle_outline),
              ),
        ],
      ],
    );
  }

  Widget _guestRow(DoorGuest guest) {
    final details = [
      if (guest.status == 'maybe') 'Maybe',
      if (guest.walkIn) 'Walk-in',
      if (guest.phoneEnd != null) 'number ends ${guest.phoneEnd}',
      if (guest.isIn) 'In ${_time(guest.checkedInAt)}${guest.party > 1 ? ' (${guest.checkedInCount} of ${guest.party})' : ''}',
    ];
    final allIn = guest.checkedInCount >= guest.party;
    return JolListRow(
      title: guest.party > 1 ? '${guest.name} +${guest.party - 1}' : guest.name,
      subtitle: details.isEmpty ? null : details.join(' · '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (guest.isIn)
            TextButton(onPressed: () => _undoGuest(guest), child: const Text('Undo')),
          if (!allIn)
            JolButton(label: guest.isIn ? 'More' : 'Let in', small: true, onPressed: () => _letGuestIn(guest)),
          if (allIn) Icon(Icons.check_circle, color: Colors.green.shade700),
        ],
      ),
    );
  }

  Widget _sellTab(DoorInfo info) {
    final tokens = JolTokens.of(context);
    final summary = info.summary;
    if (!summary.doorSalesEnabled) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          JolCard(
            border: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Door sales are off for this event.', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  info.canManage
                      ? 'Switch them on to sell tickets at the door for cash or on your own card machine. The money goes straight to you; JOL doesn’t take a fee on door sales.'
                      : 'Ask the host to switch them on.',
                  style: TextStyle(color: tokens.muted),
                ),
                if (info.canManage) ...[
                  const SizedBox(height: 12),
                  JolButton(label: 'Switch on door sales', onPressed: () => _setDoorSales(true)),
                ],
              ],
            ),
          ),
        ],
      );
    }

    final tier = info.tiers.where((item) => item.id == _tierId).firstOrNull;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? tier?.price ?? 0;
    final methods = info.methods.isEmpty ? const {'cash': 'Cash', 'card': 'Card machine', 'other': 'Other'} : info.methods;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        if (info.tiers.isEmpty)
          Text('This event has no ticket types to sell.', style: TextStyle(color: tokens.muted))
        else ...[
          DropdownButtonFormField<int>(
            initialValue: tier?.id,
            decoration: const InputDecoration(labelText: 'Ticket'),
            items: [
              for (final item in info.tiers)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(
                    '${item.name} · ${_rand(item.price)}'
                    '${item.available == null ? '' : (item.available! > 0 ? ' · ${item.available} left' : ' · sold out')}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) => setState(() {
              _tierId = id;
              final chosen = info.tiers.where((item) => item.id == id).firstOrNull;
              if (chosen != null) _price.text = _plain(chosen.price);
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.outlined(
                tooltip: 'One fewer',
                onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 48,
                child: Text('$_quantity', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton.outlined(
                tooltip: 'One more',
                onPressed: _quantity < 20 ? () => setState(() => _quantity++) : null,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Price each (R)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('paid with', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in methods.entries)
                ChoiceChip(
                  label: Text(entry.value.split(' (').first),
                  selected: _method == entry.key,
                  onSelected: (_) => setState(() => _method = entry.key),
                ),
            ],
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Buyer’s name and number (optional)'),
            children: [
              TextField(controller: _buyerName, decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                controller: _buyerPhone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', hintText: '082 123 4567'),
              ),
              const SizedBox(height: 8),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('Total ${_rand(price * _quantity)}', style: Theme.of(context).textTheme.titleLarge),
              ),
              JolButton(
                label: _selling ? 'Selling…' : 'Sell and let in',
                variant: JolButtonVariant.purchase,
                onPressed: _selling || tier == null ? null : _sell,
              ),
            ],
          ),
          if (!_online)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('No signal: the sale is saved on this phone and sent later.', style: TextStyle(color: tokens.muted)),
            ),
        ],
        const SizedBox(height: 20),
        JolCard(
          border: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('door takings', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(_rand(summary.doorSalesTotal), style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                [
                  for (final entry in methods.entries)
                    '${entry.value.split(' (').first} ${_rand(summary.byMethod[entry.key] ?? 0)}',
                ].join(' · '),
                style: TextStyle(color: tokens.muted),
              ),
              Text(
                '${summary.doorSalesTickets} tickets in ${summary.doorSalesCount} sales',
                style: TextStyle(color: tokens.muted),
              ),
            ],
          ),
        ),
        if (info.recentSales.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('latest door sales', style: Theme.of(context).textTheme.titleSmall),
          for (final sale in info.recentSales)
            Opacity(
              opacity: sale.voided ? 0.5 : 1.0,
              child: JolListRow(
                title: '${sale.quantity} × ${sale.tier ?? 'ticket'} · ${_rand(sale.total)}',
                subtitle: [
                  _methodLabel(info, sale.method),
                  ?sale.seller,
                  _time(sale.soldAt),
                  if (sale.voided) 'undone',
                  if (sale.overCapacity) 'over capacity',
                ].join(' · '),
                trailing: sale.canUndo
                    ? TextButton(onPressed: () => _voidSale(sale), child: const Text('Undo'))
                    : null,
              ),
            ),
        ],
        if (info.canManage) ...[
          const SizedBox(height: 12),
          TextButton(onPressed: () => _setDoorSales(false), child: const Text('Switch off door sales')),
        ],
      ],
    );
  }
}

class _Checked {
  const _Checked({required this.code, required this.outcome, required this.at});

  final String code;
  final ScanOutcome outcome;
  final DateTime at;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.muted)),
        ],
      ),
    );
  }
}

/// Big green (let in), amber (check ID) or red (don't let in) answer.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ScanOutcome result;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, String headline) = !result.admit
        ? (Colors.red.shade50, Colors.red.shade900, 'Don’t let in')
        : result.requiresIdCheck
        ? (Colors.amber.shade50, Colors.amber.shade900, 'Check ID · 18+')
        : (Colors.green.shade50, Colors.green.shade900, 'Let in');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: foreground, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: foreground, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(result.message, style: TextStyle(color: foreground)),
          if (result.guest != null || result.tier != null) ...[
            const SizedBox(height: 6),
            Text(
              [?result.guest, ?result.tier].join(' · '),
              style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
            ),
          ],
          if (result.offline) ...[
            const SizedBox(height: 6),
            Text('Checked on this phone (no signal). It syncs when the signal is back.', style: TextStyle(color: foreground)),
          ],
        ],
      ),
    );
  }
}

class _WalkIn {
  const _WalkIn({required this.name, this.phone, required this.count});

  final String name;
  final String? phone;
  final int count;
}

class _WalkInDialog extends StatefulWidget {
  const _WalkInDialog();

  @override
  State<_WalkInDialog> createState() => _WalkInDialogState();
}

class _WalkInDialogState extends State<_WalkInDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  var _count = 1;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add walk-in'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('People')),
              IconButton(onPressed: _count > 1 ? () => setState(() => _count--) : null, icon: const Icon(Icons.remove)),
              Text('$_count'),
              IconButton(onPressed: _count < 20 ? () => setState(() => _count++) : null, icon: const Icon(Icons.add)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.length < 2) return;
            Navigator.pop(
              context,
              _WalkIn(name: name, phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(), count: _count),
            );
          },
          child: const Text('Add and let in'),
        ),
      ],
    );
  }
}
