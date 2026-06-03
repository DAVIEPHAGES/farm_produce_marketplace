import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';

class DistanceService {
  DistanceService._();

  static Map<String, dynamic>? _districtsCache;

  static Future<void> _loadDistricts() async {
    if (_districtsCache != null) return;
    final jsonString = await rootBundle.loadString('assets/data/malawi_districts.json');
    _districtsCache = json.decode(jsonString) as Map<String, dynamic>;
  }

  static String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static String? _findDistrictKey(String input, Map<String, dynamic> districts) {
    if (input.isEmpty) return null;
    // direct key
    if (districts.containsKey(input)) return input;

    final normalizedInput = _normalize(input);
    // build normalized map
    final Map<String, String> normMap = {};
    for (final k in districts.keys) {
      normMap[_normalize(k)] = k;
    }

    if (normMap.containsKey(normalizedInput)) return normMap[normalizedInput];

    // fallback: try contains/substring matches
    for (final entry in normMap.entries) {
      if (entry.key.contains(normalizedInput) || normalizedInput.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  static Future<double> calculateDistanceKm(String originDistrict, String destinationDistrict) async {
    try {
      await _loadDistricts();
      final districts = _districtsCache!;

      final originKey = _findDistrictKey(originDistrict, districts);
      final destinationKey = _findDistrictKey(destinationDistrict, districts);

      if (originKey == null) {
        throw Exception('Origin district "$originDistrict" not found in malawi_districts.json');
      }
      if (destinationKey == null) {
        throw Exception('Destination district "$destinationDistrict" not found in malawi_districts.json');
      }

      final origin = districts[originKey] as Map<String, dynamic>;
      final destination = districts[destinationKey] as Map<String, dynamic>;

      final double lat1 = (origin['lat'] as num).toDouble();
      final double lon1 = (origin['lng'] as num).toDouble();
      final double lat2 = (destination['lat'] as num).toDouble();
      final double lon2 = (destination['lng'] as num).toDouble();

      final distanceMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
      final distanceKm = distanceMeters / 1000.0;
      return double.parse(distanceKm.toStringAsFixed(2));
    } catch (e) {
      rethrow;
    }
  }

  static Future<double> calculateDeliveryFee({
    required String originDistrict,
    required String destinationDistrict,
    required double ratePerKm,
  }) async {
    try {
      final distance = await calculateDistanceKm(originDistrict, destinationDistrict);
      final fee = distance * ratePerKm;
      return double.parse(fee.toStringAsFixed(2));
    } catch (e) {
      rethrow;
    }
  }
}
