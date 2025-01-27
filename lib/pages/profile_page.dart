import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayNameController.text = _authService.currentUser?.displayName ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('프로필'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundImage: user?.photoURL != null
                    ? NetworkImage(user!.photoURL!)
                    : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: '이름',
                hintText: '표시될 이름을 입력하세요',
              ),
            ),
            const SizedBox(height: 20),
            Text('이메일: ${user?.email ?? ""}'),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  String? error = await _authService.updateProfile(
                    displayName: _displayNameController.text,
                  );
                  if (mounted) {
                    if (error == null) {
                      // 프로필 업데이트 성공 후 Firebase 사용자 재로드
                      await FirebaseAuth.instance.currentUser?.reload();

                      // 상태 변경을 강제로 트리거하기 위한 추가 작업
                      setState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('프로필이 업데이트되었습니다.'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );

                      // 잠시 대기 후 이전 페이지로 돌아가기
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(error),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('프로필 업데이트'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }
}
