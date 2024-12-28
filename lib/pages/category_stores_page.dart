import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import 'package:geolocator/geolocator.dart';

class CategoryStoresPage extends StatefulWidget {
  final String category;
  final String title;
  final Position? userLocation;

  const CategoryStoresPage({
    Key? key,
    required this.category,
    required this.title,
    this.userLocation,
  }) : super(key: key);

  @override
  State<CategoryStoresPage> createState() => _CategoryStoresPageState();
}

class _CategoryStoresPageState extends State<CategoryStoresPage> {
  final StoreService _storeService = StoreService();
  List<Store> stores = [];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      print('Loading stores for category: ${widget.category}');
      print(
          'User location: ${widget.userLocation?.latitude}, ${widget.userLocation?.longitude}');

      final allStores = await _storeService.getStores();

      if (widget.userLocation != null) {
        // 각 스토어에 대해 현재 위치와의 거리 계산
        for (var store in allStores) {
          double distanceInMeters = Geolocator.distanceBetween(
            widget.userLocation!.latitude,
            widget.userLocation!.longitude,
            store.latitude,
            store.longitude,
          );
          store.distance = distanceInMeters;
        }

        // 거리순으로 정렬
        allStores.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      }

      setState(() {
        stores = allStores;
      });

      print('Loaded ${stores.length} stores');
    } catch (e) {
      print('Error loading stores: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: stores.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: stores.length,
              itemBuilder: (context, index) {
                final store = stores[index];
                return ListTile(
                  title: Text(store.name),
                  subtitle: Text(
                    store.distance != null
                        ? '${(store.distance! / 1000).toStringAsFixed(1)}km'
                        : store.address,
                  ),
                  onTap: () {
                    // 스토어 상세 페이지로 이동
                  },
                );
              },
            ),
    );
  }
}
