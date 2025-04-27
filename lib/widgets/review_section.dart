import 'package:flutter/material.dart';
import '../models/store.dart';

class ReviewSection extends StatelessWidget {
  final Store store;
  final String? currentUserId;

  const ReviewSection({
    Key? key,
    required this.store,
    this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 별점 분포 계산
    Map<int, int> ratingDistribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (var review in store.reviews.values) {
      int roundedScore = (review.score + 0.4).floor();
      ratingDistribution[roundedScore] =
          (ratingDistribution[roundedScore] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final leftWidth = availableWidth * 0.25;
              final spacerWidth = availableWidth * 0.10;
              final rightWidth = availableWidth * 0.50;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽: 평균 별점 (25%)
                  SizedBox(
                    width: leftWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 44,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  store.averageRating.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(${store.totalRatings}개)',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 간격 (10%)
                  SizedBox(width: spacerWidth),

                  // 오른쪽: 별점 분포 그래프 (50%)
                  SizedBox(
                    width: rightWidth,
                    child: Column(
                      children: [5, 4, 3, 2, 1].map((score) {
                        final count = ratingDistribution[score] ?? 0;
                        final percentage = store.totalRatings > 0
                            ? count / store.totalRatings
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 16,
                                child: Text(
                                  '$score',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '$count',
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // 리뷰 목록
        ...store.reviews.entries.map((entry) {
          final review = entry.value;
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (currentUserId == entry.key) ...[
                      TextButton(
                        child: const Text('수정', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          // TODO: 수정 기능 구현
                        },
                      ),
                      TextButton(
                        child: const Text('삭제', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          // TODO: 삭제 기능 구현
                        },
                      ),
                    ] else
                      TextButton(
                        child: const Text('신고', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          // TODO: 신고 기능 구현
                        },
                      ),
                  ],
                ),
                Row(
                  children: [
                    ...List.generate(
                      5,
                      (index) => Icon(
                        index < review.score ? Icons.star : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      review.timestamp.toString().split('.')[0], // 날짜 표시
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                if (review.comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(review.comment),
                  ),
                const Divider(height: 24),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
