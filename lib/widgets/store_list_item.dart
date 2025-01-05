import 'package:flutter/material.dart';
import '../models/store.dart';

class StoreListItem extends StatelessWidget {
  final Store store;
  final DateTime? selectedDateTime;

  const StoreListItem({
    Key? key,
    required this.store,
    this.selectedDateTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOpen = selectedDateTime == null
        ? store.isCurrentlyOpen()
        : store.isOpenAt(selectedDateTime!);

    final isHappyHour = selectedDateTime == null
        ? store.isHappyHourNow()
        : store.isHappyHourAt(selectedDateTime!);

    return ListTile(
      title: Text(store.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (store.totalRatings > 0) ...[
                const Icon(Icons.star, color: Colors.amber, size: 16),
                Text(
                  ' ${store.cachedAverageRating.toStringAsFixed(1)} ',
                  style: const TextStyle(color: Colors.black87),
                ),
                Text(
                  '(${store.totalRatings})',
                  style: const TextStyle(color: Colors.grey),
                ),
              ] else
                const Text(
                  'New!',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOpen
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isOpen ? 'Open' : 'Closed',
                  style: TextStyle(
                    color: isOpen ? Colors.green : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isHappyHour) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Happy Hour',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            store.distance != null
                ? '${(store.distance! / 1000).toStringAsFixed(1)}km'
                : store.address,
          ),
        ],
      ),
    );
  }
}
