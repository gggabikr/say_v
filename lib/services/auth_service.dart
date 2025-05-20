import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user.dart' as app_user;
import '../models/user_role.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

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
      // Firestore에 사용자 정보 저장 (기본 role은 user)
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'email': email,
          'displayName': displayName,
          'role': UserRole.user.value,
          'managedStores': [],
          'ownedStores': [],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

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

      // Firestore에서 사용자 데이터 확인
      try {
        final userDoc = await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .get();

        print('User document exists: ${userDoc.exists}');
        if (userDoc.exists) {
          print('User data: ${userDoc.data()}');
        } else {
          // 사용자 문서가 없으면 기본 데이터 생성
          await _firestore.collection('users').doc(credential.user!.uid).set({
            'email': email,
            'displayName': credential.user!.displayName ?? '',
            'role': 'user', // 기본 role 설정
            'createdAt': FieldValue.serverTimestamp(),
          });
          print('Created new user document with default role');
        }
      } catch (firestoreError) {
        print('Firestore error during login: $firestoreError');
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error Code: ${e.code}');
      print('Firebase Auth Error Message: ${e.message}');

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
    } catch (e, stackTrace) {
      print('Login error: $e');
      print('Stack trace: $stackTrace');
      return '로그인 중 예상치 못한 오류가 발생했습니다.';
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

// 현재 사용자의 역할 정보를 포함한 상세 정보 가져오기
  Future<app_user.User?> getCurrentUserWithRole() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final doc =
        await _firestore.collection('users').doc(firebaseUser.uid).get();
    if (!doc.exists) return null;

    return app_user.User.fromJson(doc.data()!..['uid'] = firebaseUser.uid);
  }

  // 어드민이 새로운 어드민 계정 생성
  Future<String?> createAdminAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      // 현재 사용자가 어드민인지 확인
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();

      if (!currentUserDoc.exists ||
          currentUserDoc.data()?['role'] != UserRole.admin.value) {
        return '관리자만 새로운 관리자 계정을 생성할 수 있습니다.';
      }

      final callable = _functions.httpsCallable('createAdminAccount');
      final result = await callable.call({
        'email': email,
        'password': password,
        'displayName': displayName,
      });

      if (result.data['success'] == true) {
        return null;
      }
      return '관리자 계정 생성에 실패했습니다.';
    } catch (e) {
      print('Error creating admin account: $e');
      return '관리자 계정 생성 중 오류가 발생했습니다.';
    }
  }

// 스토어 오너 계정 생성
  Future<String?> createStoreOwnerAccount({
    required String email,
    required String password,
    required String displayName,
    required List<String> storeIds,
  }) async {
    try {
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();

      if (!currentUserDoc.exists ||
          currentUserDoc.data()?['role'] != UserRole.admin.value) {
        return '관리자만 스토어 오너 계정을 생성할 수 있습니다.';
      }

      final callable = _functions.httpsCallable('createStoreOwnerAccount');
      final result = await callable.call({
        'email': email,
        'password': password,
        'displayName': displayName,
        'storeIds': storeIds,
      });

      if (result.data['success'] == true) {
        return null;
      }
      return '스토어 오너 계정 생성에 실패했습니다.';
    } catch (e) {
      print('Error creating store owner account: $e');
      return '스토어 오너 계정 생성 중 오류가 발생했습니다.';
    }
  }

// 스토어 매니저 계정 생성
  Future<String?> createStoreManagerAccount({
    required String email,
    required String password,
    required String displayName,
    required List<String> storeIds,
  }) async {
    try {
      final currentUserDoc = await _firestore
          .collection('users')
          .doc(_auth.currentUser?.uid)
          .get();

      if (!currentUserDoc.exists) {
        return '계정 생성 권한이 없습니다.';
      }

      final currentUserRole = currentUserDoc.data()?['role'];
      if (currentUserRole != UserRole.admin.value &&
          currentUserRole != UserRole.storeOwner.value) {
        return '관리자 또는 스토어 오너만 매니저 계정을 생성할 수 있습니다.';
      }

      // 스토어 오너의 경우 자신의 스토어에 대해서만 매니저 생성 가능
      if (currentUserRole == UserRole.storeOwner.value) {
        final ownedStores =
            List<String>.from(currentUserDoc.data()?['ownedStores'] ?? []);
        if (!storeIds.every((id) => ownedStores.contains(id))) {
          return '스토어 오너는 자신이 소유한 스토어의 매니저만 생성할 수 있습니다.';
        }
      }

      final callable = _functions.httpsCallable('createStoreManagerAccount');
      final result = await callable.call({
        'email': email,
        'password': password,
        'displayName': displayName,
        'storeIds': storeIds,
      });

      if (result.data['success'] == true) {
        return null;
      }
      return '스토어 매니저 계정 생성에 실패했습니다.';
    } catch (e) {
      print('Error creating store manager account: $e');
      return '스토어 매니저 계정 생성 중 오류가 발생했습니다.';
    }
  }
}
