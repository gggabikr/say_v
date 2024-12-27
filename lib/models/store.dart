class Store {
  final String storeId;
  final String name;
  final List<String> category;
  final Location location;
  final List<MenuItem> menus;

  Store({
    required this.storeId,
    required this.name,
    required this.category,
    required this.location,
    required this.menus,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeId: json['storeId'],
      name: json['name'],
      category: List<String>.from(json['category']),
      location: Location.fromJson(json['location']),
      menus: (json['menus'] as List)
          .map((menu) => MenuItem.fromJson(menu))
          .toList(),
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
