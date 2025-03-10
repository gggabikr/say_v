import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_address.dart';
import '../services/address_service.dart';
import 'category_stores_page.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/event_bus.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({Key? key}) : super(key: key);

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  final TextEditingController _addressController = TextEditingController();
  final AddressService _addressService = AddressService();
  Timer? _debouncer;
  List<dynamic> predictions = [];
  bool isUsingCurrentLocation = false;
  Position? currentPosition;
  bool isLoadingLocation = false;
  bool isSearching = false;
  String? selectedPlaceId;
  UserAddress? defaultAddress;

  @override
  void initState() {
    super.initState();
    _loadInitialAddress();
  }

  Future<void> _loadInitialAddress() async {
    try {
      final address = await _addressService.getDefaultAddress();
      if (mounted) {
        setState(() {
          defaultAddress = address;
          if (address != null) {
            isUsingCurrentLocation = false;
            _addressController.text = address.fullAddress;
            if (address.nickname.isNotEmpty) {
              _addressController.text += ' (${address.nickname})';
            }
            // 기본 주소의 위치로 검색 실행
            _searchWithPosition(Position(
              latitude: address.latitude,
              longitude: address.longitude,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ));
          } else {
            // 기본 주소가 없으면 현재 위치 사용
            isUsingCurrentLocation = true;
            _getCurrentLocation();
          }
        });
      }
    } catch (e) {
      print('Error loading default address: $e');
      // 에러 발생 시 현재 위치 사용
      if (mounted) {
        setState(() {
          isUsingCurrentLocation = true;
        });
        _getCurrentLocation();
      }
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('위치 서비스가 비활성화되어 있습니다. 설정에서 위치 서비스를 켜주세요.'),
      ));
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('위치 권한이 거부되었습니다.'),
        ));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('위치 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.'),
      ));
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    print('위치 가져오기 시작');
    setState(() {
      isLoadingLocation = true;
    });

    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        setState(() {
          isUsingCurrentLocation = false;
        });
        return;
      }

      print('GPS 위치 가져오기 시도');
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      print('가져온 위치: ${position.latitude}, ${position.longitude}');

      // 위치 업데이트 이벤트 발생 시 로그 추가
      print('위치 업데이트 이벤트 발생');
      EventBus().updateLocation(position);

      setState(() {
        currentPosition = position;
        if (isUsingCurrentLocation) {
          _addressController.text = '현재 위치 사용 중';
        }
      });

      print('주변 가게 검색 시작');
      print('위치로 검색: ${position.latitude}, ${position.longitude}');

      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CategoryStoresPage(
            category: 'nearby',
            title: '주변 맛집',
            userLocation: position,
          ),
        ),
      );
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치를 가져오는데 실패했습니다: ${e.toString()}')),
        );
      }
      setState(() {
        isUsingCurrentLocation = false;
      });
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _getLocationFromAddress() async {
    print('주소의 좌표 검색 시작: ${_addressController.text}');
    setState(() {
      isLoadingLocation = true;
    });

    try {
      // 기본 주소인 경우
      if (defaultAddress != null &&
          _addressController.text.startsWith(defaultAddress!.fullAddress)) {
        print('Using default address coordinates');
        final position = Position(
          latitude: defaultAddress!.latitude,
          longitude: defaultAddress!.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
        _searchWithPosition(position);
        return;
      }

      // 검색한 주소인 경우
      if (selectedPlaceId != null) {
        print('Using placeId: $selectedPlaceId');
        final detailsUrl =
            Uri.parse('https://maps.googleapis.com/maps/api/place/details/json'
                '?place_id=$selectedPlaceId'
                '&key=${dotenv.env['GOOGLE_MAPS_API_KEY']}');

        final response = await http.get(detailsUrl);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          if (json['result'] != null && json['result']['geometry'] != null) {
            final location = json['result']['geometry']['location'];
            print('주소의 좌표값: 위도 ${location['lat']}, 경도 ${location['lng']}');

            final position = Position.fromMap({
              'latitude': location['lat'],
              'longitude': location['lng'],
              'accuracy': 0,
              'altitude': 0,
              'speed': 0,
              'speedAccuracy': 0,
              'heading': 0,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });

            _searchWithPosition(position);
          }
        }
      } else {
        print('No placeId found for the address');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주소를 다시 선택해주세요.')),
        );
      }
    } catch (e) {
      print('Error getting location from address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주소를 찾을 수 없습니다.')),
      );
    } finally {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  Future<void> _searchWithDefaultAddress() async {
    if (defaultAddress != null) {
      final position = Position(
        latitude: defaultAddress!.latitude,
        longitude: defaultAddress!.longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
      _searchWithPosition(position);
    }
  }

  void _searchWithPosition(Position position) {
    print('주변 가게 검색 시작');
    print('위치로 검색: ${position.latitude}, ${position.longitude}');

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryStoresPage(
          category: 'nearby',
          title: '주변 맛집',
          userLocation: position,
        ),
      ),
    );
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
            SwitchListTile(
              title: const Text('현재 위치 사용'),
              subtitle: Text(isUsingCurrentLocation
                  ? '디바이스의 GPS 위치를 사용합니다'
                  : defaultAddress != null
                      ? '기본 주소를 사용합니다'
                      : '주소를 직접 입력해주세요'),
              value: isUsingCurrentLocation,
              onChanged: (bool value) {
                setState(() {
                  isUsingCurrentLocation = value;
                  if (value) {
                    _getCurrentLocation();
                  } else {
                    if (defaultAddress != null) {
                      _addressController.text = defaultAddress!.fullAddress;
                      if (defaultAddress!.nickname.isNotEmpty) {
                        _addressController.text +=
                            ' (${defaultAddress!.nickname})';
                      }
                    } else {
                      _addressController.clear();
                    }
                    predictions = [];
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                TextField(
                  controller: _addressController,
                  enabled: !isUsingCurrentLocation,
                  decoration: InputDecoration(
                    labelText: isUsingCurrentLocation
                        ? '현재 위치 사용 중'
                        : defaultAddress != null
                            ? '기본 주소'
                            : '주소 입력',
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
                            onPressed: () {
                              if (isUsingCurrentLocation) {
                                _getCurrentLocation();
                              } else if (defaultAddress != null) {
                                _searchWithDefaultAddress();
                              } else {
                                _getLocationFromAddress();
                              }
                            },
                          ),
                  ),
                  onChanged: (value) {
                    if (!isUsingCurrentLocation) {
                      if (_debouncer?.isActive ?? false) _debouncer!.cancel();
                      _debouncer =
                          Timer(const Duration(milliseconds: 500), () async {
                        if (value.length > 2) {
                          setState(() => isSearching = true);
                          try {
                            final url = Uri.parse(
                                'https://maps.googleapis.com/maps/api/place/autocomplete/json'
                                '?input=$value'
                                '&components=country:ca'
                                '&key=${dotenv.env['GOOGLE_MAPS_API_KEY']}');

                            final response = await http.get(url);
                            if (response.statusCode == 200) {
                              final json = jsonDecode(response.body);
                              if (!mounted) return;
                              setState(() {
                                predictions =
                                    json['predictions'].map((prediction) {
                                  String description =
                                      prediction['description'];
                                  description =
                                      description.replaceAll(', Canada', '');
                                  description = description.replaceAll(
                                      'British Columbia', 'BC');
                                  description =
                                      description.replaceAll('Alberta', 'AB');
                                  description =
                                      description.replaceAll('Ontario', 'ON');
                                  description =
                                      description.replaceAll('Quebec', 'QC');
                                  return {
                                    'description': description,
                                    'place_id': prediction['place_id'],
                                  };
                                }).toList();
                                print(
                                    'Updated predictions: ${predictions.length} items');
                              });
                            }
                          } catch (e) {
                            print('Error fetching address predictions: $e');
                          } finally {
                            if (!mounted) return;
                            setState(() => isSearching = false);
                          }
                        } else {
                          setState(() => predictions = []);
                        }
                      });
                    }
                  },
                ),
                if (!isUsingCurrentLocation && predictions.isNotEmpty)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: predictions.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(predictions[index]['description']),
                          onTap: () {
                            final selectedAddress =
                                predictions[index]['description'];
                            final placeId = predictions[index]['place_id'];
                            print(
                                'Selected address: $selectedAddress with placeId: $placeId');

                            setState(() {
                              _addressController.text = selectedAddress;
                              selectedPlaceId = placeId;
                              predictions = [];
                            });
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                print("검색 버튼 클릭");
                if (isUsingCurrentLocation) {
                  _getCurrentLocation();
                } else {
                  _getLocationFromAddress();
                }
              },
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
    _debouncer?.cancel();
    super.dispose();
  }
}
