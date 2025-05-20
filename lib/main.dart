import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/user_address.dart';
import 'services/location_service.dart';
import 'services/address_service.dart';
import 'pages/category_stores_page.dart';
import 'pages/nearby_page.dart';
import 'dart:async';
import 'services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'pages/profile_page.dart';
import 'services/event_bus.dart';
import 'pages/my_stores_screen.dart';

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
  final AddressService _addressService = AddressService();
  Position? _currentPosition;
  String _currentAddress = '위치정보 없음';
  bool _isLoadingLocation = true;
  Timer? _debouncer;
  final AuthService _authService = AuthService();
  UserAddress? _defaultAddress;
  StreamSubscription<UserAddress?>? _addressSubscription;

  @override
  void initState() {
    super.initState();
    _setupAddressListener();

    _addressSubscription = _addressService.addressStream.listen((address) {
      if (mounted) {
        setState(() {
          _defaultAddress = address;
          if (address != null) {
            _currentAddress = address.fullAddress;
            if (address.nickname.isNotEmpty) {
              _currentAddress += ' (${address.nickname})';
            }
            _isLoadingLocation = false;
          }
        });
      }
    });

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    // print('API Key: $apiKey');

    // 로그인 상태 변경 감지
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        // 로그아웃 상태일 때 현재 위치 가져오기
        _getCurrentLocation();
      } else {
        // 로그인 상태일 때는 기존대로 기본 주소 확인
        _initializeAddress();
      }
    });

    // 위치 업데이트 이벤트 구독
    EventBus().onLocationUpdate.listen((event) async {
      print(
          '위치 업데이트 이벤트 수신됨: ${event.position.latitude}, ${event.position.longitude}');
      try {
        final address = await _locationService.getAddressFromCoordinates(
          event.position.latitude,
          event.position.longitude,
        );
        if (mounted) {
          setState(() {
            _currentPosition = event.position;
            _currentAddress = address;
            _isLoadingLocation = false;
          });
        }
        print('주소 업데이트 완료: $address');
      } catch (e) {
        print('주소 업데이트 실패: $e');
      }
    });
  }

  @override
  void dispose() {
    _debouncer?.cancel();
    _addressSubscription?.cancel();
    super.dispose();
  }

  void _setupAddressListener() {
    EventBus().onAddressUpdate.listen((event) {
      if (mounted) {
        setState(() {
          _currentPosition = event.position;
          _currentAddress = event.address;
          _isLoadingLocation = false;
        });
      }
    });
  }

  Future<void> _initializeAddress() async {
    setState(() => _isLoadingLocation = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final defaultAddress = await _addressService.getDefaultAddress();
        if (defaultAddress != null) {
          final position = Position(
            latitude: defaultAddress.latitude,
            longitude: defaultAddress.longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );

          // 디버그 로그 추가
          print(
              'Updating address with position: ${position.latitude}, ${position.longitude}');

          // 이벤트 발생
          EventBus().updateAddress(
              position,
              defaultAddress.fullAddress +
                  (defaultAddress.nickname.isNotEmpty
                      ? ' (${defaultAddress.nickname})'
                      : ''));

          setState(() {
            _defaultAddress = defaultAddress;
            _currentPosition = position;
            _currentAddress = defaultAddress.fullAddress;
            if (defaultAddress.nickname.isNotEmpty) {
              _currentAddress += ' (${defaultAddress.nickname})';
            }
            _isLoadingLocation = false;
          });
        }
      }

      // 기본 주소가 없거나 로그인되지 않은 경우 현재 위치 사용
      if (_currentPosition == null) {
        await _getCurrentLocation();
      }
    } catch (e) {
      print('Error initializing address: $e');
      setState(() {
        _currentAddress = '위치정보 없음';
        _isLoadingLocation = false;
      });
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

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final position = await _locationService.getCurrentLocation();
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = address;
          _defaultAddress = null;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _currentAddress = '위치정보 없음';
          _isLoadingLocation = false;
        });
      }
    }
  }

  void updateCurrentAddress(Position position) async {
    try {
      final address = await _locationService.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // 디버그 로그 추가
      print(
          'Updating address from nearby page: ${position.latitude}, ${position.longitude}');

      // 이벤트 발생 전 상태 확인
      print('Current position before event: $_currentPosition');

      // 이벤트 발생
      EventBus().updateAddress(position, address);

      print('Address update event emitted');

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = address;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('Error updating address: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }

  Widget _buildAddressSection() {
    return GestureDetector(
      onTap: () async {
        if (_currentAddress == '위치정보 없음' ||
            _currentAddress == '주소를 찾을 수 없습니다.') {
          final position = await _locationService.getCurrentLocation();
          updateCurrentAddress(position);
        }
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
      },
      child: Tooltip(
        preferBelow: true,
        verticalOffset: 20,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        textStyle: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
          height: 1.2,
        ),
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(seconds: 3),
        message: _isLoadingLocation ? '위치 확인 중...' : _currentAddress,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _defaultAddress != null ? Icons.home : Icons.location_on,
              size: 16,
              color: Colors.grey[500],
            ),
            const SizedBox(width: 4),
            Flexible(
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
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.grey[500],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Say:V'),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: _buildAddressSection(),
        ),
        leadingWidth: 150,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              // async 추가
              // 현재 위치 정보가 없다면 가져오기 시도
              Position? position = _currentPosition;
              if (position == null) {
                try {
                  position = await Geolocator.getCurrentPosition();
                  setState(() {
                    _currentPosition = position;
                  });
                } catch (e) {
                  print('Error getting current position: $e');
                }
              }

              if (!mounted) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryStoresPage(
                    category: 'all',
                    title: 'All Stores',
                    userLocation: position, // null이 아닌 실제 위치 정보 전달
                    address: _currentAddress,
                  ),
                ),
              );
            },
          ),
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // 로그인된 상태
                return PopupMenuButton(
                  icon: const Icon(Icons.person),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('프로필 설정'),
                      onTap: () {
                        Future.delayed(Duration.zero, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          );
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: const Text('내 상점'),
                      onTap: () {
                        Future.delayed(Duration.zero, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MyStoresScreen(),
                            ),
                          );
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: const Text('로그아웃'),
                      onTap: () async {
                        await AuthService().signOut();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('로그아웃되었습니다.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                );
              } else {
                // 로그인되지 않은 상태
                return IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () {
                    _showLoginDialog(context);
                  },
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 인사말 수정
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: StreamBuilder<User?>(
              // userChanges() 스트림을 사용하여 사용자 정보 변경을 감지
              stream: FirebaseAuth.instance.userChanges(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final user = snapshot.data;
                  return Text(
                    'Hello, ${user?.displayName ?? 'Guest'}!',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.right,
                  );
                }
                return Text(
                  'Hello, Guest!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildCategorySection(),
                  _buildFeaturedEvents(),
                  _buildNearbySpots(),
                ],
              ),
            ),
          ),
        ],
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
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'example@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                  ),
                  obscureText: true,
                  onFieldSubmitted: (_) async {
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
                          backgroundColor: Colors.green,
                        ),
                      );

                      // 사용자 이름이 없는 경우에만 프로필 페이지로 이동
                      if (mounted) {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user?.displayName == null ||
                            user!.displayName!.isEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfilePage(),
                            ),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('로그인 실패: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // 현재 다이얼로그 닫기
                        _showPasswordResetDialog(context); // 비밀번호 재설정 다이얼로그 표시
                      },
                      child: const Text(
                        '비밀번호 찾기',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // 현재 다이얼로그 닫기
                        _showSignUpDialog(context); // 회원가입 다이얼로그 표시
                      },
                      child: const Text(
                        '회원가입',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
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
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 5)),
                  );

                  // 사용자 이름이 없는 경우에만 프로필 페이지로 이동
                  if (mounted) {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user?.displayName == null ||
                        user!.displayName!.isEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('로그인 실패: $error'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5)),
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

  void _showPasswordResetDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final AuthService authService = AuthService();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('비밀번호 재설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('비밀번호 재설정 링크를 이메일로 보내드립니다.'),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  hintText: 'example@email.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
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
                String? error = await authService.sendPasswordResetEmail(
                  emailController.text,
                );

                Navigator.of(context).pop();

                if (error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('비밀번호 재설정 이메일을 발송했습니다.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('이메일 발송 실패: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('이메일 보내기'),
            ),
          ],
        );
      },
    );
  }

  void _showSignUpDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController displayNameController = TextEditingController();
    final AuthService authService = AuthService();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('회원가입'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: displayNameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    hintText: '표시될 이름을 입력하세요',
                  ),
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'example@email.com',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                  ),
                  obscureText: true,
                  onFieldSubmitted: (_) async {
                    String? error =
                        await authService.signUpWithEmailAndPassword(
                      emailController.text,
                      passwordController.text,
                      displayNameController.text,
                    );

                    Navigator.of(context).pop();

                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('회원가입 성공!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('회원가입 실패: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
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
                String? error = await authService.signUpWithEmailAndPassword(
                  emailController.text,
                  passwordController.text,
                  displayNameController.text,
                );

                Navigator.of(context).pop();

                if (error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('회원가입 성공!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('회원가입 실패: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('회원가입'),
            ),
          ],
        );
      },
    );
  }
}
