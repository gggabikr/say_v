import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 유저 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 현재 로그인된 유저 가져오기
  User? get currentUser => _auth.currentUser;

  // 이메일/비밀번호로 회원가입
  Future<String?> signUpWithEmailAndPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      await Firebase.initializeApp();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // 사용자 이름 업데이트
      await credential.user?.updateDisplayName(displayName);

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return '비밀번호가 너무 약합니다.';
        case 'email-already-in-use':
          return '이미 사용 중인 이메일입니다.';
        case 'invalid-email':
          return '유효하지 않은 이메일 형식입니다.';
        default:
          return e.message ?? '회원가입 중 오류가 발생했습니다.';
      }
    } catch (e) {
      return '회원가입 중 예상치 못한 오류가 발생했습니다.';
    }
  }

  // 비밀번호 재설정 이메일 보내기
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return '해당 이메일로 등록된 사용자가 없습니다.';
        case 'invalid-email':
          return '유효하지 않은 이메일 형식입니다.';
        default:
          return e.message ?? '비밀번호 재설정 이메일 전송 중 오류가 발생했습니다.';
      }
    }
  }

  // 사용자 프로필 업데이트
  Future<String?> updateProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await user.updatePhotoURL(photoURL);
        await user.reload(); // 사용자 정보 즉시 새로고침

        // 상태 변경을 강제로 트리거
        _auth.currentUser?.reload();

        return null;
      }
      return '로그인된 사용자가 없습니다.';
    } catch (e) {
      return '프로필 업데이트 중 오류가 발생했습니다.';
    }
  }

  // 이메일/비밀번호로 로그인
  Future<String?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (email.isEmpty || password.isEmpty) {
      return '이메일과 비밀번호를 입력해주세요.';
    }

    try {
      await Firebase.initializeApp();

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user?.uid == null) {
        return '로그인에 실패했습니다.';
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error Code: ${e.code}'); // 디버깅용 로그

      switch (e.code) {
        case 'user-not-found':
          return '등록되지 않은 이메일입니다.';
        case 'wrong-password':
          return '잘못된 비밀번호입니다.';
        case 'invalid-email':
          return '유효하지 않은 이메일 형식입니다.';
        case 'user-disabled':
          return '비활성화된 계정입니다.';
        case 'invalid-credential':
          return '이메일 또는 비밀번호가 올바르지 않습니다.';
        case 'too-many-requests':
          return '너무 많은 로그인 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
        case 'operation-not-allowed':
          return '이메일/비밀번호 로그인이 비활성화되어 있습니다.';
        default:
          print('Unhandled Firebase Auth Error: ${e.message}'); // 디버깅용 로그
          return '로그인에 실패했습니다. 이메일과 비밀번호를 확인해주세요.';
      }
    } catch (e) {
      print('Login error: $e'); // 디버깅용 로그
      return '로그인 중 예상치 못한 오류가 발생했습니다.';
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
