import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report.dart';

class ReportedReviewsPage extends StatefulWidget {
  final String storeId;

  const ReportedReviewsPage({
    Key? key,
    required this.storeId,
  }) : super(key: key);

  @override
  State<ReportedReviewsPage> createState() => _ReportedReviewsPageState();
}

class _ReportedReviewsPageState extends State<ReportedReviewsPage> {
  final Set<String> _selectedReports = {};
  bool _isProcessing = false;

  Stream<List<Report>> _getReportsStream() {
    return FirebaseFirestore.instance
        .collection('reports')
        .where('storeId', isEqualTo: widget.storeId)
        .where('status', isEqualTo: ReportStatus.pending.name)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Report.fromFirestore(doc)).toList());
  }

  Future<void> _processReports(ReportStatus newStatus) async {
    if (_selectedReports.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리할 신고를 선택해주세요')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final user = FirebaseAuth.instance.currentUser;

      for (final reportId in _selectedReports) {
        final reportRef =
            FirebaseFirestore.instance.collection('reports').doc(reportId);

        batch.update(reportRef, {
          'status': newStatus.name,
          'statusUpdateTime': Timestamp.now(),
          'statusUpdatedBy': user?.uid,
        });
      }

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _selectedReports.clear();
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == ReportStatus.reportedToAdmin
              ? '선택한 신고가 관리자에게 전달되었습니다'
              : '선택한 신고가 무시되었습니다'),
        ),
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리 중 오류가 발생했습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('신고된 리뷰'),
        actions: [
          if (_selectedReports.isNotEmpty) ...[
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => _processReports(ReportStatus.ignored),
              child: const Text(
                '무시',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: _isProcessing
                  ? null
                  : () => _processReports(ReportStatus.reportedToAdmin),
              child: const Text(
                '관리자에게 신고',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ],
      ),
      body: StreamBuilder<List<Report>>(
        stream: _getReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('오류가 발생했습니다: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!;

          if (reports.isEmpty) {
            return const Center(child: Text('신고된 리뷰가 없습니다'));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              final isSelected = _selectedReports.contains(report.reportId);

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: ListTile(
                  leading: Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedReports.add(report.reportId);
                        } else {
                          _selectedReports.remove(report.reportId);
                        }
                      });
                    },
                  ),
                  title: Text(report.reason.text),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('리뷰 내용: ${report.reviewSnapshot.comment}'),
                      if (report.detail != null)
                        Text('신고 상세: ${report.detail}'),
                      Text(
                          '신고 시각: ${_getRelativeTimeString(report.timestamp.toDate())}'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getRelativeTimeString(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}주 전';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}개월 전';
    } else {
      return '${(difference.inDays / 365).floor()}년 전';
    }
  }
}
