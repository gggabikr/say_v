import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/store.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Store>> loadStores() async {
    try {
      print('Loading stores from Firestore');
      final QuerySnapshot querySnapshot =
          await _firestore.collection('stores').get();
      final stores = querySnapshot.docs
          .map((doc) => Store.fromJson(
              {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
      print('Found ${stores.length} stores');
      return stores;
    } catch (e) {
      print('Error loading stores data: $e');
      return [];
    }
  }

  Future<List<Store>> getStores() async {
    return await loadStores();
  }

  Future<List<Store>> getStoresByCategory(
      String category, Position position) async {
    print('Searching for stores with category: $category');
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('stores')
          .where('category', arrayContains: category)
          .get();

      print('Found ${querySnapshot.docs.length} documents');

      final stores = querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        print('Processing document ID: ${doc.id}');

        // menus 데이터의 'id' 필드를 'itemId'로 변환
        if (data['menus'] != null) {
          final List<dynamic> menus = data['menus'] as List;
          data['menus'] = menus.map((menu) {
            if (menu['id'] != null) {
              menu['itemId'] = menu['id'];
              menu.remove('id');
            }
            return menu;
          }).toList();
        }

        // storeId가 없으면 document ID를 사용
        if (data['storeId'] == null) {
          data['storeId'] = doc.id;
        }

        // 필수 필드들이 null이 아닌지 확인
        if (data['name'] == null) data['name'] = '';
        if (data['address'] == null) data['address'] = '';
        if (data['category'] == null) data['category'] = [];
        if (data['cuisineTypes'] == null) data['cuisineTypes'] = [];
        if (data['contactNumber'] == null) data['contactNumber'] = '';

        return Store.fromJson(data);
      }).toList();

      // 위치 정보로 거리 계산
      for (var store in stores) {
        store.calculateDistance(position);
      }

      // 거리순으로 정렬
      stores.sort((a, b) => (a.distance ?? double.infinity)
          .compareTo(b.distance ?? double.infinity));

      print('Successfully processed ${stores.length} stores');
      return stores;
    } catch (e, stackTrace) {
      print('Error loading stores by category: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Store>> getAllStores(Position position) async {
    print('1. Starting getAllStores...');
    try {
      print('2. Fetching documents from Firestore');
      final QuerySnapshot querySnapshot =
          await _firestore.collection('stores').get();

      print('3. Found ${querySnapshot.docs.length} documents');

      final stores = querySnapshot.docs.map((doc) {
        print('4. Processing document: ${doc.id}');
        final data = doc.data() as Map<String, dynamic>;
        print('5. Raw data: $data');

        // menus 데이터의 'id' 필드를 'itemId'로 변환
        if (data['menus'] != null) {
          print('6. Processing menus for ${doc.id}');
          final List<dynamic> menus = data['menus'] as List;
          print('7. Original menus: $menus');
          data['menus'] = menus.map((menu) {
            print('8. Processing menu item: $menu');
            if (menu['id'] != null) {
              menu['itemId'] = menu['id'];
              menu.remove('id');
            }
            return menu;
          }).toList();
          print('9. Processed menus: ${data['menus']}');
        }

        // storeId가 없으면 document ID를 사용
        if (data['storeId'] == null) {
          print('10. Setting storeId to doc.id: ${doc.id}');
          data['storeId'] = doc.id;
        }

        // 필수 필드들이 null이 아닌지 확인
        print('11. Checking required fields');
        if (data['name'] == null) data['name'] = '';
        if (data['address'] == null) data['address'] = '';
        if (data['category'] == null) data['category'] = [];
        if (data['cuisineTypes'] == null) data['cuisineTypes'] = [];
        if (data['contactNumber'] == null) data['contactNumber'] = '';

        print('12. Creating Store object from data');
        try {
          final store = Store.fromJson(data);
          print('13. Successfully created Store object for ${doc.id}');
          return store;
        } catch (e, stackTrace) {
          print('Error creating Store object: $e');
          print('Data that caused error: $data');
          print('Stack trace: $stackTrace');
          rethrow;
        }
      }).toList();

      print('14. Processing distances for ${stores.length} stores');

      // 위치 정보로 거리 계산
      for (var store in stores) {
        store.calculateDistance(position);
      }

      // 거리순으로 정렬
      stores.sort((a, b) => (a.distance ?? double.infinity)
          .compareTo(b.distance ?? double.infinity));

      print('15. Successfully completed getAllStores');
      return stores;
    } catch (e, stackTrace) {
      print('ERROR in getAllStores: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<List<Store>> getNearbyStores(double latitude, double longitude) async {
    print('Fetching nearby stores for coordinates: $latitude, $longitude');
    try {
      final stores = await loadStores();

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
    } catch (e) {
      print('Error fetching nearby stores: $e');
      return [];
    }
  }

  Future<List<Store>> getStoresByCuisineType(String cuisineType) async {
    try {
      final QuerySnapshot querySnapshot = await _firestore
          .collection('stores')
          .where('cuisineTypes', arrayContains: cuisineType)
          .get();

      return querySnapshot.docs
          .map((doc) => Store.fromJson(
              {...doc.data() as Map<String, dynamic>, 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error loading stores by cuisine type: $e');
      return [];
    }
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
}
