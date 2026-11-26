import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../ui/theme/jol_theme.dart';
import '../../ui/widgets/jol_button.dart';
import '../../ui/widgets/jol_card.dart';
import '../../ui/widgets/jol_sheet.dart';
import '../../ui/widgets/jol_toast.dart';
import '../discover/models/jol_event.dart';

/// Small map of the venue with a "Get directions" button. For private events
/// whose location is hidden, shows the area only.
class EventLocationCard extends StatelessWidget {
  const EventLocationCard({super.key, required this.event, this.enabled = true});

  final JolEvent event;

  /// False on the host's preview, where nothing should open.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = JolTokens.of(context);
    if (event.locationHidden) {
      return JolCard(
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: tokens.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Somewhere in ${event.area}. The exact location is shared '
                'once you RSVP or get a ticket.',
              ),
            ),
          ],
        ),
      );
    }
    final hasPin = event.hasPin;
    return JolCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasPin)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: SizedBox(
                height: 160,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(event.latitude!, event.longitude!),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('venue'),
                          position: LatLng(event.latitude!, event.longitude!),
                        ),
                      },
                      // A still map inside a scrolling page.
                      liteModeEnabled: Platform.isAndroid,
                      zoomGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomControlsEnabled: false,
                      myLocationButtonEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    // Taps on the map open directions instead of moving it.
                    Positioned.fill(
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: enabled
                              ? () => showDirectionsSheet(context, event)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.venue, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  event.rawAddress?.isNotEmpty == true
                      ? event.rawAddress!
                      : '${event.area}, Cape Town',
                  style: TextStyle(color: tokens.muted),
                ),
                const SizedBox(height: 12),
                JolButton(
                  label: 'Get directions',
                  small: true,
                  variant: JolButtonVariant.secondary,
                  onPressed: enabled
                      ? () => showDirectionsSheet(context, event)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the guest pick Google Maps, Apple Maps (iPhone) or Waze.
Future<void> showDirectionsSheet(BuildContext context, JolEvent event) {
  final hasPin = event.hasPin;
  final query = hasPin
      ? '${event.latitude},${event.longitude}'
      : Uri.encodeComponent(event.address);
  final options = <(String, IconData, Uri)>[
    (
      'Google Maps',
      Icons.map_outlined,
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$query',
      ),
    ),
    if (Platform.isIOS)
      (
        'Apple Maps',
        Icons.map,
        Uri.parse('https://maps.apple.com/?daddr=$query'),
      ),
    (
      'Waze',
      Icons.navigation_outlined,
      hasPin
          ? Uri.parse('https://waze.com/ul?ll=$query&navigate=yes')
          : Uri.parse('https://waze.com/ul?q=$query&navigate=yes'),
    ),
  ];
  return JolSheet.show<void>(
    context: context,
    title: 'get directions',
    child: Column(
      children: [
        for (final (label, icon, uri) in options)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icon),
            title: Text(label),
            onTap: () async {
              Navigator.of(context).pop();
              final opened = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              if (!opened && context.mounted) {
                JolToast.show(context, 'Could not open $label.');
              }
            },
          ),
      ],
    ),
  );
}
