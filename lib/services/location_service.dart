import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스가 활성화되어 있는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // 위치 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // 현재 위치 반환
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
}
