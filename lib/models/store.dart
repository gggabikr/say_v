import 'package:cloud_firestore/cloud_firestore.dart';
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
  final double averageRating;
  final int totalRatings;
  final Map<String, Review> reviews;
  final List<String> cuisineTypes;
  final List<MenuItem> menus;
  final String contactNumber;
  double? _cachedDistance;
  Position? _lastPosition;
  late final String searchableText;
  final List<BusinessHours>? businessHours;
  final List<HappyHour>? happyHours;
  final bool is24Hours;
  final List<String>? images;

  String? _cachedAddress;
  final LocationService _locationService = LocationService();

  int get recentRatingsCount => totalRatings;

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
    required this.averageRating,
    required this.totalRatings,
    required this.reviews,
    required this.cuisineTypes,
    required this.menus,
    required this.contactNumber,
    this.businessHours,
    this.happyHours,
    this.is24Hours = false,
    this.images,
  }) : categories = StoreCategory.fromString(category) {
    searchableText = [
      name.toLowerCase(),
      ...cuisineTypes.map((type) => type.toLowerCase()),
      ...menus.map((menu) => menu.name.toLowerCase()),
    ].join(' ');
  }

  factory Store.fromJson(Map<String, dynamic> json) {
    Map<String, Review> parseReviews(Map<String, dynamic>? ratingsJson) {
      if (ratingsJson == null || ratingsJson['reviews'] == null) return {};

      final reviewsJson = ratingsJson['reviews'] as Map<String, dynamic>;
      return reviewsJson.map((key, value) =>
          MapEntry(key, Review.fromJson(value as Map<String, dynamic>)));
    }

    double parseLatitude() {
      final location = json['location'];
      if (location is Map) {
        return (location['latitude'] ?? 0.0).toDouble();
      } else if (location != null) {
        return location.latitude.toDouble();
      }
      return 0.0;
    }

    double parseLongitude() {
      final location = json['location'];
      if (location is Map) {
        return (location['longitude'] ?? 0.0).toDouble();
      } else if (location != null) {
        return location.longitude.toDouble();
      }
      return 0.0;
    }

    final ratingsJson = json['ratings'] as Map<String, dynamic>?;
    final rawAverage = ratingsJson?['average'] as num?;

    print('Raw average from Firebase: $rawAverage');
    final parsedAverage = (rawAverage?.toDouble() ?? 0.00).isNaN
        ? 0.00
        : (rawAverage?.toDouble() ?? 0.00);
    print('Parsed average: $parsedAverage');

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
      averageRating: parsedAverage,
      totalRatings: (ratingsJson?['total'] as num?)?.toInt() ?? 0,
      reviews: parseReviews(ratingsJson),
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
      'ratings': {
        'average': averageRating,
        'total': totalRatings,
        'reviews': reviews.map((key, value) => MapEntry(key, value.toJson())),
      },
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

  List<Review> get reviewsList => reviews.values.toList();

  List<Review> get commentedReviews =>
      reviews.values.where((review) => review.comment.isNotEmpty).toList();

  String get ratingDisplay {
    print('Current averageRating: $averageRating');
    print('Formatted rating: ${averageRating.toStringAsFixed(2)}');
    print('Total ratings: $totalRatings');
    final display = totalRatings > 0
        ? "${averageRating.toStringAsFixed(2)} ($totalRatings)"
        : "New!";
    print('Final display: $display');
    return display;
  }
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

class Review {
  final double score;
  final DateTime timestamp;
  final String userName;
  final String comment;
  final List<String>? images;

  Review({
    required this.score,
    required this.timestamp,
    required this.userName,
    required this.comment,
    this.images,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      score: (json['score'] as num).toDouble(),
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      userName: json['userName'] as String,
      comment: json['comment'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'timestamp': timestamp,
      'userName': userName,
      'comment': comment,
      'images': images,
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'timestamp': timestamp.toIso8601String(),
      'userName': userName,
      'comment': comment,
      'images': images,
    };
  }
}
