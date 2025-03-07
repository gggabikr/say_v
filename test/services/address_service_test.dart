import 'package:flutter_test/flutter_test.dart';
import 'package:say_v/services/address_service.dart';
import 'package:say_v/models/user_address.dart';

void main() {
  group('UserAddress 모델 테스트', () {
    test('기본 생성자 테스트', () {
      final address = UserAddress(
        docId: 'test-id',
        fullAddress: '123 Test St, Vancouver, BC',
        nickname: 'Home',
        latitude: 49.2827,
        longitude: -123.1207,
        isDefault: true,
        notes: 'Test note',
        unitNumber: '101',
        lastUsed: DateTime(2024),
      );

      expect(address.docId, 'test-id');
      expect(address.fullAddress, '123 Test St, Vancouver, BC');
      expect(address.nickname, 'Home');
      expect(address.latitude, 49.2827);
      expect(address.longitude, -123.1207);
      expect(address.isDefault, true);
      expect(address.notes, 'Test note');
      expect(address.unitNumber, '101');
      expect(address.lastUsed, DateTime(2024));
    });

    test('toMap과 fromMap 변환 테스트', () {
      final originalAddress = UserAddress(
        docId: 'test-id',
        fullAddress: '123 Test St, Vancouver, BC',
        nickname: 'Home',
        latitude: 49.2827,
        longitude: -123.1207,
        isDefault: true,
        notes: 'Test note',
        unitNumber: '101',
        lastUsed: DateTime(2024),
      );

      final map = originalAddress.toMap();
      final convertedAddress = UserAddress.fromMap(map, docId: 'test-id');

      expect(convertedAddress.docId, originalAddress.docId);
      expect(convertedAddress.fullAddress, originalAddress.fullAddress);
      expect(convertedAddress.nickname, originalAddress.nickname);
      expect(convertedAddress.latitude, originalAddress.latitude);
      expect(convertedAddress.longitude, originalAddress.longitude);
      expect(convertedAddress.isDefault, originalAddress.isDefault);
      expect(convertedAddress.notes, originalAddress.notes);
      expect(convertedAddress.unitNumber, originalAddress.unitNumber);
      expect(convertedAddress.lastUsed.toString(),
          originalAddress.lastUsed.toString());
    });

    test('copyWith 메서드 테스트', () {
      final originalAddress = UserAddress(
        docId: 'test-id',
        fullAddress: '123 Test St, Vancouver, BC',
        nickname: 'Home',
        latitude: 49.2827,
        longitude: -123.1207,
        isDefault: true,
        notes: 'Test note',
        unitNumber: '101',
        lastUsed: DateTime(2024),
      );

      final updatedAddress = originalAddress.copyWith(
        nickname: 'Work',
        isDefault: false,
        notes: 'Updated note',
      );

      // 변경된 필드 확인
      expect(updatedAddress.nickname, 'Work');
      expect(updatedAddress.isDefault, false);
      expect(updatedAddress.notes, 'Updated note');

      // 변경되지 않은 필드 확인
      expect(updatedAddress.docId, originalAddress.docId);
      expect(updatedAddress.fullAddress, originalAddress.fullAddress);
      expect(updatedAddress.latitude, originalAddress.latitude);
      expect(updatedAddress.longitude, originalAddress.longitude);
      expect(updatedAddress.unitNumber, originalAddress.unitNumber);
      expect(updatedAddress.lastUsed, originalAddress.lastUsed);
    });

    test('동일한 값을 가진 주소 비교 테스트', () {
      final address1 = UserAddress(
        docId: 'test-id',
        fullAddress: '123 Test St, Vancouver, BC',
        nickname: 'Home',
        latitude: 49.2827,
        longitude: -123.1207,
        isDefault: true,
        notes: 'Test note',
        unitNumber: '101',
        lastUsed: DateTime(2024),
      );

      final address2 = UserAddress(
        docId: 'test-id',
        fullAddress: '123 Test St, Vancouver, BC',
        nickname: 'Home',
        latitude: 49.2827,
        longitude: -123.1207,
        isDefault: true,
        notes: 'Test note',
        unitNumber: '101',
        lastUsed: DateTime(2024),
      );

      final address3 = UserAddress(
        docId: 'different-id',
        fullAddress: '456 Other St, Vancouver, BC',
        nickname: 'Work',
        latitude: 49.2827,
        longitude: -123.1207,
        isDefault: false,
        notes: 'Different note',
        unitNumber: '202',
        lastUsed: DateTime(2024),
      );

      // 각 필드별로 비교
      expect(address1.docId, address2.docId);
      expect(address1.fullAddress, address2.fullAddress);
      expect(address1.nickname, address2.nickname);
      expect(address1.latitude, address2.latitude);
      expect(address1.longitude, address2.longitude);
      expect(address1.isDefault, address2.isDefault);
      expect(address1.notes, address2.notes);
      expect(address1.unitNumber, address2.unitNumber);
      expect(address1.lastUsed, address2.lastUsed);

      // 다른 주소와 비교
      expect(address1.docId != address3.docId, true);
      expect(address1.fullAddress != address3.fullAddress, true);
      expect(address1.nickname != address3.nickname, true);
      expect(address1.isDefault != address3.isDefault, true);
      expect(address1.notes != address3.notes, true);
      expect(address1.unitNumber != address3.unitNumber, true);
    });
  });
}
