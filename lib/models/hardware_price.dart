class HardwarePrice {
  final int id;
  final String itemKey;
  final String itemName;
  final int price;

  HardwarePrice({
    required this.id,
    required this.itemKey,
    required this.itemName,
    required this.price,
  });

  factory HardwarePrice.fromJson(Map<String, dynamic> json) {
    return HardwarePrice(
      id: json['id'] as int? ?? 0,
      itemKey: json['item_key']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      price: json['price'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item_key': itemKey,
      'item_name': itemName,
      'price': price,
    };
  }
}
