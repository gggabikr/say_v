import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/report.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReportedReviewsPage extends StatefulWidget {
  final String storeId;

  const ReportedReviewsPage({
    super.key,
    required this.storeId,
  });

  @override
  State<ReportedReviewsPage> createState() => _ReportedReviewsPageState();
}

class _ReportedReviewsPageState extends State<ReportedReviewsPage>
    with SingleTickerProviderStateMixin {
  final Set<String> _selectedReports = {};
  bool _isProcessing = false;
  late TabController _tabController;
  bool _isDateAscending = false;
  bool _isStatusAscending = false;
  String _currentSortType = 'date'; // 'date' 또는 'status'
  final Set<String> _expandedCards = {}; // 확장된 카드들의 ID를 저장
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // 사용자 역할 확인
    FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .get()
        .then((snapshot) {
      if (mounted) {
        setState(() {
          _isAdmin = snapshot.data()?['role'] == 'admin';
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('신고된 리뷰'),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Column(
              children: [
                // 전체 선택 체크박스
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _selectedReports.isNotEmpty &&
                            _getVisibleReportIds().length ==
                                _selectedReports.length,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedReports.addAll(_getVisibleReportIds());
                            } else {
                              _selectedReports.clear();
                            }
                          });
                        },
                      ),
                      const Text('전체 선택'),
                      const Spacer(),
                      // 날짜순 정렬 텍스트 버튼
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            if (_currentSortType == 'date') {
                              _isDateAscending = !_isDateAscending;
                            } else {
                              _currentSortType = 'date';
                            }
                          });
                        },
                        icon: Icon(
                          _isDateAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: _currentSortType == 'status'
                              ? Colors.grey
                              : Theme.of(context).colorScheme.secondary,
                        ),
                        label: Text(
                          _isDateAscending ? '오래된 순' : '최신 순',
                          style: TextStyle(
                            color: _currentSortType == 'status'
                                ? Colors.grey
                                : Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                      // 상태순 정렬 버튼 (전체 내역 탭에서만 표시)
                      if (_tabController.index == 1)
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              if (_currentSortType == 'status') {
                                _isStatusAscending = !_isStatusAscending;
                              } else {
                                _currentSortType = 'status';
                              }
                            });
                          },
                          icon: Icon(
                            Icons.sort,
                            size: 16,
                            color: _currentSortType == 'date'
                                ? Colors.grey
                                : Theme.of(context).colorScheme.secondary,
                          ),
                          label: Text(
                            _isStatusAscending ? '상태 ↑' : '상태 ↓',
                            style: TextStyle(
                              color: _currentSortType == 'date'
                                  ? Colors.grey
                                  : Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // 탭바
                TabBar(
                  controller: _tabController,
                  tabs: [
                    Tab(text: _isAdmin ? '관리자 보고' : '처리 대기'),
                    const Tab(text: '전체 내역'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // 처리 대기 탭
            _buildReportList(true),
            // 전체 내역 탭
            _buildReportList(false),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildReportList(bool filteredOnly) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getReportsStream(filteredOnly),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('오류가 발생했습니다'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data?.docs ?? [];

        // 정렬 적용
        final sortedReports = _sortReports(reports);

        if (reports.isEmpty) {
          return const Center(child: Text('신고된 리뷰가 없습니다'));
        }

        return ListView.builder(
          itemCount: sortedReports.length,
          itemBuilder: (context, index) {
            final report = sortedReports[index];
            return _buildReportItem(report);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getReportsStream(bool filteredOnly) {
    Query query = FirebaseFirestore.instance
        .collection('reports')
        .where('storeId', isEqualTo: widget.storeId);

    if (filteredOnly) {
      query = query.where(
        'status',
        isEqualTo: _isAdmin
            ? ReportStatus.reportedToAdmin.name
            : ReportStatus.pending.name,
      );
    }

    return query.snapshots();
  }

  List<DocumentSnapshot> _sortReports(List<DocumentSnapshot> reports) {
    return reports
      ..sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;

        if (_currentSortType == 'status' && _tabController.index == 1) {
          // 상태순 정렬 (전체 내역 탭에서만)
          final compareStatus = _compareStatus(
            ReportStatus.values.byName(aData['status'] ?? ''),
            ReportStatus.values.byName(bData['status'] ?? ''),
          );
          if (compareStatus != 0) return compareStatus;

          // 상태가 같은 경우 날짜순으로 정렬 (항상 최신순)
          final aTimestamp = aData['timestamp'] as Timestamp?;
          final bTimestamp = bData['timestamp'] as Timestamp?;
          final aDate = aTimestamp?.toDate() ?? DateTime.now();
          final bDate = bTimestamp?.toDate() ?? DateTime.now();
          return bDate.compareTo(aDate); // 최신순으로 고정
        } else {
          // 날짜순 정렬
          final aTimestamp = aData['timestamp'] as Timestamp?;
          final bTimestamp = bData['timestamp'] as Timestamp?;
          final aDate = aTimestamp?.toDate() ?? DateTime.now();
          final bDate = bTimestamp?.toDate() ?? DateTime.now();
          return _isDateAscending
              ? aDate.compareTo(bDate)
              : bDate.compareTo(aDate);
        }
      });
  }

  int _compareStatus(ReportStatus a, ReportStatus b) {
    final statusOrder = {
      ReportStatus.pending: 0,
      ReportStatus.reportedToAdmin: 1,
      ReportStatus.maintained: 2,
      ReportStatus.ignored: 3,
      ReportStatus.deleted: 4,
    };

    return _isStatusAscending
        ? statusOrder[a]!.compareTo(statusOrder[b]!)
        : statusOrder[b]!.compareTo(statusOrder[a]!);
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

  Widget _buildBottomBar() {
    if (_selectedReports.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final bool isAdmin = snapshot.data?['role'] == 'admin';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: isAdmin
                ? [
                    // 관리자용 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => _processReports(ReportStatus.maintained),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('유지'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => _processReports(ReportStatus.deleted),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('삭제'),
                      ),
                    ),
                  ]
                : [
                    // 오너용 버튼
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : () => _processReports(ReportStatus.ignored),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('무시'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : () =>
                                _processReports(ReportStatus.reportedToAdmin),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('관리자에게 신고'),
                      ),
                    ),
                  ],
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour}시 ${dateTime.minute}분 ${dateTime.second}초';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.yellow.withOpacity(0.16);
      case 'maintained':
        return Colors.green.withOpacity(0.16);
      case 'deleted':
        return Colors.red.withOpacity(0.16);
      case 'ignored':
        return Colors.lightBlue.withOpacity(0.16);
      case 'reportedtoadmin':
        return Colors.orange.withOpacity(0.16);
      default:
        return Colors.transparent;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return '처리 대기';
      case 'maintained':
        return '유지';
      case 'deleted':
        return '삭제';
      case 'ignored':
        return '무시됨';
      case 'reportedtoadmin':
        return '관리자에게 보고됨';
      default:
        return status;
    }
  }

  Widget _buildReportItem(DocumentSnapshot report) {
    final reportData = report.data() as Map<String, dynamic>;
    final isSelected = _selectedReports.contains(report.id);
    final isExpanded = _expandedCards.contains(report.id);
    final status = reportData['status']?.toString() ?? '';
    final bool isAdminHandled = status == ReportStatus.maintained.name ||
        status == ReportStatus.deleted.name;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final bool isAdmin = snapshot.data?['role'] == 'admin';

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _getStatusColor(status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: isAdmin
                  ? () {
                      setState(() {
                        if (_expandedCards.contains(report.id)) {
                          _expandedCards.remove(report.id);
                        } else {
                          _expandedCards.add(report.id);
                        }
                      });
                    }
                  : null,
              child: ListTile(
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (!isAdmin && isAdminHandled)
                      ? null
                      : (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedReports.add(report.id);
                            } else {
                              _selectedReports.remove(report.id);
                            }
                          });
                        },
                ),
                title: Text(reportData['reason']?.toString() ?? ''),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '리뷰 내용: ${reportData['reviewSnapshot']?['comment'] ?? ''}'),
                    if (reportData['detail'] != null)
                      Text('신고 상세: ${reportData['detail']}'),
                    const SizedBox(height: 8),
                    Text(
                      '상태: ${_getStatusText(status)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(isExpanded && isAdmin
                        ? '신고 시각: ${_formatDateTime(reportData['timestamp']?.toDate())}'
                        : '신고 시각: ${_getRelativeTimeString(reportData['timestamp']?.toDate() ?? DateTime.now())}'),
                    if (isAdmin && isExpanded) ...[
                      const Divider(),
                      Text('스토어 ID: ${reportData['storeId'] ?? ''}'),
                      const SizedBox(height: 16), // 공백 추가
                      // 신고자 정보
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(reportData['reporterId'])
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final userData =
                                snapshot.data?.data() as Map<String, dynamic>?;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '신고자 이름: ${userData?['displayName'] ?? ''}'),
                                Text('신고자 이메일: ${userData?['email'] ?? ''}'),
                                Text(
                                    '신고자 ID: ${reportData['reporterId'] ?? ''}'),
                                const SizedBox(height: 16), // 공백 추가
                              ],
                            );
                          }
                          return const CircularProgressIndicator();
                        },
                      ),
                      // 리뷰 작성자 정보
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(reportData['reviewAuthorId'])
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final userData =
                                snapshot.data?.data() as Map<String, dynamic>?;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '리뷰 작성자 이름: ${userData?['displayName'] ?? ''}'),
                                Text('리뷰 작성자 이메일: ${userData?['email'] ?? ''}'),
                                Text(
                                    '리뷰 작성자 ID: ${reportData['reviewAuthorId'] ?? ''}'),
                                const SizedBox(height: 16), // 공백 추가
                              ],
                            );
                          }
                          return const CircularProgressIndicator();
                        },
                      ),
                      Text(
                          '리뷰 작성 시각: ${_formatDateTime(reportData['reviewSnapshot']?['timestamp']?.toDate())}'),
                      Text(
                          '리뷰 평점: ${reportData['reviewSnapshot']?['rating']?.toString() ?? ''}'),
                      const SizedBox(height: 8), // 이미지 위 공백 추가
                      // 리뷰 이미지 표시
                      if (reportData['reviewSnapshot']?['images'] != null &&
                          reportData['reviewSnapshot']?['images'] is List &&
                          (reportData['reviewSnapshot']?['images'] as List)
                              .isNotEmpty)
                        SizedBox(
                          height: 100, // 이미지 높이 조정
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: (reportData['reviewSnapshot']?['images']
                                    as List)
                                .length,
                            itemBuilder: (context, index) {
                              final imageUrl = reportData['reviewSnapshot']
                                  ?['images'][index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    width: 100,
                                    height: 100,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
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

  // 현재 보이는 리포트 ID들을 가져오는 헬퍼 메소드
  Set<String> _getVisibleReportIds() {
    final reports =
        _tabController.index == 0 ? _getPendingReports() : _getAllReports();
    return reports.map((doc) => doc.id).toSet();
  }

  // 처리 대기 중인 리포트만 가져오기
  List<DocumentSnapshot> _getPendingReports() {
    // 실제 구현은 현재 보이는 리포트 목록을 반환하도록 해야 합니다
    return []; // TODO: 실제 구현 필요
  }

  // 모든 리포트 가져오기
  List<DocumentSnapshot> _getAllReports() {
    // 실제 구현은 현재 보이는 리포트 목록을 반환하도록 해야 합니다
    return []; // TODO: 실제 구현 필요
  }
}
