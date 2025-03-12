import 'package:say_v/models/user_role.dart';

class User {
  final String uid;
  final String email;
  final String? displayName;
  final UserRole role;
  final List<String> managedStores; // 관리 가능한 스토어 ID 목록
  final List<String> ownedStores; // 소유한 스토어 ID 목록

  User({
    required this.uid,
    required this.email,
    this.displayName,
    required this.role,
    this.managedStores = const [],
    this.ownedStores = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      uid: json['uid'],
      email: json['email'],
      displayName: json['displayName'],
      role: UserRole.fromString(json['role'] ?? 'user'),
      managedStores: List<String>.from(json['managedStores'] ?? []),
      ownedStores: List<String>.from(json['ownedStores'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.value,
      'managedStores': managedStores,
      'ownedStores': ownedStores,
    };
  }

  bool canManageMenu(String storeId) {
    return UserPermissions.canManageMenu(role, storeId, managedStores);
  }

  bool canManageStore(String storeId) {
    return UserPermissions.canManageStore(role, storeId, ownedStores);
  }

  bool canManageUsers() {
    return UserPermissions.canManageUsers(role);
  }

  bool canManagePromotions() {
    return UserPermissions.canManagePromotions(role);
  }

  bool canViewStatistics(String storeId) {
    return UserPermissions.canViewStatistics(role, storeId, ownedStores);
  }
}
