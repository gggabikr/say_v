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
    return AlertDialog(
      title: Text(widget.isStoreOwner ? '관리자에게 리뷰 신고' : '리뷰 신고'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<ReportReason>(
              value: _selectedReason,
              items: ReportReason.values.map((reason) {
                return DropdownMenuItem(
                  value: reason,
                  child: Text(reason.text),
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
              ),
            ),
            if (_showDetailInput) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _detailController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: '상세 사유',
                  hintText: '신고 사유를 자세히 설명해주세요 (최대 500자)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () {
            final detail = _showDetailInput ? _detailController.text : null;
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
    );
  }

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }
}
