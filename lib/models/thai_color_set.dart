class ThaiColorSet {
  final int id;
  final String brand;
  final String color;
  final double thick;
  final String specLength;
  final int priceOs;
  final int priceOt;
  final int priceOhb;
  final int priceSl;
  final int priceIl;
  final int priceSt;
  final int priceSb;

  ThaiColorSet({
    required this.id,
    required this.brand,
    required this.color,
    required this.thick,
    required this.specLength,
    required this.priceOs,
    required this.priceOt,
    required this.priceOhb,
    required this.priceSl,
    required this.priceIl,
    required this.priceSt,
    required this.priceSb,
  });

  factory ThaiColorSet.fromJson(Map<String, dynamic> json) {
    return ThaiColorSet(
      id: json['id'] as int? ?? 0,
      brand: json['brand']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      thick: (json['thick'] as num?)?.toDouble() ?? 1.2,
      specLength: json['spec_length']?.toString() ?? "21'-0\"",
      priceOs: json['price_os'] as int? ?? 0,
      priceOt: json['price_ot'] as int? ?? 0,
      priceOhb: json['price_ohb'] as int? ?? 0,
      priceSl: json['price_sl'] as int? ?? 0,
      priceIl: json['price_il'] as int? ?? 0,
      priceSt: json['price_st'] as int? ?? 0,
      priceSb: json['price_sb'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'color': color,
      'thick': thick,
      'spec_length': specLength,
      'price_os': priceOs,
      'price_ot': priceOt,
      'price_ohb': priceOhb,
      'price_sl': priceSl,
      'price_il': priceIl,
      'price_st': priceSt,
      'price_sb': priceSb,
    };
  }
}
