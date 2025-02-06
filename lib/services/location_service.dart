import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationService {
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  // 수동으로 위치 설정
  Position setManualLocation(String address) {
    // 여기서는 밴쿠버 다운타운의 기본 좌표를 반환
    return Position.fromMap({
      'latitude': 49.2827,
      'longitude': -123.1207,
      'accuracy': 0,
      'altitude': 0,
      'speed': 0,
      'speedAccuracy': 0,
      'heading': 0,
      'timestamp': DateTime.now().millisecondsSinceEpoch
    });
  }

  String processStreetAddress(String street) {
    // 범위 주소 처리 (일반 하이픈과 특수 하이픈 모두 처리)
    RegExp rangePattern = RegExp(r'(\d+)[-–—](\d+)');
    street = street.replaceAllMapped(rangePattern, (match) {
      return match.group(1)!; // 범위의 첫 번째 값만 사용
    });

    // 도로명 약어 변환
    final Map<String, String> abbreviations = {
      'Street': 'St',
      'Avenue': 'Ave',
      'Drive': 'Dr',
      'Boulevard': 'Blvd',
      'Road': 'Rd',
      'Lane': 'Ln',
      'Place': 'Pl',
      'Court': 'Ct',
      'Circle': 'Cir',
      'Highway': 'Hwy',
    };

    abbreviations.forEach((full, abbr) {
      street = street.replaceAll(full, abbr);
      street = street.replaceAll(full.toLowerCase(), abbr);
    });

    return street;
  }

  Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.length < 2) return [];

    // 한글 문자 제거
    query = query.replaceAll(RegExp(r'[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]'), '');
    if (query.trim().isEmpty) return [];

    try {
      print('Searching address for query: $query');
      List<Location> locations = [];

      try {
        locations = await locationFromAddress('$query Canada',
            localeIdentifier: 'en_CA');
      } catch (e) {
        print('Canada search error: $e');
        try {
          locations = await locationFromAddress('$query USA',
              localeIdentifier: 'en_US');
        } catch (e) {
          print('USA search error: $e');
        }
      }

      print('Found ${locations.length} locations');
      List<Map<String, dynamic>> results = [];

      for (var location in locations) {
        try {
          print(
              'Processing location: ${location.latitude}, ${location.longitude}');
          List<Placemark> placemarks = await placemarkFromCoordinates(
              location.latitude, location.longitude,
              localeIdentifier: 'en_CA');
          print('Found ${placemarks.length} placemarks');

          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            String address = '';

            try {
              if (place.street != null && place.street!.isNotEmpty) {
                address = place.street!;
              }

              if (place.locality != null && place.locality!.isNotEmpty) {
                address +=
                    address.isEmpty ? place.locality! : ', ${place.locality}';
              }

              if (place.administrativeArea != null &&
                  place.administrativeArea!.isNotEmpty) {
                address += ', ${place.administrativeArea}';
              }

              if (address.isNotEmpty) {
                results.add({
                  'address': address.trim(),
                  'latitude': location.latitude,
                  'longitude': location.longitude,
                });
              }
            } catch (e) {
              print('Address formatting error: $e');
              continue;
            }
          }
        } catch (e) {
          print('Placemark error: $e');
          continue;
        }
      }

      return results;
    } catch (e) {
      print('Address search error: $e');
      return [];
    }
  }

  Future<String> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      print('주소 검색 시작: $latitude, $longitude');

      // geocoding 패키지 사용
      final placemarks = await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        print('Geocoding 결과: $place');

        // 주소 구성
        final List<String> addressParts = [];

        if (place.street?.isNotEmpty ?? false) addressParts.add(place.street!);
        if (place.locality?.isNotEmpty ?? false)
          addressParts.add(place.locality!);
        if (place.subLocality?.isNotEmpty ?? false)
          addressParts.add(place.subLocality!);

        if (addressParts.isNotEmpty) {
          return addressParts.join(', ');
        }
      }

      print('주소를 찾을 수 없음');
      return '주소를 찾을 수 없습니다';
    } catch (e) {
      print('주소 검색 에러: $e');
      return '주소를 찾을 수 없습니다';
    }
  }
}
