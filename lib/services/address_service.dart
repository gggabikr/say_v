import 'dart:async'; // StreamController를 위한 import 추가
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import '../models/user_address.dart';
import 'package:flutter/foundation.dart';

class AddressService {
  static final AddressService _instance = AddressService._internal();
  factory AddressService() => _instance;
  AddressService._internal() {
    _addressController = StreamController<UserAddress?>.broadcast();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final StreamController<UserAddress?> _addressController;
  Stream<UserAddress?> get addressStream => _addressController.stream;

  CollectionReference get addressCollection {
    if (_auth.currentUser == null) {
      throw Exception('User not logged in');
    }
    return _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('addresses');
  }

  // 주소 목록 스트림
  Future<List<UserAddress>> getAddresses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .get();

      return snapshot.docs
          .map((doc) => UserAddress.fromMap(
                doc.data(),
                docId: doc.id,
              ))
          .toList();
    } catch (e) {
      print('Error getting addresses: $e');
      return [];
    }
  }

  // 새 주소 추가
  Future<void> addAddress(UserAddress address) async {
    try {
      if (_auth.currentUser == null) {
        throw Exception('User not logged in');
      }
      print('Adding address: ${address.fullAddress}');
      await addressCollection.add(address.toMap());
      print('Address added successfully');
    } catch (e) {
      print('Error adding address: $e');
      rethrow;
    }
  }

  // 주소 업데이트
  Future<void> updateAddress(UserAddress address) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final addressCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      await addressCollection.doc(address.docId).update(address.toMap());
    } catch (e) {
      print('Error updating address: $e');
      rethrow;
    }
  }

  // 주소 삭제
  Future<void> deleteAddress(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final addressCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      await addressCollection.doc(docId).delete();
    } catch (e) {
      print('Error deleting address: $e');
      rethrow;
    }
  }

  // 기본 주소 설정
  Future<void> setDefaultAddress(String docId) async {
    try {
      if (_addressController.isClosed) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final batch = FirebaseFirestore.instance.batch();
      final addressCollection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      // 모든 주소의 isDefault를 false로 설정
      final addresses = await addressCollection.get();
      for (var doc in addresses.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }

      // 선택된 주소를 기본 주소로 설정
      batch.update(addressCollection.doc(docId), {'isDefault': true});

      // 일괄 업데이트 실행
      await batch.commit();

      // Stream 업데이트를 위해 새로운 기본 주소 가져오기
      final updatedAddress = await addressCollection.doc(docId).get();
      if (updatedAddress.exists && !_addressController.isClosed) {
        final address = UserAddress.fromMap(
          updatedAddress.data()!,
          docId: updatedAddress.id,
        );
        _addressController.add(address);
      }
    } catch (e) {
      print('Error setting default address: $e');
      rethrow;
    }
  }

  // 주소 검색 (자동완성)
  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.isEmpty) return [];

    try {
      List<Location> locations = await locationFromAddress(query);
      List<Placemark> placemarks = await placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      );

      return placemarks.map((place) {
        return {
          'address': '${place.street}, ${place.locality}, ${place.country}',
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }).toList();
    } catch (e) {
      print('Address search error: $e');
      return [];
    }
  }

  Future<UserAddress?> getDefaultAddress() async {
    try {
      if (_addressController.isClosed) return null;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .where('isDefault', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final address = UserAddress.fromMap(
        doc.data(),
        docId: doc.id,
      );

      if (!_addressController.isClosed) {
        _addressController.add(address);
      }
      return address;
    } catch (e) {
      print('Error getting default address: $e');
      return null;
    }
  }

  void dispose() {
    _addressController.close();
  }
}
