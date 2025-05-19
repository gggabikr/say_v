import 'package:flutter/material.dart';
import 'package:say_v/models/report.dart';
import 'package:say_v/widgets/report_dialog.dart';
import '../models/store.dart';
import '../pages/store_detail_page.dart'; // GalleryViewPage를 사용하기 위한 import
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/store_update_notifier.dart';

class ReviewSection extends StatefulWidget {
  final Store store;
  final Function(Store) onStoreUpdate;

  const ReviewSection({
    Key? key,
    required this.store,
    required this.onStoreUpdate,
  }) : super(key: key);

  @override
  State<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<ReviewSection> {
  String _sortBy = 'latest'; // 'latest' 또는 'rating'

  Map<int, int> _calculateRatingDistribution() {
    final distribution = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (var review in widget.store.reviews.values) {
      final rating = review.score;
      final bucket =
          (rating + 0.5).floor(); // 1.0 -> 1, 1.5-2.0 -> 2, 2.5-3.0 -> 3, etc.
      distribution[bucket] = (distribution[bucket] ?? 0) + 1;
    }

    return distribution;
  }

  List<MapEntry<String, Review>> _getSortedReviews() {
    var reviews = widget.store.reviews.entries.toList();

    // 정렬 로직
    if (_sortBy == 'latest') {
      reviews.sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));
    } else {
      // 평점순 정렬 시, 같은 평점인 경우 최신순으로 정렬
      reviews.sort((a, b) {
        // 먼저 평점으로 비교
        int scoreCompare = b.value.score.compareTo(a.value.score);
        // 평점이 같으면 시간으로 비교
        if (scoreCompare == 0) {
          return b.value.timestamp.compareTo(a.value.timestamp);
        }
        return scoreCompare;
      });
    }

    return reviews;
  }

  String _getRelativeTimeString(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // 10분 이내
    if (difference.inMinutes < 11) {
      if (difference.inMinutes <= 1) {
        return '방금 전';
      }
      return '${difference.inMinutes}분 전';
    }

    // 50분 이내 (10분 단위)
    if (difference.inMinutes < 51) {
      return '${(difference.inMinutes / 10).floor() * 10}분 전';
    }

    // 24시간 이내
    if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    }

    // 7일 이내
    if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    }

    // 4주 이내
    if (difference.inDays < 28) {
      final weeks = (difference.inDays / 7).floor();
      if (weeks == 0) return '1주 전';
      return '$weeks주 전';
    }

    // 12개월 이내
    if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      if (months == 0) return '1개월 전';
      return '$months개월 전';
    }

    // 1년 이상
    final years = (difference.inDays / 365).floor();
    if (years == 0) return '1년 전';
    return '$years년 전';
  }

  // 현재 사용자의 리뷰 존재 여부 확인
  bool _hasUserReview() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return widget.store.reviews.entries.any((entry) => entry.key == user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final ratingDistribution = _calculateRatingDistribution();
    final maxCount = ratingDistribution.values.reduce((a, b) => a > b ? a : b);
    final reviewCount = widget.store.reviews.values
        .where((review) =>
            review.comment.isNotEmpty || (review.images?.isNotEmpty ?? false))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '리뷰',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // 리뷰 작성 버튼 (이미 리뷰를 작성했다면 숨김)
        if (!_hasUserReview())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton(
              onPressed: () {
                _showReviewDialog(context);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
              child: const Text('리뷰 작성하기'),
            ),
          ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 왼쪽: 평균 별점
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 32,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.store.averageRating.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '별점 ${widget.store.totalRatings}개',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '리뷰 $reviewCount개',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              // 오른쪽: 별점 분포 그래프
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((rating) {
                    final count = ratingDistribution[rating] ?? 0;
                    final ratio = maxCount > 0 ? count / maxCount : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          Text(
                            '$rating',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Stack(
                              children: [
                                Container(
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: ratio,
                                  child: Container(
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.amber,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$count',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 정렬 옵션 드롭다운
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              DropdownButton<String>(
                value: _sortBy,
                items: const [
                  DropdownMenuItem(
                    value: 'latest',
                    child: Text('최신순'),
                  ),
                  DropdownMenuItem(
                    value: 'rating',
                    child: Text('평점순'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _sortBy = value;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        // 리뷰 목록
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // 사용자 본인의 리뷰를 먼저 표시 (코멘트나 이미지 유무와 관계없이)
              ..._getSortedReviews().where((entry) {
                final user = FirebaseAuth.instance.currentUser;
                return entry.key == user?.uid; // 조건 단순화
              }).map((entry) => _buildReviewCard(entry.value, true)),

              // 나머지 리뷰들 (코멘트나 이미지가 있는 경우만)
              ..._getSortedReviews().where((entry) {
                final user = FirebaseAuth.instance.currentUser;
                return entry.key != user?.uid &&
                    (entry.value.comment.isNotEmpty ||
                        (entry.value.images?.isNotEmpty ?? false));
              }).map((entry) => _buildReviewCard(entry.value, false)),
            ],
          ),
        ),
      ],
    );
  }

  void _showReviewDialog(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        onSubmit: (score, comment, images) async {
          // 새 리뷰 작성 로직
          final newReview = Review(
            userName: user.displayName ?? '익명',
            score: score,
            comment: comment,
            timestamp: DateTime.now(),
            images: images,
          );

          final updatedReviews = Map<String, Review>.from(widget.store.reviews);
          updatedReviews[user.uid] = newReview;

          final newAverageRating = updatedReviews.values
                  .map((r) => r.score)
                  .reduce((a, b) => a + b) /
              updatedReviews.length;

          try {
            final storeRef = FirebaseFirestore.instance
                .collection('stores')
                .doc(widget.store.id);

            await storeRef.update({
              'ratings.reviews.${user.uid}': {
                'score': score,
                'timestamp': Timestamp.fromDate(DateTime.now()),
                'userName': user.displayName ?? '익명',
                'comment': comment,
                'images': images ?? [],
              },
              'ratings.average': newAverageRating,
              'ratings.total': updatedReviews.length,
            });

            final updatedDoc = await storeRef.get();
            if (!mounted) return;

            final updatedStore = Store.fromJson({
              'storeId': updatedDoc.id,
              ...updatedDoc.data() ?? {},
            });

            StoreUpdateNotifier.instance.notifyStoreUpdate(updatedStore);
          } catch (e) {
            print('리뷰 저장 실패: $e');
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('리뷰 저장에 실패했습니다.')),
            );
          }
        },
      ),
    );
  }

  Widget _buildReviewCard(Review review, bool isUserReview) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  review.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isUserReview) ...[
                      // 본인 리뷰인 경우 수정, 삭제 버튼
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ReviewDialog(
                                initialRating: review.score,
                                initialComment: review.comment,
                                initialImages: review.images,
                                onSubmit: (score, comment, images) =>
                                    _updateReview(
                                        review, score, comment, images),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.delete, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showDeleteConfirmation(review),
                        ),
                      ),
                    ] else
                      // 다른 사용자의 리뷰인 경우 신고 버튼만
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.flag, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('로그인이 필요합니다.')),
                              );
                              return;
                            }

                            final isStoreOwner = await _isStoreOwner(user);

                            if (!mounted) return;
                            showDialog(
                              context: context,
                              builder: (context) => ReportDialog(
                                isStoreOwner: isStoreOwner,
                                reviewAuthorId: widget.store.reviews.entries
                                    .firstWhere(
                                        (entry) => entry.value == review)
                                    .key,
                                storeId: widget.store.id,
                                onSubmit: (reason, detail) => _submitReport(
                                  review,
                                  reason,
                                  detail,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < review.score ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  review.score.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(review.comment),
            ],
            if (review.images?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images?.length ?? 0,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GalleryViewPage(
                              images: review.images!,
                              initialIndex: index,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: index != review.images!.length - 1 ? 8.0 : 0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            review.images![index],
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            // 리뷰 내용과 시간 표시 사이 간격
            const SizedBox(height: 8),

            // 시간 표시
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _getRelativeTimeString(review.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Review review) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: const Text('이 리뷰를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            child: const Text('취소'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              _deleteReview(review);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReview(Review review) async {
    try {
      print('=== 리뷰 삭제 프로세스 시작 ===');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storeRef =
          FirebaseFirestore.instance.collection('stores').doc(widget.store.id);

      // 현재 리뷰를 제외한 나머지 리뷰들로 새로운 평균 계산
      final updatedReviews = Map<String, Review>.from(widget.store.reviews);
      updatedReviews.remove(user.uid);

      final newAverageRating = updatedReviews.isEmpty
          ? 0.0
          : updatedReviews.values.map((r) => r.score).reduce((a, b) => a + b) /
              updatedReviews.length;

      print('리뷰 삭제 상세:');
      print('삭제 전 리뷰 수: ${widget.store.reviews.length}');
      print('삭제할 리뷰 점수: ${review.score}');
      print('새로운 평균 평점: $newAverageRating');
      print('업데이트된 리뷰 수: ${updatedReviews.length}');

      // Firestore 업데이트
      await storeRef.update({
        'ratings.reviews.${user.uid}': FieldValue.delete(),
        'ratings.average': newAverageRating,
        'ratings.total': updatedReviews.length,
      });

      // 업데이트된 스토어 정보 가져오기
      final updatedDoc = await storeRef.get();
      final updatedStore = Store.fromJson({
        'storeId': updatedDoc.id,
        ...updatedDoc.data() ?? {},
      });

      // StoreUpdateNotifier를 통해 업데이트 알림
      StoreUpdateNotifier.instance.notifyStoreUpdate(updatedStore);
      print('=== 리뷰 삭제 프로세스 완료 ===');
    } catch (e) {
      print('리뷰 삭제 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 삭제에 실패했습니다.')),
      );
    }
  }

  Future<void> _updateReview(Review oldReview, double score, String comment,
      List<String>? images) async {
    try {
      print('=== 리뷰 수정 프로세스 시작 ===');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storeRef =
          FirebaseFirestore.instance.collection('stores').doc(widget.store.id);

      // 새로운 리뷰를 포함한 리뷰 맵 생성
      final updatedReviews = Map<String, Review>.from(widget.store.reviews);
      updatedReviews[user.uid] = Review(
        userName: user.displayName ?? '익명',
        score: score,
        comment: comment,
        timestamp: DateTime.now(),
        images: images,
      );

      // 새로운 평균 평점 계산
      final newAverageRating =
          updatedReviews.values.map((r) => r.score).reduce((a, b) => a + b) /
              updatedReviews.length;

      // Firestore 업데이트
      await storeRef.update({
        'ratings.reviews.${user.uid}': {
          'score': score,
          'timestamp': Timestamp.fromDate(DateTime.now()),
          'userName': user.displayName ?? '익명',
          'comment': comment,
          'images': images ?? [],
        },
        'ratings.average': newAverageRating,
      });

      // 업데이트된 스토어 정보 가져오기
      final updatedDoc = await storeRef.get();
      final updatedStore = Store.fromJson({
        'storeId': updatedDoc.id,
        ...updatedDoc.data() ?? {},
      });

      // StoreUpdateNotifier를 통해 업데이트 알림
      StoreUpdateNotifier.instance.notifyStoreUpdate(updatedStore);
      print('=== 리뷰 수정 프로세스 완료 ===');
    } catch (e) {
      print('리뷰 수정 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('리뷰 수정에 실패했습니다.')),
      );
    }
  }

  Future<void> _submitReport(
      Review review, ReportReason reason, String? detail) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final isStoreOwner = await _isStoreOwner(user);
      final reporterType =
          isStoreOwner ? ReportHandler.storeOwner : ReportHandler.user;
      final initialStatus =
          isStoreOwner ? ReportStatus.reportedToAdmin : ReportStatus.pending;

      final reportRef = FirebaseFirestore.instance.collection('reports').doc();

      final report = Report(
        reportId: reportRef.id,
        reporterId: user.uid,
        reporterType: reporterType,
        reviewAuthorId: widget.store.reviews.entries
            .firstWhere((entry) => entry.value == review)
            .key,
        storeId: widget.store.id,
        timestamp: Timestamp.now(),
        reason: reason,
        detail: detail,
        status: initialStatus,
        statusUpdateTime: Timestamp.now(),
        statusUpdatedBy: user.uid,
        reviewSnapshot: ReviewSnapshot(
          rating: review.score,
          comment: review.comment,
          timestamp: Timestamp.fromDate(review.timestamp),
          images: review.images,
        ),
      );

      await reportRef.set(report.toFirestore());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isStoreOwner ? '관리자에게 신고되었습니다.' : '신고가 접수되었습니다.'),
        ),
      );
    } catch (e) {
      print('리뷰 신고 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고 처리 중 오류가 발생했습니다.')),
      );
    }
  }

  Future<bool> _isStoreOwner(User user) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final List<String> ownedStores =
        List<String>.from(userDoc.data()?['ownedStores'] ?? []);
    return ownedStores.contains(widget.store.id);
  }
}

// 리뷰 작성 다이얼로그
class ReviewDialog extends StatefulWidget {
  final Function(double score, String comment, List<String>? images) onSubmit;
  final double? initialRating;
  final String? initialComment;
  final List<String>? initialImages;

  const ReviewDialog({
    Key? key,
    required this.onSubmit,
    this.initialRating,
    this.initialComment,
    this.initialImages,
  }) : super(key: key);

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  late int _rating;
  late final TextEditingController _commentController;
  late final List<String> _images;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating?.toInt() ?? 5;
    _commentController =
        TextEditingController(text: widget.initialComment ?? '');
    _images = widget.initialImages?.toList() ?? [];
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => _isUploading = true);

      print('이미지 선택 시작');
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 60,
      );

      if (pickedFiles.isEmpty) {
        print('이미지 선택 취소됨');
        setState(() => _isUploading = false);
        return;
      }

      print('선택된 이미지 수: ${pickedFiles.length}');

      for (final pickedFile in pickedFiles) {
        final bytes = await pickedFile.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('review_images')
            .child(fileName);

        await storageRef.putData(bytes);
        final downloadUrl = await storageRef.getDownloadURL();

        if (!mounted) return;
        setState(() {
          _images.add(downloadUrl);
        });
      }

      setState(() => _isUploading = false);
      print('모든 이미지 업로드 완료');
    } catch (e) {
      print('이미지 업로드 에러: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 업로드 실패: $e')),
      );
    }
  }

  Widget _buildStarRating() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < _rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 35,
          ),
          onPressed: () {
            setState(() {
              _rating = index + 1;
            });
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('리뷰 작성'),
      content: Container(
        constraints: const BoxConstraints(maxHeight: 500), // 최대 높이 제한
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStarRating(),
              Text('$_rating점'),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '리뷰를 작성해주세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (_images.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _images[index],
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _images.removeAt(index);
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndUploadImage,
                icon: _isUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera),
                label: Text(_isUploading ? '업로드 중...' : '사진 추가'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isUploading
              ? null
              : () {
                  final score = _rating.toDouble();
                  final comment = _commentController.text;
                  final images = _images.isEmpty ? null : _images;
                  Navigator.pop(context); // 다이얼로그 닫기
                  widget.onSubmit(score, comment, images); // 리뷰 저장 실행
                },
          child: const Text('작성완료'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
