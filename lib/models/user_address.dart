import 'package:cloud_firestore/cloud_firestore.dart';

class UserAddress {
  final String docId;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final String nickname;
  final String notes;
  final String unitNumber;
  final bool isDefault;
  final DateTime lastUsed;

  UserAddress({
    required this.docId,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    required this.nickname,
    required this.notes,
    required this.unitNumber,
    required this.isDefault,
    required this.lastUsed,
  });

  factory UserAddress.fromMap(Map<String, dynamic> map,
      {required String docId}) {
    // lastUsed 필드 처리를 더 유연하게 수정
    DateTime parseLastUsed(dynamic lastUsedValue) {
      if (lastUsedValue is Timestamp) {
        return lastUsedValue.toDate();
      } else if (lastUsedValue is String) {
        return DateTime.parse(lastUsedValue);
      } else {
        return DateTime.now(); // 기본값
      }
    }

    return UserAddress(
      docId: docId,
      fullAddress: map['fullAddress'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      nickname: map['nickname'] ?? '',
      notes: map['notes'] ?? '',
      unitNumber: map['unitNumber'] ?? '',
      isDefault: map['isDefault'] ?? false,
      lastUsed: parseLastUsed(map['lastUsed']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullAddress': fullAddress,
      'latitude': latitude,
      'longitude': longitude,
      'nickname': nickname,
      'notes': notes,
      'unitNumber': unitNumber,
      'isDefault': isDefault,
      'lastUsed': Timestamp.fromDate(lastUsed),
    };
  }
}
