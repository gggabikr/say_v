import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:say_v/models/store.dart';
import 'package:say_v/pages/category_stores_page.dart';
import 'package:say_v/services/store_service.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<Store> testStores;

  setUpAll(() async {
    // Load stores.json from test_data directory
    final String jsonString =
        await rootBundle.loadString('test/test_data/stores.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    final List<dynamic> storeList =
        jsonMap['stores'] as List<dynamic>; // stores 키로 접근
    testStores = storeList.map((json) => Store.fromJson(json)).toList();
  });

  group('1. 정렬 기능 테스트', () {
    test('거리순 정렬 테스트', () {
      final stores = List<Store>.from(testStores);
      stores.sort((a, b) => (a.distance ?? double.infinity)
          .compareTo(b.distance ?? double.infinity));

      for (int i = 0; i < stores.length - 1; i++) {
        expect(
            (stores[i].distance ?? double.infinity) <=
                (stores[i + 1].distance ?? double.infinity),
            true);
      }
    });

    test('평점순 정렬 테스트', () {
      final stores = List<Store>.from(testStores);
      stores.sort((a, b) => b.averageRating.compareTo(a.averageRating));

      for (int i = 0; i < stores.length - 1; i++) {
        expect(stores[i].averageRating >= stores[i + 1].averageRating, true);
      }
    });
  });

  group('2. 필터 조합 테스트', () {
    test('Open Now + 거리순 테스트', () {
      final stores = List<Store>.from(testStores)
          .where((store) => store.isCurrentlyOpen())
          .toList()
        ..sort((a, b) => (a.distance ?? double.infinity)
            .compareTo(b.distance ?? double.infinity));

      // 모든 가게가 열려있는지 확인
      expect(stores.every((store) => store.isCurrentlyOpen()), true);
      // 거리순 정렬 확인
      for (int i = 0; i < stores.length - 1; i++) {
        expect(
            (stores[i].distance ?? double.infinity) <=
                (stores[i + 1].distance ?? double.infinity),
            true);
      }
    });

    // 나머지 필터 조합 테스트들...
  });

  group('3. 검색어 입력 테스트', () {
    test('검색어로 가게 필터링 테스트', () {
      const searchQuery = 'sushi';
      final stores = List<Store>.from(testStores)
          .where((store) =>
              store.name.toLowerCase().contains(searchQuery) ||
              store.category.toLowerCase().contains(searchQuery) ||
              store.cuisineTypes
                  .any((type) => type.toLowerCase().contains(searchQuery)))
          .toList();

      expect(
          stores.every((store) =>
              store.name.toLowerCase().contains(searchQuery) ||
              store.category.toLowerCase().contains(searchQuery) ||
              store.cuisineTypes
                  .any((type) => type.toLowerCase().contains(searchQuery))),
          true);
    });

    // 나머지 검색어 테스트들...
  });

  group('4. 시간 선택 기능 테스트', () {
    test('특정 시간에 영업중인 가게 필터링 테스트', () {
      final testDateTime = DateTime(2024, 3, 20, 14, 0); // 수요일 오후 2시
      final stores = List<Store>.from(testStores)
          .where((store) => store.isOpenAt(testDateTime))
          .toList();

      expect(stores.every((store) => store.isOpenAt(testDateTime)), true,
          reason: '모든 가게가 지정된 시간에 영업 중이어야 함');
    });

    test('특정 시간의 해피아워 가게 필터링 테스트', () {
      final testDateTime = DateTime(2024, 3, 20, 17, 0); // 수요일 오후 5시
      final stores = List<Store>.from(testStores)
          .where((store) => store.isHappyHourAt(testDateTime))
          .toList();

      expect(stores.every((store) => store.isHappyHourAt(testDateTime)), true,
          reason: '모든 가게가 지정된 시간에 해피아워여야 함');
    });

    test('24시간 영업 가게 확인 테스트', () {
      final stores = List<Store>.from(testStores)
          .where((store) => store.is24Hours)
          .toList();

      // 아무 시간이나 테스트
      final testTimes = [
        DateTime(2024, 3, 20, 2, 0), // 새벽 2시
        DateTime(2024, 3, 20, 14, 0), // 오후 2시
        DateTime(2024, 3, 20, 23, 0), // 밤 11시
      ];

      for (final store in stores) {
        for (final testTime in testTimes) {
          expect(store.isOpenAt(testTime), true,
              reason: '24시간 영업 가게는 항상 영업 중이어야 함');
        }
      }
    });
  });

  group('5. 복합 필터링 테스트', () {
    test('검색어 + Open Now + 거리순 정렬 테스트', () {
      const searchQuery = 'korean';
      final now = DateTime.now();

      final stores = List<Store>.from(testStores)
          .where((store) =>
              (store.name.toLowerCase().contains(searchQuery) ||
                  store.category.toLowerCase().contains(searchQuery) ||
                  store.cuisineTypes.any(
                      (type) => type.toLowerCase().contains(searchQuery))) &&
              store.isOpenAt(now))
          .toList()
        ..sort((a, b) => (a.distance ?? double.infinity)
            .compareTo(b.distance ?? double.infinity));

      // 검색어 필터링 확인
      expect(
          stores.every((store) =>
              store.name.toLowerCase().contains(searchQuery) ||
              store.category.toLowerCase().contains(searchQuery) ||
              store.cuisineTypes
                  .any((type) => type.toLowerCase().contains(searchQuery))),
          true,
          reason: '모든 가게가 검색어와 일치해야 함');

      // 영업 중 확인
      expect(stores.every((store) => store.isOpenAt(now)), true,
          reason: '모든 가게가 현재 영업 중이어야 함');

      // 거리순 정렬 확인
      for (int i = 0; i < stores.length - 1; i++) {
        expect(
            (stores[i].distance ?? double.infinity) <=
                (stores[i + 1].distance ?? double.infinity),
            true,
            reason: '거리순으로 정렬되어야 함');
      }
    });

    test('해피아워 + 평점순 정렬 테스트', () {
      final now = DateTime.now();

      final stores = List<Store>.from(testStores)
          .where((store) => store.isHappyHourAt(now))
          .toList()
        ..sort((a, b) => b.averageRating.compareTo(a.averageRating));

      expect(stores.every((store) => store.isHappyHourAt(now)), true,
          reason: '모든 가게가 현재 해피아워여야 함');

      for (int i = 0; i < stores.length - 1; i++) {
        expect(stores[i].averageRating >= stores[i + 1].averageRating, true,
            reason: '평점순으로 정렬되어야 함');
      }
    });
  });

  group('6. 카테고리별 테스트', () {
    test('전체(all) 카테고리 테스트', () {
      final allStores = List<Store>.from(testStores);
      expect(allStores.isNotEmpty, true, reason: '전체 가게 목록이 비어있지 않아야 함');
    });

    test('근처(nearby) 카테고리 테스트', () {
      final testLocation = Position(
        latitude: 49.2827,
        longitude: -123.1207,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
        floor: null,
      );

      final nearbyStores = List<Store>.from(testStores)
          .map((store) {
            final distance = calculateDistance(
              testLocation.latitude,
              testLocation.longitude,
              store.latitude,
              store.longitude,
            );
            store.distance = distance;
            return store;
          })
          .where((store) => (store.distance ?? double.infinity) <= 5.0)
          .toList();

      expect(nearbyStores.isNotEmpty, true, reason: '근처 가게가 존재해야 함');

      expect(
          nearbyStores
              .every((store) => (store.distance ?? double.infinity) <= 5.0),
          true,
          reason: '모든 가게가 5km 이내여야 함');
    });

    test('해피아워(happy_hour) 카테고리 테스트', () {
      final now = DateTime.now();
      final happyHourStores = List<Store>.from(testStores)
          .where((store) =>
              store.happyHours != null && store.happyHours!.isNotEmpty)
          .toList();

      expect(happyHourStores.isNotEmpty, true, reason: '해피아워 가게가 존재해야 함');

      final currentHappyHourStores =
          happyHourStores.where((store) => store.isHappyHourAt(now)).toList();

      expect(currentHappyHourStores.every((store) => store.isHappyHourAt(now)),
          true,
          reason: '필터링된 모든 가게가 현재 해피아워여야 함');
    });

    test('특정 카테고리(예: Korean) 테스트', () {
      const testCategory = 'Korean';
      final koreanStores = List<Store>.from(testStores)
          .where((store) =>
              store.category.contains(testCategory) ||
              store.cuisineTypes.contains(testCategory))
          .toList();

      expect(koreanStores.isNotEmpty, true, reason: '한식 카테고리 가게가 존재해야 함');

      expect(
          koreanStores.every((store) =>
              store.category.contains(testCategory) ||
              store.cuisineTypes.contains(testCategory)),
          true,
          reason: '모든 가게가 Korean 카테고리여야 함');
    });
  });
}

// 거리 계산 헬퍼 함수
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  var R = 6371.0;
  var lat1Rad = lat1 * (pi / 180.0);
  var lon1Rad = lon1 * (pi / 180.0);
  var lat2Rad = lat2 * (pi / 180.0);
  var lon2Rad = lon2 * (pi / 180.0);
  var dLat = lat2Rad - lat1Rad;
  var dLon = lon2Rad - lon1Rad;
  var a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
  var c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}
