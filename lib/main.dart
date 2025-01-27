import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/store.dart';
import 'services/store_service.dart';
import 'services/location_service.dart';
import 'pages/category_stores_page.dart';
import 'pages/nearby_page.dart';
import 'dart:async';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/data/.env');

  // Firebase 초기화 시도
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase 초기화 성공');
  } catch (e) {
    print('Firebase 초기화 오류: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Say:V',
      theme: ThemeData(
        primaryColor: const Color(0xFF4A90E2),
        textTheme: GoogleFonts.notoSansTextTheme(),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF4A90E2),
          error: Colors.red,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  String _currentAddress = '위치정보 없음';
  bool _isLoadingLocation = true;
  Timer? _debouncer;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    print('API Key: $apiKey');
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

  Future<void> _getCurrentLocation() async {
    try {
      // 위치 권한 확인
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _currentAddress = '위치정보 없음';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _currentAddress = '위치정보 없음';
        });
        return;
      }

      // 현재 위치 가져오기
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });

      // 위치를 주소로 변환
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          if (place.street != null && place.street!.isNotEmpty) {
            String processedStreet = _processStreetAddress(place.street!);
            String city = place.locality ?? '';

            // 정확한 주소인 경우 (번지수가 있는 경우)
            bool isExactAddress = RegExp(r'^\d+').hasMatch(processedStreet);

            if (city.isNotEmpty) {
              _currentAddress = '$processedStreet, $city';
            } else {
              _currentAddress = processedStreet;
            }

            // 정확한 주소가 아닌 경우에만 '부근' 추가
            if (!isExactAddress) {
              _currentAddress += ' 부근';
            }
          } else if (place.subLocality != null &&
              place.subLocality!.isNotEmpty) {
            _currentAddress = '${place.subLocality} 부근';
          } else {
            _currentAddress = '${place.locality ?? ''} 부근';
          }
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() {
        _currentAddress = '위치정보 없음';
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 150,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Center(
            child: Text(
              _isLoadingLocation ? '위치 확인 중...' : _currentAddress,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                height: 1.2,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.left,
            ),
          ),
        ),
        title: const Text('Say:V'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CategoryStoresPage(
                    category: 'all',
                    title: '전체 매장',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              _showLoginDialog(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCategorySection(),
            _buildFeaturedEvents(),
            _buildNearbySpots(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildCategoryCard(Icons.local_bar, 'Happy Hour'),
          _buildCategoryCard(Icons.restaurant, 'All You Can Eat'),
          _buildCategoryCard(Icons.local_offer, 'Deals & Discounts'),
          _buildCategoryCard(Icons.event, 'Special Events'),
          _buildCategoryCard(Icons.location_on, 'Nearby'),
          _buildPromotionCard(
            'https://picsum.photos/200/200?random=1',
            '프로모션 1',
          ),
          _buildPromotionCard(
            'https://picsum.photos/200/200?random=2',
            '프로모션 2',
          ),
          _buildPromotionCard(
            'https://picsum.photos/200/200?random=3',
            '프로모션 3',
          ),
          _buildCategoryCard(Icons.more_horiz, '더보기'),
        ],
      ),
    );
  }

  Widget _buildPromotionCard(String imageUrl, String label) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // 프로모션 세 페이지로 이동
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(IconData icon, String label) {
    String category = '';
    switch (label) {
      case 'Happy Hour':
        category = 'happy_hour';
        break;
      case 'All You Can Eat':
        category = 'all_you_can_eat';
        break;
      case 'Deals & Discounts':
        category = 'deals_and_discounts';
        break;
      case 'Special Events':
        category = 'special_events';
        break;
      default:
        break;
    }

    return Card(
      child: InkWell(
        onTap: () {
          if (label == 'Nearby') {
            showDialog(
              context: context,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: const NearbyPage(),
                  ),
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryStoresPage(
                  category: category,
                  title: label,
                  userLocation: _currentPosition,
                ),
              ),
            );
          }
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedEvents() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '추천 이벤트',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              return Container(
                width: 300,
                margin: const EdgeInsets.all(8),
                child: Card(
                  child: Center(child: Text('이벤트 ${index + 1}')),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNearbySpots() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '근처 상점',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (context, index) {
            return ListTile(
              leading: const Icon(Icons.store),
              title: Text('상점 ${index + 1}'),
              subtitle: const Text('위치 정보'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // 상점 상세 페이지로 이동
              },
            );
          },
        ),
      ],
    );
  }

  void _showLoginDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final AuthService authService = AuthService();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그인'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'example@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                  ),
                  obscureText: true,
                  onSubmitted: (_) async {
                    String? error =
                        await authService.signInWithEmailAndPassword(
                      emailController.text,
                      passwordController.text,
                    );

                    Navigator.of(context).pop();

                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('로그인 성공!'),
                          duration: Duration(seconds: 5),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('로그인 실패: $error'),
                          duration: const Duration(seconds: 5),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // Forgot password 기능은 나중에 구현
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                String? error = await authService.signInWithEmailAndPassword(
                  emailController.text,
                  passwordController.text,
                );

                Navigator.of(context).pop();

                if (error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('로그인 성공!'),
                      duration: Duration(seconds: 5),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('로그인 실패: $error'),
                      duration: const Duration(seconds: 5),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('로그인'),
            ),
          ],
        );
      },
    );
  }
}
