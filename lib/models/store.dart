import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

enum StoreCategory {
  happyHour('happy_hour'),
  allYouCanEat('all_you_can_eat'),
  specialEvents('special_events'),
  dealsAndDiscounts('deals_and_discounts');

  final String value;
  const StoreCategory(this.value);

  static List<StoreCategory> fromString(String categories) {
    final categoryList = categories.split(',');
    return categoryList
        .map((category) => StoreCategory.values.firstWhere(
              (e) => e.value == category.trim(),
              orElse: () => throw ArgumentError('Invalid category: $category'),
            ))
        .toList();
  }
}

class Store {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<StoreCategory> categories;
  final List<double> ratings;
  final List<String> cuisineTypes;
  final List<MenuItem> menus;
  final String contactNumber;
  double? _cachedDistance;
  Position? _lastPosition;
  late final String searchableText;
  final List<BusinessHours>? businessHours;
  final List<HappyHour>? happyHours;
  final bool is24Hours;
  final int totalRatings;
  final List<String>? images;

  double? _cachedAverageRating;
  int? _lastRatingsLength;

  String? _cachedAddress;
  final LocationService _locationService = LocationService();

  double get averageRating {
    if (_lastRatingsLength != ratings.length || _cachedAverageRating == null) {
      if (ratings.isEmpty) {
        _cachedAverageRating = 0.0;
      } else {
        final recentRatings = ratings.length > RATING_LIMIT
            ? ratings.sublist(ratings.length - RATING_LIMIT)
            : ratings;
        _cachedAverageRating =
            recentRatings.reduce((a, b) => a + b) / recentRatings.length;
      }
      _lastRatingsLength = ratings.length;
    }
    return _cachedAverageRating!;
  }

  static const RATING_LIMIT = 20; // 나중에 200으로 변경 가능

  int get recentRatingsCount =>
      ratings.length > RATING_LIMIT ? RATING_LIMIT : ratings.length;

  double? get distance => _cachedDistance;
  set distance(double? value) => _cachedDistance = value;

  void calculateDistance(Position currentPosition) {
    // 같은 위치에서 이미 계산했다면 캐시된 값 반환
    if (_lastPosition?.latitude == currentPosition.latitude &&
        _lastPosition?.longitude == currentPosition.longitude) {
      return;
    }

    _lastPosition = currentPosition;
    _cachedDistance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          latitude,
          longitude,
        ) /
        1000; // 미터를 킬로미터로 변환
  }

  // 거리가 특정 범위 내인지 확인하는 유틸리티 메서드
  bool isWithinDistance(double maxDistanceKm) {
    return (distance ?? double.infinity) <= maxDistanceKm;
  }

  Store({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required String category,
    required this.ratings,
    required this.cuisineTypes,
    required this.menus,
    required this.contactNumber,
    this.businessHours,
    this.happyHours,
    this.is24Hours = false,
    required this.totalRatings,
    this.images,
  }) : categories = StoreCategory.fromString(category) {
    searchableText = [
      name.toLowerCase(),
      ...cuisineTypes.map((type) => type.toLowerCase()),
      ...menus.map((menu) => menu.name.toLowerCase()),
    ].join(' ');
  }

  factory Store.fromJson(Map<String, dynamic> json) {
    List<double> parseRatings() {
      try {
        final ratingsList = json['ratings'];
        if (ratingsList == null) return [];
        if (ratingsList is! List) return [];
        return ratingsList
            .whereType<num>()
            .map((rating) => rating.toDouble())
            .toList();
      } catch (e) {
        print('Error parsing ratings: $e');
        return [];
      }
    }

    double parseLatitude() {
      final location = json['location'];
      if (location is Map) {
        return (location['latitude'] ?? 0.0).toDouble();
      } else if (location != null) {
        // GeoPoint 처리
        return location.latitude.toDouble();
      }
      return 0.0;
    }

    double parseLongitude() {
      final location = json['location'];
      if (location is Map) {
        return (location['longitude'] ?? 0.0).toDouble();
      } else if (location != null) {
        // GeoPoint 처리
        return location.longitude.toDouble();
      }
      return 0.0;
    }

    return Store(
      id: json['storeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: parseLatitude(),
      longitude: parseLongitude(),
      category: (json['category'] as List?)
              ?.map((e) => e.toString())
              .toList()
              .join(',') ??
          '',
      ratings: parseRatings(),
      cuisineTypes: (json['cuisineTypes'] as List?)
              ?.map((type) => type.toString())
              .toList() ??
          [],
      menus: (json['menus'] as List?)
              ?.map((menu) => MenuItem.fromJson(menu))
              .toList() ??
          [],
      contactNumber: json['contactNumber']?.toString() ?? '',
      businessHours: (json['businessHours'] as List?)
          ?.map((hour) => BusinessHours.fromJson(hour))
          .toList(),
      happyHours: (json['happyHours'] as List?)
          ?.map((hour) => HappyHour.fromJson(hour))
          .toList(),
      is24Hours: json['is24Hours'] ?? false,
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      images: (json['images'] as List?)?.cast<String>(),
    );
  }

  String _formatTimeFromHourMinute(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  bool _isTimeInRange(DateTime dateTime, int startHour, int startMinute,
      int endHour, int endMinute, bool isNextDay) {
    final time = _formatTimeFromHourMinute(dateTime.hour, dateTime.minute);
    final start = _formatTimeFromHourMinute(startHour, startMinute);
    final end = _formatTimeFromHourMinute(endHour, endMinute);

    if (!isNextDay) {
      return time.compareTo(start) >= 0 && time.compareTo(end) <= 0;
    } else {
      // 다음날까지 이어지는 경우 (예: 오후 11시 ~ 다음날 오전 2시)
      if (time.compareTo(start) >= 0 || time.compareTo(end) <= 0) {
        return true;
      }
    }
    return false;
  }

  bool isOpenAt(DateTime dateTime) {
    if (is24Hours) return true;
    if (businessHours == null || businessHours!.isEmpty) return false;

    final dayOfWeek = dateTime.weekday;
    return businessHours!.any((hours) =>
        hours.daysOfWeek.contains(_getDayOfWeekString(dayOfWeek)) &&
        _isTimeInRange(dateTime, hours.openHour, hours.openMinute,
            hours.closeHour, hours.closeMinute, hours.isNextDay));
  }

  bool isCurrentlyOpen() {
    final now = DateTime.now();
    return isOpenAt(now);
  }

  bool isHappyHourAt(DateTime dateTime) {
    if (happyHours == null || happyHours!.isEmpty) return false;

    final dayOfWeek = dateTime.weekday;
    return happyHours!.any((hours) =>
        hours.daysOfWeek.contains(_getDayOfWeekString(dayOfWeek)) &&
        _isTimeInRange(dateTime, hours.startHour, hours.startMinute,
            hours.endHour, hours.endMinute, hours.isNextDay));
  }

  bool isHappyHourNow() {
    final now = DateTime.now();
    return isHappyHourAt(now);
  }

  String _getDayOfWeekString(int dayOfWeek) {
    switch (dayOfWeek) {
      case DateTime.monday:
        return 'MON';
      case DateTime.tuesday:
        return 'TUE';
      case DateTime.wednesday:
        return 'WED';
      case DateTime.thursday:
        return 'THU';
      case DateTime.friday:
        return 'FRI';
      case DateTime.saturday:
        return 'SAT';
      case DateTime.sunday:
        return 'SUN';
      default:
        throw ArgumentError('Invalid day of week');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'storeId': id,
      'name': name,
      'address': address,
      'category': categories.map((c) => c.value).toList(),
      'cuisineTypes': cuisineTypes,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'ratings': ratings,
      'totalRatings': totalRatings,
      'menus': menus.map((x) => x.toJson()).toList(),
      'businessHours': businessHours?.map((x) => x.toJson()).toList(),
      'happyHours': happyHours
          ?.map((x) => {
                'startHour': x.startHour,
                'startMinute': x.startMinute,
                'endHour': x.endHour,
                'endMinute': x.endMinute,
                'isNextDay': x.isNextDay,
                'daysOfWeek': x.daysOfWeek,
              })
          .toList(),
      'is24Hours': is24Hours,
      'images': images,
    };
  }

  Future<String> getAddress() async {
    if (_cachedAddress != null) return _cachedAddress!;

    _cachedAddress =
        await _locationService.getAddressFromCoordinates(latitude, longitude);
    return _cachedAddress!;
  }

  static Future<Map<String, dynamic>?> getLocationFromAddress(
      String address) async {
    final locationService = LocationService();
    final results = await locationService.searchAddress(address);
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  Future<String> get formattedAddress => getAddress();
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class MenuItem {
  final String itemId;
  final String name;
  final double price;
  final String type;

  MenuItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.type,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      itemId: json['itemId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      type: json['type']?.toString() ?? 'default',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'type': type,
    };
  }
}

class BusinessHours {
  final int openHour;
  final int openMinute;
  final int closeHour;
  final int closeMinute;
  final bool isNextDay;
  final List<String> daysOfWeek;

  BusinessHours({
    required this.openHour,
    required this.openMinute,
    required this.closeHour,
    required this.closeMinute,
    this.isNextDay = false,
    required this.daysOfWeek,
  });

  factory BusinessHours.fromJson(Map<String, dynamic> json) {
    return BusinessHours(
      openHour: json['openHour'],
      openMinute: json['openMinute'],
      closeHour: json['closeHour'],
      closeMinute: json['closeMinute'],
      isNextDay: json['isNextDay'] ?? false,
      daysOfWeek: List<String>.from(json['daysOfWeek']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'openHour': openHour,
      'openMinute': openMinute,
      'closeHour': closeHour,
      'closeMinute': closeMinute,
      'isNextDay': isNextDay,
      'daysOfWeek': daysOfWeek,
    };
  }
}

class HappyHour {
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool isNextDay;
  final List<String> daysOfWeek; // ["MON", "TUE", ...]

  HappyHour({
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.isNextDay = false,
    required this.daysOfWeek,
  });

  factory HappyHour.fromJson(Map<String, dynamic> json) {
    return HappyHour(
      startHour: json['startHour'],
      startMinute: json['startMinute'],
      endHour: json['endHour'],
      endMinute: json['endMinute'],
      isNextDay: json['isNextDay'] ?? false,
      daysOfWeek: List<String>.from(json['daysOfWeek']),
    );
  }

  bool isHappyHourNow() {
    final now = DateTime.now();
    if (!daysOfWeek.contains(_getDayOfWeek(now))) return false;

    final currentHour = now.hour;
    final currentMinute = now.minute;

    final currentTime = currentHour * 60 + currentMinute;
    final startTime = startHour * 60 + startMinute;
    final endTime = endHour * 60 + endMinute;

    if (isNextDay) {
      if (currentTime >= startTime) return true;
      if (currentTime <= endTime) return true;
      return false;
    } else {
      return currentTime >= startTime && currentTime <= endTime;
    }
  }

  bool isHappyHourAt(DateTime dateTime) {
    if (!daysOfWeek.contains(_getDayOfWeek(dateTime))) return false;

    final hour = dateTime.hour;
    final minute = dateTime.minute;

    final currentTime = hour * 60 + minute;
    final startTime = startHour * 60 + startMinute;
    final endTime = endHour * 60 + endMinute;

    if (isNextDay) {
      if (currentTime >= startTime) return true;
      if (currentTime <= endTime) return true;
      return false;
    } else {
      return currentTime >= startTime && currentTime <= endTime;
    }
  }

  String _getDayOfWeek(DateTime date) {
    switch (date.weekday) {
      case 1:
        return "MON";
      case 2:
        return "TUE";
      case 3:
        return "WED";
      case 4:
        return "THU";
      case 5:
        return "FRI";
      case 6:
        return "SAT";
      case 7:
        return "SUN";
      default:
        return "";
    }
  }
}
