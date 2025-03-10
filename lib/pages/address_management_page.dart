import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_address.dart';
import '../services/address_service.dart';
import '../services/location_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AddressManagementPage extends StatefulWidget {
  const AddressManagementPage({super.key});

  @override
  State<AddressManagementPage> createState() => _AddressManagementPageState();
}

class _AddressManagementPageState extends State<AddressManagementPage> {
  final AddressService _addressService = AddressService();
  final LocationService _locationService = LocationService();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _unitNumberController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  Timer? _debounce;
  List<dynamic> predictions = [];
  String? selectedPlaceId;
  bool isSearching = false;
  List<UserAddress> _addresses = [];
  bool _isLoading = true;
  StreamSubscription<UserAddress?>? _addressSubscription;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
    // Stream 구독 추가 및 mounted 체크
    _addressSubscription = _addressService.addressStream.listen((_) {
      if (mounted) {
        _loadAddresses();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _addressController.dispose();
    _nicknameController.dispose();
    _unitNumberController.dispose();
    _notesController.dispose();
    _addressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final addresses = await _addressService.getAddresses();
      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading addresses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _processStreetAddress(String street) {
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

  Future<void> _searchAddress(String query) async {
    if (query.length < 2) return;

    final results = await _locationService.searchAddress(query);
    setState(() {
      predictions = results;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        setState(() {
          predictions = [];
        });
      } catch (e) {
        print('UI Update error: $e');
      }
    });
  }

  void _clearControllers() {
    _addressController.clear();
    _nicknameController.clear();
    _unitNumberController.clear();
    _notesController.clear();
    selectedPlaceId = null;
    predictions = [];
  }

  Future<void> searchPlaces(String input) async {
    if (input.length > 2) {
      setState(() => isSearching = true);
      try {
        final url = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=$input'
            '&components=country:ca'
            '&key=${dotenv.env['GOOGLE_MAPS_API_KEY']}');

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          setState(() {
            predictions = json['predictions'].map((prediction) {
              String description = prediction['description'];
              description = description.replaceAll(', Canada', '');
              description = description.replaceAll('British Columbia', 'BC');
              description = description.replaceAll('Alberta', 'AB');
              description = description.replaceAll('Ontario', 'ON');
              description = description.replaceAll('Quebec', 'QC');
              return {
                'description': description,
                'place_id': prediction['place_id'],
              };
            }).toList();
          });
        }
      } catch (e) {
        print('Error fetching address predictions: $e');
      } finally {
        setState(() => isSearching = false);
      }
    } else {
      setState(() => predictions = []);
    }
  }

  void _showAddAddressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('새 주소 추가'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                        _clearControllers();
                      },
                    ),
                  ],
                ),
                body: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: '주소 검색',
                          hintText: '주소를 입력하세요',
                        ),
                        onChanged: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 500),
                              () async {
                            if (value.length > 2) {
                              try {
                                final url = Uri.parse(
                                    'https://maps.googleapis.com/maps/api/place/autocomplete/json'
                                    '?input=$value'
                                    '&components=country:ca'
                                    '&key=${dotenv.env['GOOGLE_MAPS_API_KEY']}');

                                final response = await http.get(url);
                                print('API Response: ${response.body}'); // 디버그용
                                if (response.statusCode == 200) {
                                  final json = jsonDecode(response.body);
                                  setDialogState(() {
                                    predictions =
                                        json['predictions'].map((prediction) {
                                      String description =
                                          prediction['description'];
                                      description = description.replaceAll(
                                          ', Canada', '');
                                      description = description.replaceAll(
                                          'British Columbia', 'BC');
                                      description = description.replaceAll(
                                          'Alberta', 'AB');
                                      description = description.replaceAll(
                                          'Ontario', 'ON');
                                      description = description.replaceAll(
                                          'Quebec', 'QC');
                                      return {
                                        'description': description,
                                        'place_id': prediction['place_id'],
                                      };
                                    }).toList();
                                    print(
                                        'Predictions updated: ${predictions.length}'); // 디버그용
                                  });
                                }
                              } catch (e) {
                                print('Error fetching address predictions: $e');
                              }
                            } else {
                              setDialogState(() {
                                predictions = [];
                              });
                            }
                          });
                        },
                      ),
                      if (predictions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: predictions.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(predictions[index]['description']),
                                onTap: () {
                                  setDialogState(() {
                                    _addressController.text =
                                        predictions[index]['description'];
                                    selectedPlaceId =
                                        predictions[index]['place_id'];
                                    predictions = [];
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: '별칭 (선택사항)',
                          hintText: '예: 집, 회사',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _unitNumberController,
                        decoration: const InputDecoration(
                          labelText: '상세주소 (선택사항)',
                          hintText: '아파트/건물 호수',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: '메모 (선택사항)',
                          hintText: '배송 시 참고사항',
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          if (_addressController.text.isNotEmpty &&
                              selectedPlaceId != null) {
                            try {
                              print(
                                  'Getting place details for ID: $selectedPlaceId'); // 디버그 로그
                              final detailsUrl = Uri.parse(
                                  'https://maps.googleapis.com/maps/api/place/details/json'
                                  '?place_id=$selectedPlaceId'
                                  '&key=${dotenv.env['GOOGLE_MAPS_API_KEY']}');

                              final response = await http.get(detailsUrl);
                              print(
                                  'Place details response: ${response.statusCode}'); // 디버그 로그

                              if (response.statusCode == 200) {
                                final json = jsonDecode(response.body);
                                if (json['result'] != null &&
                                    json['result']['geometry'] != null) {
                                  final location =
                                      json['result']['geometry']['location'];
                                  print(
                                      'Location found: ${location['lat']}, ${location['lng']}'); // 디버그 로그

                                  final newAddress = UserAddress(
                                    docId: DateTime.now()
                                        .millisecondsSinceEpoch
                                        .toString(),
                                    fullAddress: _addressController.text,
                                    nickname: _nicknameController.text,
                                    unitNumber: _unitNumberController.text,
                                    notes: _notesController.text,
                                    latitude: location['lat'],
                                    longitude: location['lng'],
                                    isDefault: false,
                                    lastUsed: DateTime.now(),
                                  );

                                  await _addressService.addAddress(newAddress);
                                  print('Address added to service'); // 디버그 로그

                                  if (mounted) {
                                    Navigator.pop(context);
                                    setState(() {}); // 목록 새로고침
                                    _clearControllers();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('주소가 추가되었습니다')),
                                    );
                                  }
                                }
                              }
                            } catch (e) {
                              print('Error adding new address: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('주소 추가 중 오류가 발생했습니다: $e')),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('주소를 선택해주세요')),
                            );
                          }
                        },
                        child: const Text('추가'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteAddress(UserAddress address) async {
    // 삭제 확인 다이얼로그
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주소 삭제'),
        content: const Text('이 주소를 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _addressService.deleteAddress(address.docId);
        setState(() {}); // 목록 새로고침
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('주소가 삭제되었습니다')),
          );
        }
      } catch (e) {
        print('Error deleting address: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('주소 삭제 중 오류가 발생했습니다')),
          );
        }
      }
    }
  }

  void _editAddress(UserAddress address) {
    _addressController.text = address.fullAddress;
    _nicknameController.text = address.nickname;
    _unitNumberController.text = address.unitNumber;
    _notesController.text = address.notes;
    selectedPlaceId = null; // 새로운 장소 ID는 필요한 경우에만 업데이트

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('주소 수정'),
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.pop(context);
                        _clearControllers();
                      },
                    ),
                  ],
                ),
                body: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      TextField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: '별칭 (선택사항)',
                          hintText: '예: 집, 회사',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _unitNumberController,
                        decoration: const InputDecoration(
                          labelText: '상세주소 (선택사항)',
                          hintText: '아파트/건물 호수',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: '메모 (선택사항)',
                          hintText: '배송 시 참고사항',
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            final updatedAddress = UserAddress(
                              docId: address.docId,
                              fullAddress: _addressController.text,
                              nickname: _nicknameController.text,
                              unitNumber: _unitNumberController.text,
                              notes: _notesController.text,
                              latitude: address.latitude,
                              longitude: address.longitude,
                              isDefault: address.isDefault,
                              lastUsed: DateTime.now(),
                            );

                            await _addressService.updateAddress(updatedAddress);
                            if (mounted) {
                              Navigator.pop(context);
                              setState(() {}); // 목록 새로고침
                              _clearControllers();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('주소가 수정되었습니다')),
                              );
                            }
                          } catch (e) {
                            print('Error updating address: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('주소 수정 중 오류가 발생했습니다')),
                              );
                            }
                          }
                        },
                        child: const Text('수정'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> setDefaultAddress(String docId) async {
    try {
      await _addressService.setDefaultAddress(docId);
      if (mounted) {
        await _loadAddresses();
      }
    } catch (e) {
      print('Error setting default address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기본 주소 설정 중 오류가 발생했습니다.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 관리'),
      ),
      body: FutureBuilder<List<UserAddress>>(
        future: _addressService.getAddresses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final addresses = snapshot.data ?? [];
          if (addresses.isEmpty) {
            return const Center(child: Text('저장된 주소가 없습니다'));
          }

          return ListView.builder(
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final address = addresses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (address.nickname.isNotEmpty)
                                  Text(
                                    address.nickname,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          // 디폴트 주소 토글 버튼
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                await setDefaultAddress(address.docId);
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('기본 주소 설정 중 오류가 발생했습니다'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              address.isDefault
                                  ? Icons.star
                                  : Icons.star_border,
                              color: address.isDefault
                                  ? Colors.amber
                                  : Colors.grey,
                            ),
                            label: Text(
                              address.isDefault ? '기본 주소' : '기본 주소로 설정',
                              style: TextStyle(
                                color: address.isDefault
                                    ? Colors.amber
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address.fullAddress,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (address.unitNumber.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '동/호수: ${address.unitNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      if (address.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '메모: ${address.notes}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // 삭제 기능
                              _deleteAddress(address);
                            },
                            child: const Text('삭제'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              // 수정 기능
                              _editAddress(address);
                            },
                            child: const Text('수정'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAddressDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
