enum UserRole {
  admin('admin'), // 총관리자
  storeOwner('owner'), // 스토어 오너
  storeManager('manager'), // 스토어 매니저
  user('user'); // 일반 유저

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.user,
    );
  }
}

class UserPermissions {
  static bool canManageMenu(
      UserRole role, String storeId, List<String> managedStores) {
    return role == UserRole.admin ||
        ((role == UserRole.storeOwner || role == UserRole.storeManager) &&
            managedStores.contains(storeId));
  }

  static bool canManageStore(
      UserRole role, String storeId, List<String> ownedStores) {
    return role == UserRole.admin ||
        (role == UserRole.storeOwner && ownedStores.contains(storeId));
  }

  static bool canManageUsers(UserRole role) {
    return role == UserRole.admin;
  }

  static bool canManagePromotions(UserRole role) {
    return role == UserRole.admin;
  }

  static bool canViewStatistics(
      UserRole role, String storeId, List<String> ownedStores) {
    return role == UserRole.admin ||
        (role == UserRole.storeOwner && ownedStores.contains(storeId));
  }
}
