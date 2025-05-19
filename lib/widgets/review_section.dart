import 'package:flutter/material.dart';
import '../models/store.dart';
import '../pages/store_detail_page.dart'; // GalleryViewPage를 사용하기 위한 import
import 'dart:math' as math;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
              // 사용자 본인의 리뷰를 먼저 표시
              ..._getSortedReviews().where((entry) {
                final user = FirebaseAuth.instance.currentUser;
                return entry.key == user?.uid &&
                    (entry.value.comment.isNotEmpty ||
                        (entry.value.images?.isNotEmpty ?? false));
              }).map((entry) => _buildReviewCard(entry.value, true)),

              // 나머지 리뷰들
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
    // Firebase Auth에서 현재 사용자 정보 가져오기
    final user = FirebaseAuth.instance.currentUser;
    print('현재 사용자: ${user?.uid}');

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => ReviewDialog(
        onSubmit: (score, comment, List<String>? images) async {
          print(
              '리뷰 제출 시작 - 점수: $score, 코멘트: $comment, 이미지: ${images?.length}개');

          final newReview = Review(
            score: score,
            timestamp: DateTime.now(),
            userName: user.displayName ?? '익명', // 실제 사용자 이름 사용
            comment: comment,
            images: images,
          );
          print('새 리뷰 객체 생성됨');

          // 새로운 리뷰를 포함한 리뷰 맵 생성
          final updatedReviews = Map<String, Review>.from(widget.store.reviews);
          updatedReviews[user.uid] = newReview;
          print('업데이트된 리뷰 맵 생성됨');

          // 평균 평점 계산
          double totalScore = 0;
          for (var review in updatedReviews.values) {
            totalScore += review.score;
          }
          final newAverageRating = totalScore / updatedReviews.length;
          print('새로운 평균 평점 계산됨: $newAverageRating');

          try {
            print('=== 리뷰 저장 프로세스 시작 ===');
            final storeRef = FirebaseFirestore.instance
                .collection('stores')
                .doc(widget.store.id);

            print('스토어 ID: ${widget.store.id}');
            print('현재 리뷰 수: ${widget.store.reviews.length}');
            print('새로운 리뷰 데이터: ${newReview.toMap()}');

            await storeRef.update({
              'ratings.reviews.${user.uid}': {
                'score': newReview.score,
                'timestamp': Timestamp.fromDate(newReview.timestamp),
                'userName': newReview.userName,
                'comment': newReview.comment,
                'images': newReview.images ?? [],
              },
              'ratings.average': newAverageRating,
              'ratings.total': updatedReviews.length,
            });
            print('Firestore 업데이트 완료');

            // Firestore에서 업데이트된 데이터 다시 불러오기
            final updatedDoc = await storeRef.get();
            print('새로운 문서 데이터 불러옴');

            if (!mounted) {
              print('위젯이 이미 dispose됨');
              return;
            }

            final updatedStore = Store.fromJson({
              'storeId': updatedDoc.id,
              ...updatedDoc.data() ?? {},
            });
            print('새로운 Store 객체 생성됨');
            print('업데이트된 리뷰 수: ${updatedStore.reviews.length}');
            print('업데이트된 평균 평점: ${updatedStore.averageRating}');

            // StoreUpdateNotifier를 통해 업데이트 알림
            StoreUpdateNotifier.instance.notifyStoreUpdate(updatedStore);
            print('스토어 업데이트 노티파이어 호출 완료');

            print('=== 리뷰 저장 프로세스 완료 ===');
          } catch (e, stackTrace) {
            print('리뷰 저장 실패: $e');
            print('스택 트레이스: $stackTrace');
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

      print('이미지 선택 시작');
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        // 이미지 피커에서 직접 리사이징과 압축 처리
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 60,
      );

      if (pickedFile == null) {
        print('이미지 선택 취소됨');
        setState(() => _isUploading = false);
        return;
      }

      print('이미지 선택 완료: ${pickedFile.path}');
      final bytes = await pickedFile.readAsBytes();
      print('이미지 바이트 읽기 완료: ${bytes.length} bytes');

      // Firebase Storage에 업로드
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef =
          FirebaseStorage.instance.ref().child('review_images').child(fileName);

      print('Storage 업로드 시작');
      // 업로드 작업을 별도 Task로 실행
      final uploadTask = storageRef.putData(bytes);

      // 업로드 진행상황 모니터링
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print(
            'Upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes}');
      });

      // 업로드 완료 대기
      await uploadTask;
      print('Storage 업로드 완료');

      final downloadUrl = await storageRef.getDownloadURL();
      print('다운로드 URL 획득: $downloadUrl');

      if (!mounted) return;

      setState(() {
        print('상태 업데이트 시작');
        _images.add(downloadUrl);
        _isUploading = false;
        print('상태 업데이트 완료');
      });

      print('이미지 업로드 프로세스 완료');
    } catch (e, stackTrace) {
      print('이미지 업로드 에러: $e');
      print('스택 트레이스: $stackTrace');
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
