enum DiscountType {
  fixedAmount, // 정액 할인
  percentage, // 비율 할인
  bundle, // 묶음 할인
  buyOneGetOne, // 1+1
  event, // 이벤트
}

class DiscountInfo {
  final DiscountType type;
  final double? discountedPrice;
  final double? discountPercentage;
  final int? bundleQuantity;
  final int? freeQuantity;
  final String description;
  final bool isHappyHour;

  DiscountInfo({
    required this.type,
    this.discountedPrice,
    this.discountPercentage,
    this.bundleQuantity,
    this.freeQuantity,
    required this.description,
    this.isHappyHour = false,
  });

  Map<String, dynamic> toJson() => {
        'type': type.toString().split('.').last,
        'discountedPrice': discountedPrice,
        'discountPercentage': discountPercentage,
        'bundleQuantity': bundleQuantity,
        'freeQuantity': freeQuantity,
        'description': description,
        'isHappyHour': isHappyHour,
      };

  factory DiscountInfo.fromJson(Map<String, dynamic> json) {
    return DiscountInfo(
      type: DiscountType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
      ),
      discountedPrice: json['discountedPrice'] != null
          ? (json['discountedPrice'] as num).toDouble()
          : null,
      discountPercentage: json['discountPercentage'] != null
          ? (json['discountPercentage'] as num).toDouble()
          : null,
      bundleQuantity: json['bundleQuantity'],
      freeQuantity: json['freeQuantity'],
      description: json['description'] ?? '',
      isHappyHour: json['isHappyHour'] ?? false,
    );
  }
}
