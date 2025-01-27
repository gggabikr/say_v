import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 유저 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 이메일/비밀번호로 로그인
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (email.isEmpty || password.isEmpty) {
      return '이메일과 비밀번호를 입력해주세요.';
    }

    try {
      // iOS에서의 초기화 문제 해결을 위한 딜레이
      await Future.delayed(const Duration(milliseconds: 500));

      // 현재 Auth 상태 확인
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }

      // 로그인 시도
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // iOS에서의 상태 업데이트를 위한 추가 딜레이
      await Future.delayed(const Duration(milliseconds: 100));

      if (_auth.currentUser == null) {
        return '로그인에 실패했습니다.';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return '해당 이메일로 등록된 사용자가 없습니다.';
        case 'wrong-password':
          return '잘못된 비밀번호입니다.';
        case 'invalid-email':
          return '유효하지 않은 이메일 형식입니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        default:
          return e.message ?? '로그인 중 오류가 발생했습니다.';
      }
    } catch (e) {
      print('Login error: $e');
      return '로그인 중 예상치 못한 오류가 발생했습니다.';
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
