import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';

class StoreUploadPage extends StatefulWidget {
  const StoreUploadPage({Key? key}) : super(key: key);

  @override
  State<StoreUploadPage> createState() => _StoreUploadPageState();
}

class _StoreUploadPageState extends State<StoreUploadPage> {
  bool _isUploading = false;
  String _uploadStatus = '';
  final List<String> _uploadLogs = [];

  Future<void> _pickAndProcessExcel() async {
    try {
      setState(() {
        _isUploading = true;
        _uploadStatus = '파일 선택 중...';
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null) {
        setState(() {
          _uploadStatus = '파일 선택이 취소되었습니다.';
          _isUploading = false;
        });
        return;
      }

      _addLog('파일 선택 완료: ${result.files.first.name}');
      setState(() => _uploadStatus = '파일 처리 중...');

      // TODO: 엑셀 파일 처리 로직 구현
    } catch (e) {
      _addLog('오류 발생: $e');
      setState(() => _uploadStatus = '오류가 발생했습니다.');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _addLog(String log) {
    setState(() {
      _uploadLogs.insert(
          0, '${DateTime.now().toString().split('.')[0]} - $log');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스토어 데이터 업로드'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '엑셀 파일 업로드',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '지원 형식: .xlsx, .xls\n'
              '첫 번째 행은 헤더로 처리됩니다.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickAndProcessExcel,
                icon: Icon(
                    _isUploading ? Icons.hourglass_empty : Icons.upload_file),
                label: Text(_isUploading ? '업로드 중...' : '파일 선택'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _uploadStatus,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '업로드 로그',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _uploadLogs.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(_uploadLogs[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
