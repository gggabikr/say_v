import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:say_v/models/user_address.dart';

void main() {
  group('UserAddress Tests', () {
    test('fromMap with Timestamp lastUsed', () {
      final now = DateTime.now();
      final timestamp = Timestamp.fromDate(now);
      final map = {
        'fullAddress': '123 Test St',
        'latitude': 37.5665,
        'longitude': 126.9780,
        'nickname': 'Home',
        'notes': 'Front door',
        'unitNumber': '101',
        'isDefault': true,
        'lastUsed': timestamp,
      };

      final address = UserAddress.fromMap(map, docId: 'test-doc-id');

      expect(address.docId, 'test-doc-id');
      expect(address.fullAddress, '123 Test St');
      expect(address.latitude, 37.5665);
      expect(address.longitude, 126.9780);
      expect(address.nickname, 'Home');
      expect(address.notes, 'Front door');
      expect(address.unitNumber, '101');
      expect(address.isDefault, true);
      expect(address.lastUsed.year, now.year);
      expect(address.lastUsed.month, now.month);
      expect(address.lastUsed.day, now.day);
    });

    test('fromMap with String lastUsed', () {
      final address = UserAddress.fromMap({
        'fullAddress': '123 Test St',
        'latitude': 49.2342257,
        'longitude': -123.1515023,
        'nickname': 'Home',
        'notes': '',
        'unitNumber': '',
        'isDefault': true,
        'lastUsed': '2024-02-20T12:00:00.000Z',
      }, docId: 'test-id');

      expect(address.lastUsed.isBefore(DateTime.now()), true);
    });

    test('fromMap handles missing optional fields', () {
      final address = UserAddress.fromMap({
        'fullAddress': '123 Test St',
        'latitude': 49.2342257,
        'longitude': -123.1515023,
        'nickname': 'Home',
        'isDefault': true,
      }, docId: 'test-id');

      expect(address.notes, '');
      expect(address.unitNumber, '');
      expect(address.lastUsed, DateTime(1970));
    });

    test('toMap conversion', () {
      final now = DateTime.now();
      final address = UserAddress(
        docId: 'test-doc-id',
        fullAddress: '123 Test St',
        latitude: 37.5665,
        longitude: 126.9780,
        nickname: 'Home',
        notes: 'Front door',
        unitNumber: '101',
        isDefault: true,
        lastUsed: now,
      );

      final map = address.toMap();

      expect(map['fullAddress'], '123 Test St');
      expect(map['latitude'], 37.5665);
      expect(map['longitude'], 126.9780);
      expect(map['nickname'], 'Home');
      expect(map['notes'], 'Front door');
      expect(map['unitNumber'], '101');
      expect(map['isDefault'], true);
      expect(map['lastUsed'], isA<Timestamp>());
    });

    test('copyWith method', () {
      final original = UserAddress(
        docId: 'test-doc-id',
        fullAddress: '123 Test St',
        latitude: 37.5665,
        longitude: 126.9780,
        nickname: 'Home',
        notes: 'Front door',
        unitNumber: '101',
        isDefault: true,
        lastUsed: DateTime.now(),
      );

      final updated = original.copyWith(
        nickname: 'New Home',
        isDefault: false,
      );

      expect(updated.docId, original.docId);
      expect(updated.fullAddress, original.fullAddress);
      expect(updated.latitude, original.latitude);
      expect(updated.longitude, original.longitude);
      expect(updated.nickname, 'New Home');
      expect(updated.notes, original.notes);
      expect(updated.unitNumber, original.unitNumber);
      expect(updated.isDefault, false);
      expect(updated.lastUsed, original.lastUsed);
    });

    test('fromMap correctly parses DateTime', () {
      final now = DateTime.now();
      final address = UserAddress.fromMap({
        'fullAddress': '123 Test St',
        'latitude': 49.2342257,
        'longitude': -123.1515023,
        'nickname': 'Home',
        'isDefault': true,
        'lastUsed': Timestamp.fromDate(now),
      }, docId: 'test-id');

      // lastUsed가 null이 아닌 경우에만 테스트
      expect(address.lastUsed, isNotNull);
      expect(address.lastUsed.year, now.year);
      expect(address.lastUsed.month, now.month);
      expect(address.lastUsed.day, now.day);
    });

    test('fromMap handles string timestamp', () {
      final address = UserAddress.fromMap({
        'fullAddress': '123 Test St',
        'latitude': 49.2342257,
        'longitude': -123.1515023,
        'nickname': 'Home',
        'isDefault': true,
        'lastUsed': '2024-02-20T12:00:00.000Z',
      }, docId: 'test-id');

      expect(address.lastUsed, isNotNull);
      expect(address.lastUsed.isBefore(DateTime.now()), true);
    });
  });
}
