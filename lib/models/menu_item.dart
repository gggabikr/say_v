import 'discount_info.dart';

class MenuItem {
  final String itemId;
  final String name;
  final double price;
  final String type;
  final DiscountInfo? discount;

  MenuItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.type,
    this.discount,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      itemId: json['itemId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      type: json['type']?.toString() ?? 'default',
      discount: json['discount'] != null
          ? DiscountInfo.fromJson(json['discount'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'price': price,
      'type': type,
      'discount': discount?.toJson(),
    };
  }
}
