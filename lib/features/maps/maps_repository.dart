import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/api/api_client.dart';

/// Centre of the launch area. Matches the backend's maps config.
const capeTownCenter = LatLng(-33.9249, 18.4241);

@immutable
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.title,
    required this.subtitle,
  });

  final String placeId;
  final String title;
  final String subtitle;
}

/// A spot chosen in the location picker.
@immutable
class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.area,
    this.name,
    this.inServiceArea = true,
  });

  factory PickedLocation.fromApi(Map<String, dynamic> json) => PickedLocation(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    address: json['address'] as String? ?? '',
    area: json['area'] as String? ?? 'Cape Town',
    name: json['name'] as String?,
    inServiceArea: json['in_service_area'] != false,
  );

  final double latitude;
  final double longitude;

  /// "street, area": the app reads the last part as the area.
  final String address;
  final String area;

  /// Venue name when the pick was a business or landmark.
  final String? name;
  final bool inServiceArea;

  LatLng get latLng => LatLng(latitude, longitude);
}

final mapsRepositoryProvider = Provider<MapsRepository>(
  (ref) => MapsRepository(ref.watch(apiClientProvider)),
);

/// Address search through the backend (/maps/*), which holds the Google key.
class MapsRepository {
  const MapsRepository(this._dio);

  final Dio _dio;

  Future<List<PlaceSuggestion>> autocomplete(
    String query, {
    String? session,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/maps/autocomplete',
        queryParameters: {'q': query, 'session': ?session},
      );
      final data = response.data?['data'];
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map(
            (item) => PlaceSuggestion(
              placeId: '${item['place_id']}',
              title: item['title'] as String? ?? '',
              subtitle: item['subtitle'] as String? ?? '',
            ),
          )
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<PickedLocation> place(String placeId, {String? session}) =>
      _location('/maps/places/${Uri.encodeComponent(placeId)}', {
        'session': ?session,
      });

  Future<PickedLocation> reverse(LatLng position) => _location(
    '/maps/reverse',
    {'lat': position.latitude, 'lng': position.longitude},
  );

  Future<PickedLocation> _location(
    String path,
    Map<String, Object> query,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      final data = response.data?['data'];
      if (data is! Map) {
        throw const ApiException('The location could not be read.');
      }
      return PickedLocation.fromApi(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}

/// Asks for location permission and returns the phone's position, or null
/// when location is off or the person said no.
Future<Position?> currentPosition() async {
  if (!await Geolocator.isLocationServiceEnabled()) return null;
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  } catch (_) {
    return Geolocator.getLastKnownPosition();
  }
}

/// The phone's position for "Near me"; re-read by invalidating it.
final userPositionProvider = FutureProvider<Position?>(
  (ref) => currentPosition(),
);

/// Straight-line distance in metres.
double distanceMetres(double lat1, double lng1, double lat2, double lng2) {
  const radius = 6371000.0;
  double rad(double degrees) => degrees * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String formatDistance(double metres) {
  if (metres < 1000) return '${(metres / 50).round() * 50} m';
  final km = metres / 1000;
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}
