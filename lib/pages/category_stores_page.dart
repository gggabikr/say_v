import 'dart:math';

import 'package:flutter/material.dart';
import '../models/store.dart';
import '../services/store_service.dart';
import '../widgets/paginated_store_list.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _loadStores();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    print('\n=== Search Process Started ===');
    print('Search text: ${_searchController.text}');
    print('Initial loaded stores count: ${loadedStores.length}');

    if (_searchController.text.isEmpty && isSearching) {
      print('Empty search text - resetting to all stores');
      setState(() {
        isSearching = false;
        displayStores = List<Store>.from(loadedStores);
      });
    } else if (_searchController.text.isNotEmpty) {
      print('Searching for: ${_searchController.text}');
      setState(() {
        isSearching = true;
        displayStores = loadedStores.where((store) {
          bool matches = store.name
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              store.category
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              (store.cuisineTypes.any((cuisine) => cuisine
                      .toLowerCase()
                      .contains(_searchController.text.toLowerCase())) ??
                  false);
          print('Checking store: ${store.name}');
          print('Categories: ${store.category}');
          print('Cuisine Types: ${store.cuisineTypes}');
          print('Matches: $matches');
          return matches;
        }).toList();
      });
      print('Found ${displayStores.length} matches before filters');
      _applyFilters();
      print('Final display stores count: ${displayStores.length}');
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
      // 검색어가 있는 경우, 먼저 검색 결과를 다시 계산
      if (isSearching && _searchController.text.isNotEmpty) {
        displayStores = loadedStores.where((store) {
          return store.name
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              store.category
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              (store.cuisineTypes.any((cuisine) => cuisine
                      .toLowerCase()
                      .contains(_searchController.text.toLowerCase())) ??
                  false);
        }).toList();
      } else {
        displayStores = List<Store>.from(loadedStores);
      }

      print('After search filter: ${displayStores.length} stores');

      // Open Now 필터
      if (showOpenOnly) {
        displayStores = displayStores.where((store) {
          if (selectedDateTime != null) {
            return store.isOpenAt(selectedDateTime!);
          } else {
            return store.isCurrentlyOpen();
          }
        }).toList();
        print('After Open Now filter: ${displayStores.length} stores');
      }

      // Happy Hour 필터
      if (showHappyHourOnly) {
        displayStores = displayStores.where((store) {
          if (selectedDateTime != null) {
            return store.isHappyHourAt(selectedDateTime!);
          } else {
            return store.isCurrentlyHappyHour();
          }
        }).toList();
        print('After Happy Hour filter: ${displayStores.length} stores');
      }

      // 정렬 로직
      if (sortType == SortType.rating) {
        print('Attempting to sort by rating');
        print(
            'Before sort - First store rating: ${displayStores.isNotEmpty ? displayStores.first.cachedAverageRating : "no stores"}');
        displayStores.sort(
            (a, b) => b.cachedAverageRating.compareTo(a.cachedAverageRating));
        print(
            'After sort - First store rating: ${displayStores.isNotEmpty ? displayStores.first.cachedAverageRating : "no stores"}');
      } else if (sortType == SortType.distance && widget.userLocation != null) {
        print('Attempting to sort by distance');
        print(
            'Before sort - First store distance: ${displayStores.isNotEmpty ? displayStores.first.distance : "no stores"}');
        displayStores.sort((a, b) => (a.distance ?? double.infinity)
            .compareTo(b.distance ?? double.infinity));
        print(
            'After sort - First store distance: ${displayStores.isNotEmpty ? displayStores.first.distance : "no stores"}');
      }

      print('Final stores count: ${displayStores.length}');
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    print('Starting to load stores...');
    setState(() {
      isLoading = true;
    });

    try {
      if (widget.category == 'nearby' && widget.userLocation != null) {
        print('Loading nearby stores...');
        List<Store> stores = await StoreService().getNearbyStores(
          widget.userLocation!.latitude,
          widget.userLocation!.longitude,
        );
        loadedStores = stores;
        displayStores = List<Store>.from(loadedStores);
      } else {
        print('Loading all stores...');
        List<Store> stores = await StoreService().getAllStores();
        print('Loaded ${stores.length} stores');

        if (widget.category != 'all') {
          stores = stores.where((store) {
            return store.category.contains(widget.category);
          }).toList();
          print(
              'Filtered to ${stores.length} stores for category ${widget.category}');
        }

        if (widget.userLocation != null) {
          print('Calculating distances...');
          stores = stores.map((store) {
            final distance = calculateDistance(
              widget.userLocation!.latitude,
              widget.userLocation!.longitude,
              store.latitude,
              store.longitude,
            );
            store.distance = distance;
            return store;
          }).toList();
        }

        loadedStores = stores;
        displayStores = List<Store>.from(loadedStores);
        print('Final store count: ${loadedStores.length}');
      }
    } catch (e) {
      print('Error loading stores: $e');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
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
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        _searchController.clear();
        displayStores = List<Store>.from(loadedStores);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (isSearching) {
              setState(() {
                isSearching = false;
                _searchController.clear();
                isLoading = true;
              });
              _loadStores();
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
    );
  }
}
