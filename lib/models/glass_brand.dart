class GlassBrand {
  final int id;
  final String brandName;
  final int pricePerSft;

  GlassBrand({
    required this.id,
    required this.brandName,
    required this.pricePerSft,
  });

  factory GlassBrand.fromJson(Map<String, dynamic> json) {
    return GlassBrand(
      id: json['id'] as int? ?? 0,
      brandName: json['brand_name']?.toString() ?? '',
      pricePerSft: json['price_per_sft'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand_name': brandName,
      'price_per_sft': pricePerSft,
    };
  }
}
