import 'dart:math';

import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import '../widgets/paginated_store_list.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/event_bus.dart';
import '../widgets/scroll_to_top.dart';

enum SortType { distance, rating }

class CategoryStoresPage extends StatefulWidget {
  final String category;
  final String title;
  final Position? userLocation;
  final String? address;

  const CategoryStoresPage({
    Key? key,
    required this.category,
    required this.title,
    this.userLocation,
    this.address,
  }) : super(key: key);

  @override
  State<CategoryStoresPage> createState() => _CategoryStoresPageState();
}

class _CategoryStoresPageState extends State<CategoryStoresPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debouncer;

  List<Store> stores = [];
  List<Store> displayStores = [];
  bool isSearching = false;
  bool isFilterExpanded = false;
  bool showOpenOnly = false;
  bool showHappyHourOnly = false;
  SortType sortType = SortType.distance;
  DateTime? selectedDateTime;
  List<Store> loadedStores = [];
  bool isLoading = true;

  // 검색 키워드 리스트 추가
  final List<String> cuisineTypes = [
    'Korean',
    'Japanese',
    'Chinese',
    'Italian',
    'Mexican',
    'American',
    'Thai',
    'Vietnamese',
    'Indian',
    'Mediterranean',
  ];

  // 로컬 위치 변수 추가
  Position? _currentPosition;
  // 리스너 구독 관리를 위한 변수 추가
  StreamSubscription? _addressSubscription;

  @override
  void initState() {
    super.initState();
    // 초기값 설정
    _currentPosition = widget.userLocation;
    _setupAddressListener();
    _loadStores();
    _searchController.addListener(_onSearchChanged);
  }

  // 주소 업데이트 이벤트 리스너 설정
  void _setupAddressListener() {
    print('Setting up address listener in CategoryStoresPage');
    _addressSubscription = EventBus().onAddressUpdate.listen((event) {
      print(
          'Received address update event: ${event.position.latitude}, ${event.position.longitude}');
      if (mounted) {
        setState(() {
          // 로컬 위치 변수 업데이트
          _currentPosition = event.position;
        });
        // 스토어 목록 다시 로드
        _loadStores();
      }
    });
  }

  void _onSearchChanged() {
    print('\n=== Search Process Started ===');
    print('Search text: ${_searchController.text}');

    if (_searchController.text.isEmpty) {
      setState(() {
        displayStores = List<Store>.from(loadedStores);
      });
    } else {
      final searchTerm = _searchController.text.toLowerCase();
      print('Searching for term: $searchTerm');

      setState(() {
        isSearching = true;

        // 1. 가게 이름 매칭 (정확한 일치는 최상위)
        final exactNameMatches = loadedStores.where((store) {
          bool matches = store.name.toLowerCase() == searchTerm;
          if (matches) print('Exact name match found: ${store.name}');
          return matches;
        }).toList();

        // 2. 가게 이름 부분 매칭
        final partialNameMatches = loadedStores.where((store) {
          bool matches = !exactNameMatches.contains(store) &&
              store.name.toLowerCase().contains(searchTerm);
          if (matches) print('Partial name match found: ${store.name}');
          return matches;
        }).toList();

        // 3. 쿠진 타입 매칭
        final cuisineMatches = loadedStores.where((store) {
          bool matches = !exactNameMatches.contains(store) &&
              !partialNameMatches.contains(store) &&
              store.cuisineTypes
                  .any((cuisine) => cuisine.toLowerCase().contains(searchTerm));
          if (matches) {
            print('Cuisine match found: ${store.name} - ${store.cuisineTypes}');
          }
          return matches;
        }).toList();

        // 4. 메뉴 이름 매칭 (수정된 부분)
        final menuMatches = loadedStores.where((store) {
          if (exactNameMatches.contains(store) ||
              partialNameMatches.contains(store) ||
              cuisineMatches.contains(store)) {
            return false;
          }

          bool hasMatchingMenu = store.menus.any((menu) {
            bool matches = menu.name.toLowerCase().contains(searchTerm);
            if (matches) {
              print('Menu match found in ${store.name}: ${menu.name}');
            }
            return matches;
          });

          return hasMatchingMenu;
        }).toList();

        print('Found matches - Exact: ${exactNameMatches.length}, '
            'Partial: ${partialNameMatches.length}, '
            'Cuisine: ${cuisineMatches.length}, '
            'Menu: ${menuMatches.length}');

        // 우선순위대로 결과 합치기
        displayStores = [
          ...exactNameMatches,
          ...partialNameMatches,
          ...cuisineMatches,
          ...menuMatches,
        ];

        // 각 그룹 내에서 현재 정렬 기준 적용
        if (sortType == SortType.rating) {
          exactNameMatches
              .sort((a, b) => b.averageRating.compareTo(a.averageRating));
          partialNameMatches
              .sort((a, b) => b.averageRating.compareTo(a.averageRating));
          cuisineMatches
              .sort((a, b) => b.averageRating.compareTo(a.averageRating));
          menuMatches
              .sort((a, b) => b.averageRating.compareTo(a.averageRating));
        } else if (sortType == SortType.distance && _currentPosition != null) {
          exactNameMatches.sort((a, b) => (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity));
          partialNameMatches.sort((a, b) => (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity));
          cuisineMatches.sort((a, b) => (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity));
          menuMatches.sort((a, b) => (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity));
        }
      });
      _applyFilters();
    }
    print('=== Search Process Ended ===\n');
  }

  void _applyFilters() {
    print('\n=== Applying Filters and Sorting ===');
    print('Initial stores count: ${loadedStores.length}');
    print('Current sort type: $sortType');
    print('Show Open Only: $showOpenOnly');
    print('Show Happy Hour Only: $showHappyHourOnly');

    setState(() {
      // 검색 중일 때는 displayStores를 다시 초기화하지 않음
      List<Store> filteredStores = List<Store>.from(displayStores); // 수정된 부분

      // Open Now 필터
      if (showOpenOnly) {
        filteredStores = filteredStores.where((store) {
          if (selectedDateTime != null) {
            return store.isOpenAt(selectedDateTime!);
          } else {
            return store.isCurrentlyOpen();
          }
        }).toList();
        print('After Open Now filter: ${filteredStores.length} stores');
      }

      // Happy Hour 필터
      if (showHappyHourOnly) {
        filteredStores = filteredStores.where((store) {
          if (selectedDateTime != null) {
            return store.isHappyHourAt(selectedDateTime!);
          } else {
            return store.isHappyHourNow();
          }
        }).toList();
        print('After Happy Hour filter: ${filteredStores.length} stores');
      }

      // 정렬 로직
      if (sortType == SortType.rating) {
        filteredStores
            .sort((a, b) => b.averageRating.compareTo(a.averageRating));
        print('Sorted by rating');
      } else if (sortType == SortType.distance && _currentPosition != null) {
        print('Attempting to sort by distance');
        print(
            'Before sort - First store distance: ${filteredStores.isNotEmpty ? filteredStores.first.distance : "no stores"}');
        filteredStores.sort((a, b) => (a.distance ?? double.infinity)
            .compareTo(b.distance ?? double.infinity));
        print(
            'After sort - First store distance: ${filteredStores.isNotEmpty ? filteredStores.first.distance : "no stores"}');
      }

      displayStores = filteredStores; // 필터링된 결과를 displayStores에 할당
      print('Final stores count: ${displayStores.length}');
    });
  }

  @override
  void dispose() {
    // 리스너 구독 해제
    _addressSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    print('\n=== _loadStores Started ===');
    print('Category: ${widget.category}');
    print('User Location: $_currentPosition');

    setState(() {
      isLoading = true;
    });

    try {
      final storeService = StoreService();

      if (widget.category == 'nearby' && _currentPosition != null) {
        print('Loading nearby stores...');
        loadedStores = await storeService.getNearbyStores(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        print('Loaded ${loadedStores.length} nearby stores');
      } else {
        print('Loading stores for category: ${widget.category}');
        if (_currentPosition != null) {
          print('Getting stores with location data');
          loadedStores = await storeService.getStoresByCategory(
            widget.category,
            _currentPosition!,
          );
          print(
              'First store distance: ${loadedStores.isNotEmpty ? loadedStores.first.distance : "no stores"}');
        } else {
          print('Getting stores without location data');
          List<Store> stores = await storeService.loadStores();
          loadedStores = stores
              .where((store) =>
                  store.categories.any((cat) => cat.value == widget.category))
              .toList();
        }
        print('Loaded ${loadedStores.length} stores for category');
      }

      displayStores = List<Store>.from(loadedStores);
      print('Display stores count: ${displayStores.length}');
      if (displayStores.isNotEmpty) {
        print('First display store distance: ${displayStores.first.distance}');
      }
    } catch (e) {
      print('Error loading stores: $e');
      print('Stack trace: ${StackTrace.current}');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
    print('=== _loadStores Ended ===\n');
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    print('\nCalculating distance:');
    print('From: ($lat1, $lon1)');
    print('To: ($lat2, $lon2)');

    var R = 6371.0; // 지구의 반경 (km)

    // 위도, 경도를 라디안으로 변환
    var lat1Rad = lat1 * (pi / 180.0);
    var lon1Rad = lon1 * (pi / 180.0);
    var lat2Rad = lat2 * (pi / 180.0);
    var lon2Rad = lon2 * (pi / 180.0);

    // 위도, 경도의 차이
    var dLat = lat2Rad - lat1Rad;
    var dLon = lon2Rad - lon1Rad;

    // Haversine 공식
    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);

    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    var distance = R * c;

    print('Calculated distance: $distance km');
    return distance;
  }

  void calculateDistances(Position currentPosition) {
    for (var store in stores) {
      store.calculateDistance(currentPosition);
    }
  }

  Widget buildFilterBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 검색창과 필터 버튼
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              // 검색창
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search restaurants or cuisines...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 필터 버튼
              IconButton(
                icon: Icon(
                  isFilterExpanded ? Icons.filter_list_off : Icons.filter_list,
                  color: (showOpenOnly ||
                          showHappyHourOnly ||
                          sortType == SortType.rating)
                      ? Theme.of(context).primaryColor
                      : null,
                ),
                onPressed: () {
                  setState(() {
                    isFilterExpanded = !isFilterExpanded;
                  });
                },
              ),
            ],
          ),
        ),
        // 키워드 버튼들
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              children: cuisineTypes
                  .map(
                    (cuisine) => Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _searchController.text = cuisine;
                            _applyFilters();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            cuisine,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        // 필터 옵션들 (확장 시에만 표시)
        if (isFilterExpanded)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Card(
              margin:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 정렬 옵션
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.location_on, size: 16),
                              SizedBox(width: 4),
                              Text('Distance'),
                            ],
                          ),
                          selected: sortType == SortType.distance,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                sortType = SortType.distance;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 16),
                              SizedBox(width: 4),
                              Text('Rating'),
                            ],
                          ),
                          selected: sortType == SortType.rating,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                sortType = SortType.rating;
                                _applyFilters();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    // 필터 옵션들
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Open Now'),
                          selected: showOpenOnly,
                          onSelected: (selected) {
                            setState(() {
                              showOpenOnly = selected;
                              _applyFilters();
                            });
                          },
                        ),
                        if (widget.category == 'happy_hour')
                          FilterChip(
                            label: const Text('Happy Hour'),
                            selected: showHappyHourOnly,
                            onSelected: (selected) {
                              setState(() {
                                showHappyHourOnly = selected;
                                _applyFilters();
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildTimeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          // 현재 시간으로 초기화 버튼
          TextButton.icon(
            icon: const Icon(Icons.access_time),
            label: const Text('현재 시간으로 보기'),
            onPressed: () {
              setState(() {
                selectedDateTime = null;
              });
            },
          ),
          const Spacer(),
          // 날짜/시간 선택 버튼
          TextButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(selectedDateTime == null
                ? '날짜/시간 선택'
                : '${selectedDateTime!.year}/${selectedDateTime!.month}/${selectedDateTime!.day} '
                    '${selectedDateTime!.hour}:${selectedDateTime!.minute.toString().padLeft(2, '0')}'),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: selectedDateTime ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );

              if (date != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                    selectedDateTime ?? DateTime.now(),
                  ),
                );

                if (time != null) {
                  setState(() {
                    selectedDateTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void toggleSearch() {
    if (!isSearching) {
      setState(() {
        isSearching = true;
      });
      // 상태 업데이트가 완료된 후 실행되도록 함
      Future.delayed(Duration.zero, () {
        setState(() {
          // 필요한 경우 여기서 추가 상태 업데이트
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (isSearching && _searchController.text.isNotEmpty) {
              setState(() {
                _searchController.clear();
                displayStores = List<Store>.from(loadedStores);
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions: isSearching
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: toggleSearch,
                ),
              ],
      ),
      body: Column(
        children: [
          if (isSearching) ...[
            buildFilterBar(),
            buildTimeSelector(),
            if (selectedDateTime != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '선택된 시간 기준으로 영업 상태 표시 중',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayStores.isEmpty
                    ? const Center(child: Text('검색 결과가 없습니다.'))
                    : PaginatedStoreList(
                        stores: displayStores,
                        scrollController: _scrollController,
                        selectedDateTime: selectedDateTime,
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
}
