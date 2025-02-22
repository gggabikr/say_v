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
      const dateStr = '2024-03-14T12:00:00.000Z';
      final map = {
        'fullAddress': '456 Test Ave',
        'latitude': 37.5,
        'longitude': 127.0,
        'nickname': 'Office',
        'notes': '',
        'unitNumber': '',
        'isDefault': false,
        'lastUsed': dateStr,
      };

      final address = UserAddress.fromMap(map, docId: 'test-doc-id');

      expect(address.lastUsed, DateTime.parse(dateStr));
    });

    test('fromMap with missing fields', () {
      final map = <String, dynamic>{};
      final address = UserAddress.fromMap(map, docId: 'test-doc-id');

      expect(address.fullAddress, '');
      expect(address.latitude, 0.0);
      expect(address.longitude, 0.0);
      expect(address.nickname, '');
      expect(address.notes, '');
      expect(address.unitNumber, '');
      expect(address.isDefault, false);
      expect(address.lastUsed.isBefore(DateTime.now()), true);
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
  });
}
