class Store {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String category;
  double? distance;

  Store({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.distance,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['storeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: (json['location']?['latitude'] ?? 0.0).toDouble(),
      longitude: (json['location']?['longitude'] ?? 0.0).toDouble(),
      category: (json['category'] as List).join(','),
    );
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
