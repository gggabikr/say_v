import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/store.dart';

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
    // 간단한 유클리드 거리 계산 (실제 앱에서는 Haversine 공식 사용 추천)
    return ((lat2 - lat1) * (lat2 - lat1) + (lon2 - lon1) * (lon2 - lon1));
  }
}
