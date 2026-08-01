class ThaiColorSet {
  final int id;
  final String brand;
  final String color;
  final String profileSize;
  final String specLength;
  final String model;
  final int priceOs;
  final int priceOt;
  final int priceOhb;
  final int priceSl;
  final int priceIl;
  final int priceSt;
  final int priceSb;
  final int? priceNs;
  final int? priceNb;
  final int? priceBox175;
  final int? priceFittingAngle;

  ThaiColorSet({
    required this.id,
    required this.brand,
    required this.color,
    required this.profileSize,
    required this.specLength,
    this.model = 'general',
    required this.priceOs,
    required this.priceOt,
    required this.priceOhb,
    required this.priceSl,
    required this.priceIl,
    required this.priceSt,
    required this.priceSb,
    this.priceNs,
    this.priceNb,
    this.priceBox175,
    this.priceFittingAngle,
  });

  factory ThaiColorSet.fromJson(Map<String, dynamic> json) {
    return ThaiColorSet(
      id: json['id'] as int? ?? 0,
      brand: json['brand']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
      profileSize: json['profile_size']?.toString() ?? (json['thick'] != null ? '${json['thick']} mm' : '3"'),
      specLength: json['spec_length']?.toString() ?? "21'-0\"",
      model: json['model']?.toString() ?? 'general',
      priceOs: json['price_os'] as int? ?? 0,
      priceOt: json['price_ot'] as int? ?? 0,
      priceOhb: json['price_ohb'] as int? ?? 0,
      priceSl: json['price_sl'] as int? ?? 0,
      priceIl: json['price_il'] as int? ?? 0,
      priceSt: json['price_st'] as int? ?? 0,
      priceSb: json['price_sb'] as int? ?? 0,
      priceNs: json['price_ns'] as int?,
      priceNb: json['price_nb'] as int?,
      priceBox175: json['price_box_175'] as int?,
      priceFittingAngle: json['price_fitting_angle'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'color': color,
      'profile_size': profileSize,
      'spec_length': specLength,
      'model': model,
      'price_os': priceOs,
      'price_ot': priceOt,
      'price_ohb': priceOhb,
      'price_sl': priceSl,
      'price_il': priceIl,
      'price_st': priceSt,
      'price_sb': priceSb,
      'price_ns': priceNs,
      'price_nb': priceNb,
      'price_box_175': priceBox175,
      'price_fitting_angle': priceFittingAngle,
    };
  }
}