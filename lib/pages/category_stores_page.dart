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
  final StoreService _storeService = StoreService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debouncer;
  List<Store> stores = [];
  List<Store> filteredStores = [];
  bool isSearching = false;
  SortType sortType = SortType.distance;
  bool showOpenOnly = false;
  DateTime? selectedDateTime;

  final List<String> cuisineTypes = [
    // Asian Cuisines
    'Asian',
    'Korean',
    'Japanese',
    'Chinese',
    'Thai',
    'Vietnamese',
    'Indian',
    'Dim Sum',
    'Sushi',
    'Ramen',
    'Pho',

    // Western Cuisines
    'American',
    'Italian',
    'French',
    'Greek',
    'Spanish',
    'Mexican',
    'British',
    'German',
    'Mediterranean',

    // Specific Types
    'BBQ',
    'Pizza',
    'Burgers',
    'Seafood',
    'Steak',
    'Noodles',
    'Fast Food',

    // Regional
    'Middle Eastern',
    'Latin',
    'Southern',
    'Canadian',

    // Dietary
    'Vegetarian',
    'Vegan',
    'Healthy',
    'Gluten Free',

    // Specific Categories
    'Dessert',
    'Ice Cream',
    'Cafe',
    'Bar',
    'Pub',
    'Brunch',
    'Street Food',
  ];

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      print('Loading stores for category: ${widget.category}');
      print(
          'User location: ${widget.userLocation?.latitude}, ${widget.userLocation?.longitude}');

      final allStores = await _storeService.getStores();

      if (widget.userLocation != null) {
        // 각 스토어에 대해 현재 위치와의 거리 계산
        for (var store in allStores) {
          double distanceInMeters = Geolocator.distanceBetween(
            widget.userLocation!.latitude,
            widget.userLocation!.longitude,
            store.latitude,
            store.longitude,
          );
          store.distance = distanceInMeters;
        }

        // 거리순으로 정렬
        allStores.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      }

      setState(() {
        stores = allStores;
      });

      print('Loaded ${stores.length} stores');
    } catch (e) {
      print('Error loading stores: $e');
    }
  }

  @override
  void dispose() {
    _debouncer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _filterStores(String query) {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        if (query.isEmpty) {
          filteredStores = stores;
        } else {
          final queryLower = query.toLowerCase();
          filteredStores = stores.where((store) {
            return store.searchableText.contains(queryLower);
          }).toList();

          // 정렬
          filteredStores.sort((a, b) {
            if (a.distance != null && b.distance != null) {
              return a.distance!.compareTo(b.distance!);
            }
            return (b.cachedAverageRating ?? 0)
                .compareTo(a.cachedAverageRating ?? 0);
          });
        }
      });
    });
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          // 거리순/평점순 토글
          ToggleButtons(
            isSelected: [
              sortType == SortType.distance,
              sortType == SortType.rating,
            ],
            onPressed: (index) {
              setState(() {
                sortType = index == 0 ? SortType.distance : SortType.rating;
                _applyFilters();
              });
            },
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 16),
                    SizedBox(width: 4),
                    Text('Distance'),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.star, size: 16),
                    SizedBox(width: 4),
                    Text('Rating'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // 영업중인 가게만 보기
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
        ],
      ),
    );
  }

  void _applyFilters() {
    if (filteredStores.isEmpty) return;

    setState(() {
      if (showOpenOnly) {
        filteredStores =
            filteredStores.where((store) => store.isCurrentlyOpen()).toList();
      }

      filteredStores.sort((a, b) {
        if (sortType == SortType.distance) {
          return (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity);
        } else {
          return (b.cachedAverageRating ?? 0)
              .compareTo(a.cachedAverageRating ?? 0);
        }
      });
    });
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
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                isSearching = !isSearching;
                if (!isSearching) {
                  _searchController.clear();
                  filteredStores = stores;
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (isSearching) ...[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search restaurants or cuisines...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: _filterStores,
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: cuisineTypes.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: Text(cuisineTypes[index]),
                      onSelected: (selected) {
                        _searchController.text = cuisineTypes[index];
                        _filterStores(cuisineTypes[index]);
                      },
                    ),
                  );
                },
              ),
            ),
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
                    stores: isSearching ? filteredStores : stores,
                    scrollController: _scrollController,
                    selectedDateTime: selectedDateTime,
                  ),
          ),
        ],
      ),
    );
  }
}
