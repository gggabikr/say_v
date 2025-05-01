import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import 'store_list_item.dart';
import '../pages/store_detail_page.dart';

class PaginatedStoreList extends StatelessWidget {
  final List<Store> stores;
  final ScrollController scrollController;
  final DateTime? selectedDateTime;
  final StoreService storeService = StoreService();

  PaginatedStoreList({
    Key? key,
    required this.stores,
    required this.scrollController,
    this.selectedDateTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      itemCount: stores.length,
      itemBuilder: (context, index) {
        return StoreListItem(
          store: stores[index],
          selectedDateTime: selectedDateTime,
        );
      },
    );
  }
}

class StoreCard extends StatelessWidget {
  final Store store;
  final DateTime? selectedDateTime;

  const StoreCard({
    Key? key,
    required this.store,
    this.selectedDateTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        title: Text(store.name),
        subtitle: Text(store.address),
        trailing: const Text('000-000-0000'), // 임시 전화번호
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StoreDetailPage(store: store),
            ),
          );
        },
      ),
    );
  }
}
