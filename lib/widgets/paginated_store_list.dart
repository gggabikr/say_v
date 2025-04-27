import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/store.dart';
import 'store_list_item.dart';
import '../pages/store_detail_page.dart';

class PaginatedStoreList extends StatefulWidget {
  final List<Store> stores;
  final ScrollController scrollController;
  final DateTime? selectedDateTime;

  const PaginatedStoreList({
    Key? key,
    required this.stores,
    required this.scrollController,
    this.selectedDateTime,
  }) : super(key: key);

  @override
  State<PaginatedStoreList> createState() => _PaginatedStoreListState();
}

class _PaginatedStoreListState extends State<PaginatedStoreList> {
  static const int itemsPerPage = 20;
  int currentItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadMoreItems();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController.position.pixels >=
        widget.scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (currentItemCount >= widget.stores.length) return;

    setState(() {
      currentItemCount = math.min(
        currentItemCount + itemsPerPage,
        widget.stores.length,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stores.isEmpty) {
      return const Center(
        child: Text(
          'No results found',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: currentItemCount + 1,
      itemBuilder: (context, index) {
        if (index == currentItemCount) {
          if (currentItemCount >= widget.stores.length) {
            return const SizedBox.shrink();
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final store = widget.stores[index];
        return StoreListItem(
          store: store,
          selectedDateTime: widget.selectedDateTime,
        );
      },
    );
  }

  @override
  void didUpdateWidget(PaginatedStoreList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stores != oldWidget.stores) {
      setState(() {
        currentItemCount = 0;
      });
      _loadMoreItems();
    }
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
              builder: (context) => StoreDetailPage(
                store: store,
                currentUserId: 'test_user_id', // TODO: 실제 사용자 ID로 교체 필요
              ),
            ),
          );
        },
      ),
    );
  }
}
