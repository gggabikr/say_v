// ... existing imports ...
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pages/category_stores_page.dart';
import 'models/store.dart';
import 'services/store_service.dart';
import 'services/location_service.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Say:V',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          primary: const Color(0xFF4A90E2),
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme(),
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

  Future<void> _getNearbyStores() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (position != null) {
        setState(() {
          _currentPosition = position;
        });

        // 위치 정보를 가지고 CategoryStoresPage로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryStoresPage(
              category: 'nearby',
              title: 'Nearby Stores',
              userLocation: position,
            ),
          ),
        );
      } else {
        // 위치 정보를 받아올 수 없을 때 수동 입력 다이얼로그 표시
        _showAddressInputDialog();
      }
    } catch (e) {
      print('Error getting location: $e');
      _showAddressInputDialog();
    }
  }

  void _showAddressInputDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String address = '';
        return AlertDialog(
          title: const Text('주소 입력'),
          content: TextField(
            onChanged: (value) {
              address = value;
            },
            decoration: const InputDecoration(
              hintText: '예: 1234 Robson St, Vancouver',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // 입력된 주소로 위치 설정
                final position = _locationService.setManualLocation(address);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryStoresPage(
                      category: 'nearby',
                      title: 'Nearby Stores',
                      userLocation: position,
                    ),
                  ),
                );
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Say:V'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // 검색 기능 구현
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
          // 프로모션 상세 페이지로 이동
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
    // 디버그 프린트 추가
    print('Building card for label: $label');

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
        print('Selected deals_and_discounts category'); // 디버그 프린트 추가
        break;
      case 'Special Events':
        category = 'special_events';
        break;
      default:
        print('No matching category for label: $label'); // 디버그 프린트 추가
        break;
    }

    print('Mapped category: $category'); // 디버그 프린트 추가

    return Card(
      child: InkWell(
        onTap: () {
          if (label == 'Nearby') {
            _getNearbyStores();
          } else {
            // 기존의 카테고리 네비게이션 코드
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryStoresPage(
                  category: category,
                  title: label,
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
}
