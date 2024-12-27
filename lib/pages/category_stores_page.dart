import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/store_service.dart';

class CategoryStoresPage extends StatefulWidget {
  final String category;
  final String title;

  const CategoryStoresPage({
    super.key,
    required this.category,
    required this.title,
  });

  @override
  State<CategoryStoresPage> createState() => _CategoryStoresPageState();
}

class _CategoryStoresPageState extends State<CategoryStoresPage> {
  final StoreService _storeService = StoreService();
  String _sortBy = 'name'; // 기본 정렬 방식

  @override
  Widget build(BuildContext context) {
    print('Selected category: ${widget.category}');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'name',
                child: Text('알파벳 순'),
              ),
              const PopupMenuItem(
                value: 'distance',
                child: Text('거리 순'),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Store>>(
        future: _storeService.getStoresByCategory(widget.category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Error loading stores: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final stores = snapshot.data ?? [];
          print(
              'Found ${stores.length} stores for category ${widget.category}');

          return ListView.builder(
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: ListTile(
                  title: Text(store.name),
                  subtitle: Text('메뉴 ${store.menus.length}개'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // TODO: 상점 상세 페이지로 이동
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
