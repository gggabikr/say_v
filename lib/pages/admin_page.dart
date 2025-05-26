import 'package:flutter/material.dart';
import 'store_upload_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 페이지'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildAdminButton(
              context,
              '스토어 데이터 업로드',
              Icons.upload_file,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StoreUploadPage(),
                ),
              ),
            ),
            _buildAdminButton(
              context,
              '사용자 관리',
              Icons.people,
              () {
                // 사용자 관리 페이지로 이동
              },
            ),
            _buildAdminButton(
              context,
              '리뷰 관리',
              Icons.rate_review,
              () {
                // 리뷰 관리 페이지로 이동
              },
            ),
            _buildAdminButton(
              context,
              '통계 및 분석',
              Icons.analytics,
              () {
                // 통계 페이지로 이동
              },
            ),
            _buildAdminButton(
              context,
              '시스템 설정',
              Icons.settings,
              () {
                // 설정 페이지로 이동
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminButton(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 80,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 30),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }
}
