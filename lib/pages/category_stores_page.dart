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
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 500), () {
      _filterStores(_searchController.text);
    });
  }

  void _filterStores(String query) {
    if (mounted) {
      setState(() {
        if (query.isEmpty && selectedDateTime == null) {
          // 검색어와 날짜/시간 모두 없는 경우
          displayStores = stores;
        } else {
          displayStores = stores.where((store) {
            bool matchesQuery = query.isEmpty || // 검색어가 비어있으면 true
                store.name.toLowerCase().contains(query.toLowerCase()) ||
                store.category.toLowerCase().contains(query.toLowerCase());

            bool matchesDateTime =
                selectedDateTime == null || // 날짜/시간이 선택되지 않았으면 true
                    (store.isOpenAt(selectedDateTime!) &&
                        (widget.category == 'happy_hour'
                            ? store.isHappyHourAt(selectedDateTime!)
                            : true));

            return matchesQuery && matchesDateTime;
          }).toList();
        }
      });
    }
  }

  void _applyFilters() {
    print('\n=== Applying Filters ===');
    print('Initial stores count: ${stores.length}');
    print('Show Open Only: $showOpenOnly');
    print('Show Happy Hour Only: $showHappyHourOnly');
    print('Selected DateTime: $selectedDateTime');

    setState(() {
      // 항상 원본 stores에서 시작
      List<Store> tempStores = List<Store>.from(stores);
      print('Starting filter with ${tempStores.length} stores');

      // Open Now 필터
      if (showOpenOnly) {
        tempStores = tempStores.where((store) {
          if (selectedDateTime != null) {
            return store.isOpenAt(selectedDateTime!);
          } else {
            bool isCurrentlyOpen = store.isCurrentlyOpen();
            print('Store: ${store.name} - Is Currently Open: $isCurrentlyOpen');
            return isCurrentlyOpen;
          }
        }).toList();
        print('After Open Now filter: ${tempStores.length} stores');
      }

      // Happy Hour 필터
      if (showHappyHourOnly) {
        tempStores = tempStores.where((store) {
          if (selectedDateTime != null) {
            return store.isHappyHourAt(selectedDateTime!);
          } else {
            bool isCurrentlyHappyHour = store.isCurrentlyHappyHour();
            print(
                'Store: ${store.name} - Is Currently Happy Hour: $isCurrentlyHappyHour');
            return isCurrentlyHappyHour;
          }
        }).toList();
        print('After Happy Hour filter: ${tempStores.length} stores');
      }

      // 검색어 필터 유지
      if (_searchController.text.isNotEmpty) {
        tempStores = tempStores
            .where((store) =>
                store.name
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()) ||
                store.category
                    .toLowerCase()
                    .contains(_searchController.text.toLowerCase()))
            .toList();
        print('After search filter: ${tempStores.length} stores');
      }

      // 정렬 적용
      tempStores.sort((a, b) {
        if (sortType == SortType.distance) {
          return (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity);
        } else {
          return (b.cachedAverageRating ?? 0)
              .compareTo(a.cachedAverageRating ?? 0);
        }
      });

      displayStores = tempStores;
      print('Final stores count: ${displayStores.length}');
    });
  }

  @override
  void dispose() {
    _debouncer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    try {
      List<Store> loadedStores;
      if (widget.category == 'all') {
        loadedStores = await StoreService().getAllStores();
      } else if (widget.category == 'nearby') {
        if (widget.userLocation != null) {
          loadedStores = await StoreService().getNearbyStores(
            widget.userLocation!.latitude,
            widget.userLocation!.longitude,
          );
        } else {
          loadedStores = [];
        }
      } else {
        loadedStores =
            await StoreService().getStoresByCategory(widget.category);
      }

      if (mounted) {
        setState(() {
          stores = loadedStores;
          displayStores = loadedStores;
        });
      }
    } catch (e) {
      print('Error loading stores: $e');
      if (mounted) {
        setState(() {
          stores = [];
          displayStores = [];
        });
      }
    }
  }

  Widget _buildFilterBar() {
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

  Widget _buildTimeSelector() {
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
                displayStores = stores;
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
                  onPressed: () {
                    setState(() {
                      isSearching = true;
                    });
                  },
                ),
              ],
      ),
      body: Column(
        children: [
          if (isSearching) ...[
            _buildFilterBar(),
            _buildTimeSelector(),
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
            child: stores.isEmpty
                ? const Center(child: CircularProgressIndicator())
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
