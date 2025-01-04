import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import 'category_stores_page.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({Key? key}) : super(key: key);

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  final TextEditingController _addressController = TextEditingController();
  bool isUsingCurrentLocation = false; // 현재 위치 사용 여부
  Position? currentPosition; // 현재 GPS 위치
  bool isLoadingLocation = false; // 위치 로딩 상태

  // 위치 권한 요청 및 확인을 위한 메서드 추가
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 위치 서비스가 활성화되어 있는지 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 켜주세요.'),
      ));
      return false;
    }

    // 위치 권한 상태 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 권한이 거부된 상태라면 권한 요청
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('위치 권한이 거부되었습니다.'),
        ));
        return false;
      }
    }

    // 권한이 영구적으로 거부된 경우
    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.'),
      ));
      return false;
    }

    return true;
  }

  // 현재 위치 가져오기 메서드 수정
  Future<void> _getCurrentLocation() async {
    print('위치 가져오기 시작');
    setState(() {
      isLoadingLocation = true;
    });

    try {
      // 위치 권한 확인 및 요청
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        setState(() {
          isUsingCurrentLocation = false;
        });
        return;
      }

      // 현재 위치 가져오기
      print('GPS 위치 가져오기 시도');
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('가져온 위치: ${position.latitude}, ${position.longitude}');

      setState(() {
        currentPosition = position;
        if (isUsingCurrentLocation) {
          _addressController.text = '현재 위치 사용 중';
        }
      });

      // 위치 기반으로 주변 가게 검색
      if (isUsingCurrentLocation) {
        _searchNearbyStores();
      }
    } catch (e) {
      print('위치 가져오기 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('위치를 가져오는데 실패했습니다: ${e.toString()}')),
      );
      setState(() {
        isUsingCurrentLocation = false;
      });
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  void _searchNearbyStores() {
    print('주변 가게 검색 시작'); // 디버그 프린트
    if (isUsingCurrentLocation && currentPosition != null) {
      print(
          '현재 위치로 검색: ${currentPosition!.latitude}, ${currentPosition!.longitude}'); // 디버그 프린트
      // 현재 위치로 검색
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryStoresPage(
            category: 'nearby',
            title: '내 주변 맛집',
            userLocation: currentPosition,
          ),
        ),
      );
    } else if (_addressController.text.isNotEmpty) {
      print('주소로 검색: ${_addressController.text}'); // 디버그 프린트
      // 주소로 검색 (기존 기능)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryStoresPage(
            category: 'nearby',
            title: '주변 맛집',
            address: _addressController.text,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 현재 위치 사용 토글
            SwitchListTile(
              title: const Text('현재 위치 사용'),
              subtitle: Text(isUsingCurrentLocation
                  ? '디바이스의 GPS 위치를 사용합니다'
                  : '주소를 직접 입력해주세요'),
              value: isUsingCurrentLocation,
              onChanged: (bool value) {
                setState(() {
                  isUsingCurrentLocation = value;
                  if (value) {
                    _getCurrentLocation();
                  } else {
                    _addressController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            // 주소 입력 필드
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: isUsingCurrentLocation ? '현재 위치 사용 중' : '주소 입력',
                border: const OutlineInputBorder(),
                suffixIcon: isLoadingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchNearbyStores,
                      ),
              ),
              enabled: !isUsingCurrentLocation, // 현재 위치 사용 시 비활성화
              onSubmitted: (_) => _searchNearbyStores(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchNearbyStores,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: Text(
                isUsingCurrentLocation ? '현재 위치로 검색' : '주소로 검색',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }
}
