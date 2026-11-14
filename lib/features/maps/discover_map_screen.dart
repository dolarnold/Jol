import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../ui/theme/jol_theme.dart';
import '../../ui/widgets/jol_toast.dart';
import '../discover/data/event_repository.dart';
import '../discover/models/jol_event.dart';
import '../discover/widgets/attendee_components.dart';
import 'maps_repository.dart';

/// Discover as a map: one pin per upcoming event that has a location.
class DiscoverMapScreen extends ConsumerStatefulWidget {
  const DiscoverMapScreen({super.key});

  @override
  ConsumerState<DiscoverMapScreen> createState() => _DiscoverMapScreenState();
}

class _DiscoverMapScreenState extends ConsumerState<DiscoverMapScreen> {
  GoogleMapController? _map;
  JolEvent? _selected;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _goToMe() async {
    final position = await currentPosition();
    if (!mounted) return;
    if (position == null) {
      JolToast.show(context, 'Turn on location for JOL to see events near you.');
      return;
    }
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        13,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    final eventsResult = ref.watch(attendeeEventsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = (eventsResult.asData?.value ?? const <JolEvent>[])
        .where((event) => event.hasPin && !event.date.isBefore(today))
        .toList();
    final markers = {
      for (final event in events)
        Marker(
          markerId: MarkerId(event.id),
          position: LatLng(event.latitude!, event.longitude!),
          infoWindow: InfoWindow(
            title: event.title,
            snippet: '${formatEventDate(event.date)} · ${event.startTime}',
          ),
          onTap: () => setState(() => _selected = event),
        ),
    };
    final selected = _selected;

    return Scaffold(
      appBar: AppBar(title: const Text('events map')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: capeTownCenter,
              zoom: 11.5,
            ),
            onMapCreated: (controller) => _map = controller,
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onTap: (_) => setState(() => _selected = null),
          ),
          if (eventsResult.isLoading && eventsResult.asData == null)
            const Center(child: CircularProgressIndicator())
          else if (events.isEmpty)
            Positioned(
              left: 16,
              right: 16,
              top: 12,
              child: Material(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(14),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No upcoming events with a map location yet.'),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: selected == null ? 24 : 196,
            child: FloatingActionButton.small(
              heroTag: 'discover-my-location',
              tooltip: 'Show events near me',
              onPressed: _goToMe,
              child: const Icon(Icons.my_location),
            ),
          ),
          if (selected != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: AttendeePosterCard(
                  event: selected,
                  compact: true,
                  onTap: () => context.push('/event/${selected.id}'),
                  trailing: Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: tokens.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
