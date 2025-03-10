import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/store.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class StoreService {
  final String jsonPath;

  StoreService({this.jsonPath = 'assets/data/stores.json'});

  Future<List<Store>> loadStores() async {
    try {
      print('Loading stores from local data');
      final String jsonString = await rootBundle.loadString(jsonPath);
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

  Future<List<Store>> getStores() async {
    return await loadStores();
  }

  Future<List<Store>> getStoresByCategory(
      String category, Position position) async {
    print('Searching for stores with category: $category');
    final stores = await loadStores();

    final filteredStores =
        stores.where((store) => store.category.contains(category)).toList();

    // 위치 정보로 거리 계산
    for (var store in filteredStores) {
      store.calculateDistance(position);
    }

    // 거리순으로 정렬
    filteredStores.sort((a, b) => (a.distance ?? double.infinity)
        .compareTo(b.distance ?? double.infinity));

    print('Found ${filteredStores.length} stores');
    return filteredStores;
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

        // 현재 위치 생성
        final currentPosition = Position(
          latitude: latitude,
          longitude: longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          headingAccuracy: 0,
        );

        // 각 매장의 거리 계산
        for (var store in stores) {
          store.calculateDistance(currentPosition);
        }

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

  Future<List<Store>> getStoresByCuisineType(String cuisineType) async {
    final stores = await loadStores();
    return stores
        .where((store) => store.cuisineTypes.contains(cuisineType))
        .toList();
  }
}
