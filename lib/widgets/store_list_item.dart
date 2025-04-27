import 'package:flutter/material.dart';
import '../models/store.dart';
import '../pages/store_detail_page.dart';

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

    return GestureDetector(
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
      child: Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (store.totalRatings > 0) ...[
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 1),
                              Text(
                                store.averageRating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${store.totalRatings})',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'New!',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            if (store.distance != null) ...[
                              const SizedBox(width: 8),
                              const Text('•'),
                              const SizedBox(width: 8),
                              Text(
                                '${store.distance!.toStringAsFixed(1)}km',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
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
            ),
          ],
        ),
      ),
    );
  }
}
