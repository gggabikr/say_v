import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:say_v/widgets/scroll_to_top.dart';
import '../models/store.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:io' show Platform;
import 'package:say_v/widgets/review_section.dart';

class StoreDetailPage extends StatefulWidget {
  final Store store;
  final String currentUserId;

  const StoreDetailPage(
      {Key? key, required this.store, required this.currentUserId})
      : super(key: key);

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  String _selectedCategory = 'food';
  final List<String> _categories = [
    'food',
    'alcohol',
    'drink',
    'Cate 1',
    'Cate 2',
    'Cate 3'
  ];
  final ScrollController _scrollController = ScrollController();
  String? _address;
  bool _isLoadingAddress = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory =
        widget.store.menus.isNotEmpty ? widget.store.menus.first.type : 'food';
    _loadAddress();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAddress() async {
    try {
      final placemarks = await placemarkFromCoordinates(
        widget.store.latitude,
        widget.store.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        setState(() {
          _address = _formatAddress(placemark);
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _address = '주소를 불러올 수 없습니다';
        _isLoadingAddress = false;
      });
    }
  }

  String _formatAddress(Placemark placemark) {
    final components = <String>[];

    // Street number and name
    if (placemark.street?.isNotEmpty ?? false) {
      components.add(placemark.street!);
    }

    // City
    if (placemark.locality?.isNotEmpty ?? false) {
      components.add(placemark.locality!);
    }

    // Province/State
    if (placemark.administrativeArea?.isNotEmpty ?? false) {
      components.add(placemark.administrativeArea!);
    }

    // Postal code
    if (placemark.postalCode?.isNotEmpty ?? false) {
      components.add(placemark.postalCode!);
    }

    return components.join(', ');
  }

  Future<void> _openMapsNavigation() async {
    final lat = widget.store.latitude;
    final lng = widget.store.longitude;

    try {
      // 구글맵 앱으로 연결 시도
      if (Platform.isIOS) {
        final googleMapsUrl = 'comgooglemaps://?q=$lat,$lng';
        if (await canLaunchUrlString(googleMapsUrl)) {
          await launchUrlString(googleMapsUrl);
          return;
        }
      } else {
        final googleMapsUrl = 'geo:$lat,$lng?q=$lat,$lng';
        if (await canLaunchUrlString(googleMapsUrl)) {
          await launchUrlString(googleMapsUrl);
          return;
        }
      }

      // 구글맵 앱으로 연결 실패시 웹으로 열기
      final webUrl = 'https://www.google.com/maps?q=$lat,$lng';
      if (await canLaunchUrlString(webUrl)) {
        await launchUrlString(
          webUrl,
          mode: LaunchMode.externalApplication,
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('지도를 열 수 없습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error launching maps: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('지도를 열 수 없습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openPhoneApp() async {
    final phoneNumber =
        widget.store.contactNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (phoneNumber.isEmpty) return;

    try {
      final urlString = Platform.isIOS
          ? 'telprompt://$phoneNumber' // iOS는 telprompt:// 사용
          : 'tel:$phoneNumber'; // Android는 tel: 사용

      print('Attempting to launch phone URL: $urlString'); // 디버그 로그

      if (await canLaunchUrlString(urlString)) {
        await launchUrlString(
          urlString,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // 첫 번째 방법 실패시 다른 방법 시도
        final backupUrl = 'tel://$phoneNumber';
        if (await canLaunchUrlString(backupUrl)) {
          await launchUrlString(
            backupUrl,
            mode: LaunchMode.externalApplication,
          );
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('전화 앱을 열 수 없습니다.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error launching phone app: $e');
      // 에러 발생시 클립보드에 복사
      if (context.mounted) {
        await Clipboard.setData(ClipboardData(text: phoneNumber));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전화번호가 클립보드에 복사되었습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showCopyDialog(String text, String label) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text('$label을(를) 복사하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$label이(가) 클립보드에 복사되었습니다.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: const Text('복사'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.store.name),
              background: _buildImageGallery(),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildImageGallery(),
                const Divider(height: 32, thickness: 0.5, color: Colors.grey),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '기본 정보',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        children: [
                          GestureDetector(
                            onLongPress: _address != null
                                ? () => _showCopyDialog(_address!, '주소')
                                : null,
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              leading: const Icon(Icons.location_on),
                              title: _isLoadingAddress
                                  ? const Text('주소 불러오는 중...')
                                  : Text(
                                      _address ?? '주소를 불러올 수 없습니다',
                                      style: const TextStyle(height: 1.3),
                                    ),
                              minVerticalPadding: 0,
                              visualDensity: VisualDensity.compact,
                              onTap:
                                  _address != null ? _openMapsNavigation : null,
                              trailing: _address != null
                                  ? const Icon(Icons.navigation,
                                      size: 20, color: Colors.blue)
                                  : null,
                            ),
                          ),
                          SizedBox(
                            height: 40,
                            child: _buildCurrentStatus(),
                          ),
                          SizedBox(
                            height: 40,
                            child: GestureDetector(
                              onLongPress: widget.store.contactNumber.isNotEmpty
                                  ? () => _showCopyDialog(
                                      widget.store.contactNumber
                                          .replaceAllMapped(
                                        RegExp(r'(\d{3})(\d{3})(\d{4})'),
                                        (Match m) => '${m[1]}-${m[2]}-${m[3]}',
                                      ),
                                      '전화번호')
                                  : null,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                leading: const Icon(Icons.phone),
                                title: Text(widget.store.contactNumber
                                        .replaceAllMapped(
                                            RegExp(r'(\d{3})(\d{3})(\d{4})'),
                                            (Match m) =>
                                                '${m[1]}-${m[2]}-${m[3]}') ??
                                    '전화번호 없음'),
                                minVerticalPadding: 0,
                                visualDensity: VisualDensity.compact,
                                onTap: widget.store.contactNumber.isNotEmpty
                                    ? _openPhoneApp
                                    : null,
                                trailing: widget.store.contactNumber.isNotEmpty
                                    ? const Icon(Icons.phone_enabled,
                                        size: 20, color: Colors.blue)
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                          height: 32, thickness: 0.5, color: Colors.grey),
                      Row(
                        children: [
                          const Expanded(
                            flex: 2,
                            child: Text(
                              '영업 시간',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (widget.store.happyHours?.isNotEmpty ?? false)
                            const Expanded(
                              flex: 2,
                              child: Text(
                                '해피 아워',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildBusinessAndHappyHours(),
                      const Divider(
                        height: 32,
                        thickness: 0.5,
                        color: Colors.grey,
                      ),
                      const Text(
                        '메뉴',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: Text(_categories[index]),
                                selected:
                                    _selectedCategory == _categories[index],
                                onSelected: (bool selected) {
                                  setState(() {
                                    _selectedCategory = _categories[index];
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildMenuList(),
                    ],
                  ),
                ),
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    '리뷰',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ReviewSection(
                  store: widget.store,
                  currentUserId: widget.currentUserId,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ScrollToTop(
        scrollController: _scrollController,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildImageGallery() {
    final screenWidth = MediaQuery.of(context).size.width;
    final imageWidth = screenWidth * 0.8;
    final imageHeight = imageWidth * 0.7;

    // 테스트용 더미 이미지 URL들
    final List<String> dummyImages = [
      'https://picsum.photos/800/600?random=1',
      'https://picsum.photos/800/600?random=2',
      'https://picsum.photos/800/600?random=3',
      'https://picsum.photos/800/600?random=4',
      'https://picsum.photos/800/600?random=5',
    ];

    // 실제 이미지가 있으면 그것을 사용하고, 없으면 더미 이미지 사용
    final images = widget.store.images?.isNotEmpty == true
        ? widget.store.images!
        : dummyImages;

    if (images.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: imageHeight,
      child: Stack(
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length > 3 ? 4 : images.length,
            itemBuilder: (context, index) {
              // 3개 이상일 때 마지막 아이템을 "더보기" 버튼으로 대체
              if (index == 3 && images.length > 3) {
                return GestureDetector(
                  onTap: () {
                    // 전체 이미지 갤러리 페이지로 이동
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GalleryViewPage(
                          images: images,
                          initialIndex: 3,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: imageWidth,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 16 : 8,
                      right: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.collections,
                            color: Colors.white,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '+ ${images.length - 3}장 더보기',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GalleryViewPage(
                        images: images,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: imageWidth,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 16 : 8,
                    right: index == images.length - 1 ? 16 : 8,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: images[index],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${images.length}장의 사진',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatus() {
    if (widget.store.is24Hours) {
      return const ListTile(
        leading: Icon(Icons.access_time, color: Colors.green),
        title: Text(
          '24시간 영업',
          style: TextStyle(color: Colors.green),
        ),
      );
    }

    final now = DateTime.now();
    final isOpen = widget.store.isCurrentlyOpen();

    // 현재 영업 중인 경우
    if (isOpen) {
      final todayHours = widget.store.businessHours?.firstWhere(
        (hours) => hours.daysOfWeek.contains(_getDayString(now.weekday)),
        orElse: () => BusinessHours(
          openHour: 0,
          openMinute: 0,
          closeHour: 0,
          closeMinute: 0,
          daysOfWeek: [],
        ),
      );

      if (todayHours != null) {
        final closeTime =
            _formatTime(todayHours.closeHour, todayHours.closeMinute);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.access_time, color: Colors.green),
          title: Text(
            '영업 중 - $closeTime에 영업 종료',
            style: const TextStyle(color: Colors.green),
          ),
          minVerticalPadding: 0,
          visualDensity: VisualDensity.compact,
        );
      }
    }
    // 영업 종료인 경우
    else {
      // 다음 영업일과 시간 찾기
      DateTime checkDate = now;
      BusinessHours? nextOpenHours;
      String nextDay = '';

      // 최대 7일까지 확인
      for (int i = 0; i < 7; i++) {
        final dayString = _getDayString(checkDate.weekday);
        nextOpenHours = widget.store.businessHours?.firstWhere(
          (hours) => hours.daysOfWeek.contains(dayString),
          orElse: () => BusinessHours(
            openHour: 0,
            openMinute: 0,
            closeHour: 0,
            closeMinute: 0,
            daysOfWeek: [],
          ),
        );

        if (nextOpenHours?.daysOfWeek.isNotEmpty ?? false) {
          nextDay = _getKoreanDay(checkDate.weekday);
          break;
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }

      if (nextOpenHours != null && nextOpenHours.daysOfWeek.isNotEmpty) {
        final openTime =
            _formatTime(nextOpenHours.openHour, nextOpenHours.openMinute);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: const Icon(Icons.access_time, color: Colors.red),
          title: Text(
            '영업 종료 - $nextDay $openTime에 영업 시작',
            style: const TextStyle(color: Colors.red),
          ),
          minVerticalPadding: 0,
          visualDensity: VisualDensity.compact,
        );
      }
    }

    return const ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(Icons.access_time, color: Colors.grey),
      title: Text(
        '영업 시간 정보 없음',
        style: TextStyle(color: Colors.grey),
      ),
      minVerticalPadding: 0,
      visualDensity: VisualDensity.compact,
    );
  }

  String _formatTime(int hour, int minute) {
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour <= 12 ? hour : hour - 12;
    return '$period ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _getDayString(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[weekday - 1];
  }

  String _getKoreanDay(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }

  Widget _buildBusinessAndHappyHours() {
    if (widget.store.is24Hours) {
      return const Text('24시간 영업');
    }

    final List<String> days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Column(
      children: days.map((day) {
        // 영업시간 찾기
        var businessHours = widget.store.businessHours?.firstWhere(
          (hours) => hours.daysOfWeek.contains(day),
          orElse: () => BusinessHours(
            openHour: 0,
            openMinute: 0,
            closeHour: 0,
            closeMinute: 0,
            daysOfWeek: [],
          ),
        );

        // 해당 요일의 모든 해피아워 찾기
        var happyHours = widget.store.happyHours
                ?.where((hours) => hours.daysOfWeek.contains(day))
                .toList() ??
            [];

        // 시작 시간 기준으로 정렬
        happyHours.sort((a, b) {
          int aTime = a.startHour * 60 + a.startMinute;
          int bTime = b.startHour * 60 + b.startMinute;
          return aTime.compareTo(bTime);
        });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 요일
                  SizedBox(
                    width: 40,
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  // 영업시간
                  Expanded(
                    flex: 2,
                    child: Text(
                      businessHours?.daysOfWeek.isEmpty ?? true
                          ? '휴무'
                          : '${_formatTime(businessHours!.openHour, businessHours.openMinute)} - ${_formatTime(businessHours.closeHour, businessHours.closeMinute)}',
                      style: const TextStyle(height: 1.3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 해피아워
                  if (widget.store.happyHours?.isNotEmpty ?? false)
                    Expanded(
                      flex: 2,
                      child: happyHours.isEmpty
                          ? const Text('-', style: TextStyle(height: 1.3))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: happyHours.map((hours) {
                                return Text(
                                  '${_formatTime(hours.startHour, hours.startMinute)} - ${_formatTime(hours.endHour, hours.endMinute)}',
                                  style: TextStyle(
                                    fontSize: happyHours.length > 1 ? 12 : 14,
                                    height: 1.3,
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                ],
              ),
            ),
            // 마지막 요일이 아닐 경우에만 구분선 추가
            if (day != days.last)
              const Divider(
                height: 1,
                thickness: 0.5,
                color: Color(0xFFEEEEEE),
              ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildMenuList() {
    if (widget.store.menus.isEmpty) {
      return const Text('메뉴 정보가 없습니다.');
    }

    var filteredMenus = widget.store.menus
        .where((menu) => menu.type == _selectedCategory)
        .toList();

    if (filteredMenus.isEmpty) {
      return const Text('해당 카테고리의 메뉴가 없습니다.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredMenus.length,
      itemBuilder: (context, index) {
        final menu = filteredMenus[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(menu.name),
              Text('\$${menu.price.toStringAsFixed(2)}'),
            ],
          ),
        );
      },
    );
  }
}

// 전체 이미지를 볼 수 있는 갤러리 페이지
class GalleryViewPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const GalleryViewPage({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<GalleryViewPage> createState() => _GalleryViewPageState();
}

class _GalleryViewPageState extends State<GalleryViewPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${widget.images.length}장의 사진'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.error,
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black,
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: widget.images.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: widget.images[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.error,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
