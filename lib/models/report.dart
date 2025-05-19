import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportReason {
  inappropriate('부적절한 내용'),
  harassment('괴롭힘/비하'),
  spam('스팸/광고'),
  fake('허위 리뷰'),
  offensive('욕설/비속어'),
  privacy('개인정보 노출'),
  adult('선정적인 내용'),
  irrelevant('리뷰와 무관한 내용'),
  discrimination('차별/혐오'),
  other('기타/직접입력');

  final String text;
  const ReportReason(this.text);
}

enum ReportStatus {
  pending('검토 대기중'),
  ignored('가게 주인이 무시함'),
  reportedToAdmin('관리자 검토중'),
  deleted('리뷰 삭제됨'),
  maintained('리뷰 유지됨');

  final String text;
  const ReportStatus(this.text);
}

enum ReportHandler {
  user('일반 사용자'),
  storeOwner('가게 주인'),
  admin('관리자');

  final String text;
  const ReportHandler(this.text);
}

class Report {
  final String reportId;
  final String reporterId;
  final ReportHandler reporterType;
  final String reviewAuthorId;
  final String storeId;

  final Timestamp timestamp;
  final ReportReason reason;
  final String? detail;

  final ReportStatus status;
  final Timestamp statusUpdateTime;
  final String statusUpdatedBy;

  final ReviewSnapshot reviewSnapshot;

  final String? adminNote;
  final Timestamp? adminActionTime;

  Report({
    required this.reportId,
    required this.reporterId,
    required this.reporterType,
    required this.reviewAuthorId,
    required this.storeId,
    required this.timestamp,
    required this.reason,
    this.detail,
    required this.status,
    required this.statusUpdateTime,
    required this.statusUpdatedBy,
    required this.reviewSnapshot,
    this.adminNote,
    this.adminActionTime,
  });

  factory Report.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Report(
      reportId: doc.id,
      reporterId: data['reporterId'],
      reporterType: ReportHandler.values.firstWhere(
        (e) => e.name == data['reporterType'],
      ),
      reviewAuthorId: data['reviewAuthorId'],
      storeId: data['storeId'],
      timestamp: data['timestamp'],
      reason: ReportReason.values.firstWhere(
        (e) => e.name == data['reason'],
      ),
      detail: data['detail'],
      status: ReportStatus.values.firstWhere(
        (e) => e.name == data['status'],
      ),
      statusUpdateTime: data['statusUpdateTime'],
      statusUpdatedBy: data['statusUpdatedBy'],
      reviewSnapshot: ReviewSnapshot.fromMap(data['reviewSnapshot']),
      adminNote: data['adminNote'],
      adminActionTime: data['adminActionTime'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reporterId': reporterId,
      'reporterType': reporterType.name,
      'reviewAuthorId': reviewAuthorId,
      'storeId': storeId,
      'timestamp': timestamp,
      'reason': reason.name,
      'detail': detail,
      'status': status.name,
      'statusUpdateTime': statusUpdateTime,
      'statusUpdatedBy': statusUpdatedBy,
      'reviewSnapshot': reviewSnapshot.toMap(),
      'adminNote': adminNote,
      'adminActionTime': adminActionTime,
    };
  }
}

class ReviewSnapshot {
  final double rating;
  final String comment;
  final Timestamp timestamp;
  final List<String>? images;

  ReviewSnapshot({
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.images,
  });

  factory ReviewSnapshot.fromMap(Map<String, dynamic> data) {
    return ReviewSnapshot(
      rating: data['rating'].toDouble(),
      comment: data['comment'],
      timestamp: data['timestamp'],
      images: (data['images'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
      'images': images,
    };
  }
}
