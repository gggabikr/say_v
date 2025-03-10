import 'package:flutter_test/flutter_test.dart';
import 'package:say_v/services/store_service.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  late StoreService storeService;
  late Position testPosition;

  // 밴쿠버 메트로 지역 좌표 상수
  const downtownLat = 49.2856;
  const downtownLng = -123.1115;
  const richmondLat = 49.1666;
  const richmondLng = -123.1336;
  const burnabyLat = 49.2488;
  const burnabyLng = -122.9805;

  setUp(() {
    storeService = StoreService(jsonPath: 'test/test_data/stores.json');
    testPosition = Position(
      latitude: 49.2856,
      longitude: -123.1115,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      headingAccuracy: 0,
    );
  });

  group('StoreService Tests', () {
    test('기본 데이터 로드', () async {
      final stores = await storeService.loadStores();
      expect(stores, isNotEmpty);
      expect(stores.length, greaterThan(0));
    });

    group('요리 타입 필터링 테스트', () {
      test('cuisineType으로 매장 검색 - Korean', () async {
        final stores = await storeService.getStoresByCuisineType('Korean');
        expect(stores, isNotEmpty);
        for (var store in stores) {
          expect(store.cuisineTypes.contains('Korean'), true);
        }
      });

      test('cuisineType으로 매장 검색 - Japanese', () async {
        final stores = await storeService.getStoresByCuisineType('Japanese');
        expect(stores, isNotEmpty);
        for (var store in stores) {
          expect(store.cuisineTypes.contains('Japanese'), true);
        }
      });

      test('존재하지 않는 cuisineType으로 검색', () async {
        final stores = await storeService.getStoresByCuisineType('NonExistent');
        expect(stores, isEmpty);
      });
    });

    group('거리 기반 테스트', () {
      test('거리순 정렬 확인', () async {
        final sortedStores = await storeService.getNearbyStores(
          49.2856, // 밴쿠버 다운타운 좌표
          -123.1115,
        );

        expect(sortedStores, isNotEmpty);

        double? previousDistance;
        for (var store in sortedStores) {
          expect(store.distance, isNotNull);
          if (previousDistance != null) {
            expect(store.distance!, greaterThanOrEqualTo(previousDistance));
          }
          previousDistance = store.distance;
        }
      });

      test('전체 지역 매장 거리순 정렬 확인', () async {
        final sortedStores = await storeService.getNearbyStores(
          49.2856, // 밴쿠버 다운타운 좌표
          -123.1115,
        );

        expect(sortedStores, isNotEmpty);

        // 각 매장의 거리가 계산되어 있는지 확인
        for (var store in sortedStores) {
          expect(store.distance, isNotNull);
        }

        // 거리순 정렬 확인
        for (int i = 0; i < sortedStores.length - 1; i++) {
          expect(sortedStores[i].distance!,
              lessThanOrEqualTo(sortedStores[i + 1].distance!));
        }
      });

      test('150km 이내 매장만 반환', () async {
        final stores = await storeService.getNearbyStores(
          49.2856,
          -123.1115,
        );

        expect(stores, isNotEmpty);
        for (var store in stores) {
          expect(store.distance, isNotNull);
          expect(store.distance!, lessThanOrEqualTo(150.0));
        }
      });
    });

    group('Distance Based Tests - Metro Vancouver', () {
      test('getNearbyStores returns stores within Metro Vancouver', () async {
        const downtownLat = 49.2856;
        const downtownLng = -123.1115;

        final stores =
            await storeService.getNearbyStores(downtownLat, downtownLng);

        expect(stores, isNotEmpty);
        for (var store in stores) {
          expect(store.distance, isNotNull);
          expect(store.distance!, lessThanOrEqualTo(150.0));
        }
      });

      test('distance calculations between Vancouver landmarks', () async {
        const downtownLat = 49.2856;
        const downtownLng = -123.1115;

        const richmondLat = 49.1666;
        const richmondLng = -123.1336;

        const burnabyLat = 49.2488;
        const burnabyLng = -122.9805;

        final stores =
            await storeService.getNearbyStores(downtownLat, downtownLng);

        expect(
            stores.any(
                (store) => store.distance != null && store.distance! <= 15.0),
            isTrue,
            reason: 'Should find stores within Richmond distance');
      });
    });

    group('Distance Sorting Tests', () {
      test('stores are properly sorted by distance', () async {
        const downtownLat = 49.2856;
        const downtownLng = -123.1115;

        final stores = await storeService.getStoresSortedByDistance(
            downtownLat, downtownLng);

        for (int i = 0; i < stores.length - 1; i++) {
          final currentStore = stores[i];
          final nextStore = stores[i + 1];

          final currentPosition = Position(
            latitude: downtownLat,
            longitude: downtownLng,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            headingAccuracy: 0,
          );

          currentStore.calculateDistance(currentPosition);
          nextStore.calculateDistance(currentPosition);

          expect(currentStore.distance! <= nextStore.distance!, isTrue,
              reason: 'Stores should be sorted by distance in ascending order');
        }
      });
    });

    group('Error Handling Tests', () {
      test('handles invalid coordinates gracefully', () async {
        const invalidLat = 1000.0; // 유효하지 않은 위도
        const invalidLng = -2000.0; // 유효하지 않은 경도

        final stores =
            await storeService.getNearbyStores(invalidLat, invalidLng);
        expect(stores, isEmpty);
      });
    });

    group('메트로 밴쿠버 지역 거리 테스트', () {
      test('Richmond 지역 매장 검색', () async {
        final stores = await storeService.getNearbyStores(49.1666, -123.1336);
        expect(stores, isNotEmpty);

        // Richmond는 밴쿠버 다운타운에서 약 15km 거리
        bool hasNearbyStores = stores.any((store) => store.distance! <= 15.0);
        expect(hasNearbyStores, isTrue, reason: 'Richmond 지역 근처에 매장이 있어야 함');
      });

      test('Burnaby 지역 매장 검색', () async {
        final stores = await storeService.getNearbyStores(49.2488, -122.9805);
        expect(stores, isNotEmpty);

        // Burnaby는 밴쿠버 다운타운에서 약 10km 거리
        bool hasNearbyStores = stores.any((store) => store.distance! <= 10.0);
        expect(hasNearbyStores, isTrue, reason: 'Burnaby 지역 근처에 매장이 있어야 함');
      });

      test('지역 간 거리 계산 정확성 확인', () async {
        // 각 지역에서의 매장 목록 가져오기
        final downtownStores =
            await storeService.getNearbyStores(49.2856, -123.1115);
        final richmondStores =
            await storeService.getNearbyStores(49.1666, -123.1336);
        final burnabyStores =
            await storeService.getNearbyStores(49.2488, -122.9805);

        // 각 지역의 매장 수 비교
        expect(downtownStores, isNotEmpty);
        expect(richmondStores, isNotEmpty);
        expect(burnabyStores, isNotEmpty);

        // 거리에 따른 매장 수 비교
        expect(
            downtownStores.where((s) => s.distance! <= 5.0).length,
            greaterThanOrEqualTo(
                richmondStores.where((s) => s.distance! <= 5.0).length),
            reason: '다운타운이 Richmond보다 더 많은 근접 매장을 가져야 함');
      });
    });
  });
}
