import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/store.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class StoreService {
  Future<List<Store>> loadStores() async {
    final String jsonString =
        await rootBundle.loadString('assets/data/stores.json');
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return (json['stores'] as List)
        .map((store) => Store.fromJson(store))
        .toList();
  }

  Future<List<Store>> getStores() async {
    return await loadStores();
  }

  Future<List<Store>> getStoresByCategory(String category) async {
    print('Searching for stores with category: $category');

    final stores = await loadStores();
    final filteredStores = stores
        .where((store) => store.category.contains(category))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    print('Found ${filteredStores.length} stores');
    return filteredStores;
  }

  Future<List<Store>> getStoresSortedByDistance(
      double userLat, double userLng) async {
    final stores = await loadStores();
    return stores
      ..sort((a, b) {
        final distA =
            _calculateDistance(userLat, userLng, a.latitude, a.longitude);
        final distB =
            _calculateDistance(userLat, userLng, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula
    var R = 6371.0; // 지구 반경 (km)
    var dLat = _toRadians(lat2 - lat1);
    var dLon = _toRadians(lon2 - lon1);

    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    var d = R * c;

    return d;
  }

  double _toRadians(double degree) {
    return degree * (pi / 180.0);
  }

  Future<List<Store>> getAllStores() async {
    try {
      print('Loading all stores from local data');
      final String jsonString =
          await rootBundle.loadString('assets/data/stores.json');
      final data = json.decode(jsonString);
      if (data['stores'] != null) {
        final stores = (data['stores'] as List)
            .map((store) => Store.fromJson(store))
            .toList();
        print('Found ${stores.length} stores');
        return stores;
      }
    } catch (e) {
      print('Error loading stores data: $e');
    }
    return [];
  }

  Future<List<Store>> getNearbyStores(double latitude, double longitude) async {
    print('Fetching nearby stores for coordinates: $latitude, $longitude');
    try {
      print('Loading stores from local data');
      final String jsonString =
          await rootBundle.loadString('assets/data/stores.json');
      final data = json.decode(jsonString);
      if (data['stores'] != null) {
        List<Store> stores = (data['stores'] as List)
            .map((store) => Store.fromJson(store))
            .toList();

        // 각 매장의 거리 계산 및 필터링
        stores = stores.map((store) {
          final distance = _calculateDistance(
            latitude,
            longitude,
            store.latitude,
            store.longitude,
          );
          print('Distance calculation for ${store.name}:');
          print('From: ($latitude, $longitude)');
          print('To: (${store.latitude}, ${store.longitude})');
          print('Calculated distance: $distance km');
          store.distance = distance;
          return store;
        }).toList();

        // 거리순으로 정렬
        stores.sort((a, b) => (a.distance ?? double.infinity)
            .compareTo(b.distance ?? double.infinity));

        // 거리 제한 적용 (150km)
        final filteredStores = stores
            .where((store) => store.distance != null && store.distance! <= 150)
            .toList();

        print('Found ${filteredStores.length} stores within 150km');
        return filteredStores;
      }
    } catch (e) {
      print('Error loading local data: $e');
    }
    return [];
  }
}
