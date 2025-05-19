import 'package:flutter/material.dart';
import '../models/report.dart';

class ReportDialog extends StatefulWidget {
  final bool isStoreOwner; // 스토어 주인인지 여부
  final String reviewAuthorId;
  final String storeId;
  final Function(ReportReason reason, String? detail) onSubmit;

  const ReportDialog({
    Key? key,
    required this.isStoreOwner,
    required this.reviewAuthorId,
    required this.storeId,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  ReportReason _selectedReason = ReportReason.inappropriate;
  final _detailController = TextEditingController();
  bool _showDetailInput = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9, // 더 넓은 너비
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isStoreOwner ? '관리자에게 리뷰 신고' : '리뷰 신고',
                style: const TextStyle(
                  fontSize: 18.0, // 제목 크기 축소
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<ReportReason>(
                value: _selectedReason,
                items: ReportReason.values.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(
                      reason.text,
                      style: const TextStyle(fontSize: 14.0), // 폰트 크기 조정
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedReason = value;
                      _showDetailInput = value == ReportReason.other;
                    });
                  }
                },
                decoration: const InputDecoration(
                  labelText: '신고 사유',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8), // 패딩 축소
                ),
              ),
              if (_showDetailInput) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _detailController,
                  maxLines: 8, // 더 많은 줄 수 허용
                  maxLength: 500,
                  style: const TextStyle(fontSize: 14.0),
                  decoration: const InputDecoration(
                    labelText: '상세 사유',
                    hintText: '신고 사유를 자세히 설명해주세요 (최대 500자)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final detail =
                          _showDetailInput ? _detailController.text : null;
                      if (_showDetailInput && detail?.isEmpty == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('상세 사유를 입력해주세요')),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      widget.onSubmit(_selectedReason, detail);
                    },
                    child: const Text('신고하기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }
}
