import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/api/api_client.dart';
import '../../ui/theme/jol_theme.dart';
import '../../ui/widgets/jol_button.dart';
import '../../ui/widgets/jol_toast.dart';
import 'maps_repository.dart';

/// Full-screen map for hosts: search an address, drag the map under the pin,
/// or jump to their current location. Pops with a [PickedLocation].
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  final PickedLocation? initial;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  GoogleMapController? _map;
  late LatLng _target = widget.initial?.latLng ?? capeTownCenter;
  PickedLocation? _picked;
  List<PlaceSuggestion> _suggestions = const [];
  Timer? _searchDebounce;
  Timer? _reverseDebounce;
  var _resolving = false;
  var _locating = false;
  String? _error;

  /// Groups autocomplete + details calls into one billed Places session.
  String _session = _newSession();

  /// Skips the reverse lookup after we moved the map to a searched place.
  var _skipNextReverse = false;

  static String _newSession() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36);

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
    if (_picked == null) _scheduleReverse();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _reverseDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ref
            .read(mapsRepositoryProvider)
            .autocomplete(query, session: _session);
        if (mounted && _search.text.trim() == query) {
          setState(() {
            _suggestions = results;
            _error = null;
          });
        }
      } on ApiException catch (error) {
        if (mounted) setState(() => _error = error.message);
      }
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    _searchFocus.unfocus();
    setState(() {
      _suggestions = const [];
      _resolving = true;
      _search.text = suggestion.title;
    });
    try {
      final place = await ref
          .read(mapsRepositoryProvider)
          .place(suggestion.placeId, session: _session);
      _session = _newSession();
      if (!mounted) return;
      _skipNextReverse = true;
      setState(() {
        _picked = place;
        _target = place.latLng;
        _error = null;
      });
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(place.latLng, 17));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final position = await currentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (position == null) {
      JolToast.show(
        context,
        'Turn on location for JOL in your phone settings to use this.',
      );
      return;
    }
    final target = LatLng(position.latitude, position.longitude);
    await _map?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
  }

  void _scheduleReverse() {
    _reverseDebounce?.cancel();
    _reverseDebounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _resolving = true);
      try {
        final place = await ref.read(mapsRepositoryProvider).reverse(_target);
        if (mounted) {
          setState(() {
            _picked = place;
            _error = null;
          });
        }
      } on ApiException catch (error) {
        if (mounted) {
          setState(() {
            _error = error.message;
            // Still let them save the pin without an address.
            _picked = PickedLocation(
              latitude: _target.latitude,
              longitude: _target.longitude,
              address: _picked?.address ?? '',
              area: _picked?.area ?? 'Cape Town',
              name: _picked?.name,
            );
          });
        }
      } finally {
        if (mounted) setState(() => _resolving = false);
      }
    });
  }

  void _onCameraIdle() {
    if (_skipNextReverse) {
      _skipNextReverse = false;
      return;
    }
    _scheduleReverse();
  }

  void _confirm() {
    final picked = _picked;
    if (picked == null) return;
    Navigator.of(context).pop(
      PickedLocation(
        latitude: _target.latitude,
        longitude: _target.longitude,
        address: picked.address,
        area: picked.area,
        name: picked.name,
        inServiceArea: picked.inServiceArea,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final picked = _picked;
    final outside = picked != null && !picked.inServiceArea;
    return Scaffold(
      appBar: AppBar(title: const Text('event location')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _target,
              zoom: widget.initial == null ? 12 : 17,
            ),
            onMapCreated: (controller) => _map = controller,
            onCameraMove: (position) => _target = position.target,
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(bottom: 180, top: 72),
          ),
          // Fixed pin in the middle: the map moves under it.
          IgnorePointer(
            child: Padding(
              // Puts the pin's tip on the camera target, which sits in the
              // middle of the padded map area.
              padding: const EdgeInsets.only(bottom: 152),
              child: Center(
                child: Icon(Icons.location_on, size: 44, color: tokens.accent),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: Material(
              elevation: 3,
              color: tokens.surface,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search venue or address',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() {
                                _search.clear();
                                _suggestions = const [];
                              }),
                            ),
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  if (_suggestions.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _suggestions[index];
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(item.title),
                            subtitle: item.subtitle.isEmpty
                                ? null
                                : Text(item.subtitle),
                            onTap: () => _selectSuggestion(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 196,
            child: FloatingActionButton.small(
              heroTag: 'my-location',
              tooltip: 'Use my current location',
              onPressed: _locating ? null : _useMyLocation,
              child: _locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: tokens.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resolving
                            ? 'Finding address…'
                            : picked?.name ??
                                  (picked?.address.isNotEmpty == true
                                      ? picked!.address
                                      : 'Move the map to place the pin'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        outside
                            ? 'JOL is only in Cape Town for now. Pick a spot in Cape Town.'
                            : _error ??
                                  (picked?.name != null
                                      ? picked!.address
                                      : picked?.area ?? ''),
                        style: TextStyle(
                          color: outside || _error != null
                              ? Theme.of(context).colorScheme.error
                              : tokens.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      JolButton(
                        label: 'Use this location',
                        expanded: true,
                        onPressed: picked == null || _resolving || outside
                            ? null
                            : _confirm,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
