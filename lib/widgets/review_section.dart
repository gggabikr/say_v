import 'package:flutter/material.dart';
import '../models/store.dart';
import '../pages/store_detail_page.dart'; // GalleryViewPage를 사용하기 위한 import
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class ReviewSection extends StatefulWidget {
  final Store store;

  const ReviewSection({
    Key? key,
    required this.store,
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
    return widget.store.reviews.entries
        .any((entry) => entry.key == 'currentUserId'); // TODO: 실제 사용자 ID로 교체 필요
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
              // 사용자 본인의 리뷰를 먼저 표시
              ..._getSortedReviews()
                  .where((entry) =>
                      entry.key == 'currentUserId' && // TODO: 실제 사용자 ID로 교체 필요
                      (entry.value.comment.isNotEmpty ||
                          (entry.value.images?.isNotEmpty ?? false)))
                  .map((entry) => _buildReviewCard(entry.value, true)),

              // 나머지 리뷰들 (코멘트나 사진이 있는 것만)
              ..._getSortedReviews()
                  .where((entry) =>
                      entry.key != 'currentUserId' && // TODO: 실제 사용자 ID로 교체 필요
                      (entry.value.comment.isNotEmpty ||
                          (entry.value.images?.isNotEmpty ?? false)))
                  .map((entry) => _buildReviewCard(entry.value, false)),
            ],
          ),
        ),
      ],
    );
  }

  void _showReviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        onSubmit: (score, comment, List<String>? images) async {
          // TODO: 리뷰 저장 로직 구현
          final newReview = Review(
            score: score,
            timestamp: DateTime.now(),
            userName: 'Current User', // TODO: 실제 사용자 이름으로 교체 필요
            comment: comment,
            images: images,
          );

          // TODO: Firestore에 리뷰 저장
          setState(() {
            // 로컬 상태 업데이트
          });
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
                            // TODO: 수정 기능 구현
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
                          onPressed: () {
                            // TODO: 삭제 기능 구현
                          },
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
                          onPressed: () {
                            // TODO: 신고 기능 구현
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
}

// 리뷰 작성 다이얼로그
class ReviewDialog extends StatefulWidget {
  final Function(double score, String comment, List<String>? images) onSubmit;

  const ReviewDialog({
    Key? key,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();
  final List<String> _images = [];
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => _isUploading = true);

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) return;

      // 이미지 압축
      final bytes = await pickedFile.readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) return;

      // 이미지 리사이즈 및 압축
      int maxWidth = 1024;
      int maxHeight = 1024;

      if (image.width > maxWidth || image.height > maxHeight) {
        double ratio =
            math.min(maxWidth / image.width, maxHeight / image.height);
        image = img.copyResize(
          image,
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
        );
      }

      final compressedBytes =
          Uint8List.fromList(img.encodeJpg(image, quality: 60));

      // Firebase Storage에 업로드
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('review_images')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await storageRef.putData(compressedBytes);
      final downloadUrl = await storageRef.getDownloadURL();

      setState(() {
        _images.add(downloadUrl);
        _isUploading = false;
      });
    } catch (e) {
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
      content: SingleChildScrollView(
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

            // 이미지 업로드 버튼과 미리보기
            Column(
              children: [
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
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Image.network(
                                _images[index],
                                height: 100,
                                width: 100,
                                fit: BoxFit.cover,
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
                ],
              ],
            ),
          ],
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
                  widget.onSubmit(
                    _rating.toDouble(),
                    _commentController.text,
                    _images.isEmpty ? null : _images,
                  );
                  Navigator.pop(context);
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
