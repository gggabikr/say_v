import 'package:flutter/foundation.dart';

class Store {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  final List<double> ratings;
  final List<String> cuisineTypes;
  final List<MenuItem> menus;
  double? distance;
  late final String searchableText;
  final BusinessHours? businessHours;
  final List<HappyHour>? happyHours;
  final bool is24Hours;

  // 최근 200개 평점만 사용하여 평균 계산
  Future<double> calculateAverageAsync() async {
    return compute(_calculateAverage, ratings);
  }

  static double _calculateAverage(List<double> ratings) {
    if (ratings.isEmpty) return 0.0;
    final recentRatings = ratings.length > RATING_LIMIT
        ? ratings.sublist(ratings.length - RATING_LIMIT)
        : ratings;
    return recentRatings.reduce((a, b) => a + b) / recentRatings.length;
  }

  // 캐싱을 위한 변수
  double? _cachedAverageRating;
  int? _lastRatingsLength;

  // 캐싱을 적용한 평균 계산
  double get cachedAverageRating {
    // ratings 길이가 변경되었을 때만 재계산
    if (_lastRatingsLength != ratings.length || _cachedAverageRating == null) {
      _cachedAverageRating = _calculateAverage(ratings);
      _lastRatingsLength = ratings.length;
    }
    return _cachedAverageRating!;
  }

  // 총 평점 수
  int get totalRatings => ratings.length;

  // 최근 평점 수 (20개 제한 적용)
  static const RATING_LIMIT = 20; // 나중에 200으로 변경 가능

  int get recentRatingsCount =>
      ratings.length > RATING_LIMIT ? RATING_LIMIT : ratings.length;

  // 평균 평점 계산 (최근 20개만 사용)
  double calculateAverageRating() {
    if (ratings.isEmpty) return 0;

    final recentRatings = ratings.take(RATING_LIMIT).toList();
    return recentRatings.reduce((a, b) => a + b) / recentRatings.length;
  }

  Store({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.ratings,
    required this.cuisineTypes,
    required this.menus,
    this.distance,
    this.businessHours,
    this.happyHours,
    this.is24Hours = false,
  }) {
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

    return Store(
      id: json['storeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['location']?['latitude'] ?? 0.0).toDouble(),
      longitude: (json['location']?['longitude'] ?? 0.0).toDouble(),
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
      businessHours: json['businessHours'] != null
          ? BusinessHours.fromJson(json['businessHours'])
          : null,
      happyHours: (json['happyHours'] as List?)
          ?.map((hour) => HappyHour.fromJson(hour))
          .toList(),
      is24Hours: json['is24Hours'] ?? false,
    );
  }

  bool isCurrentlyOpen() {
    if (is24Hours) return true;
    if (businessHours == null) return false;
    return businessHours!.isCurrentlyOpen();
  }

  bool isHappyHourNow() {
    if (happyHours == null || happyHours!.isEmpty) return false;
    return happyHours!.any((hour) => hour.isHappyHourNow());
  }

  bool isOpenAt(DateTime dateTime) {
    if (is24Hours) return true;
    if (businessHours == null) return false;
    return businessHours!.isOpenAt(dateTime);
  }

  bool isHappyHourAt(DateTime dateTime) {
    if (happyHours == null || happyHours!.isEmpty) return false;
    return happyHours!.any((hour) => hour.isHappyHourAt(dateTime));
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
      itemId: json['itemId'],
      name: json['name'],
      price: json['price'].toDouble(),
      type: json['type'],
    );
  }
}

class BusinessHours {
  final int openHour;
  final int openMinute;
  final int closeHour;
  final int closeMinute;
  final bool isNextDay; // 마감시간이 다음날인 경우

  BusinessHours({
    required this.openHour,
    required this.openMinute,
    required this.closeHour,
    required this.closeMinute,
    this.isNextDay = false,
  });

  factory BusinessHours.fromJson(Map<String, dynamic> json) {
    return BusinessHours(
      openHour: json['openHour'],
      openMinute: json['openMinute'],
      closeHour: json['closeHour'],
      closeMinute: json['closeMinute'],
      isNextDay: json['isNextDay'] ?? false,
    );
  }

  bool isCurrentlyOpen() {
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;

    final currentTime = currentHour * 60 + currentMinute;
    final openTime = openHour * 60 + openMinute;
    final closeTime = closeHour * 60 + closeMinute;

    if (isNextDay) {
      if (currentTime >= openTime) return true;
      if (currentTime <= closeTime) return true;
      return false;
    } else {
      return currentTime >= openTime && currentTime <= closeTime;
    }
  }

  bool isOpenAt(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;

    final currentTime = hour * 60 + minute;
    final openTime = openHour * 60 + openMinute;
    final closeTime = closeHour * 60 + closeMinute;

    if (isNextDay) {
      if (currentTime >= openTime) return true;
      if (currentTime <= closeTime) return true;
      return false;
    } else {
      return currentTime >= openTime && currentTime <= closeTime;
    }
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
