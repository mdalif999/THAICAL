class ThaiBrand {
  final int id;
  final String brandName;
  final int osPrice;
  final int otPrice;
  final int obPrice;
  final int slPrice;
  final int ilPrice;
  final int stPrice;
  final int sbPrice;
  final int dlPrice;
  final int swPrice;

  ThaiBrand({
    required this.id,
    required this.brandName,
    required this.osPrice,
    required this.otPrice,
    required this.obPrice,
    required this.slPrice,
    required this.ilPrice,
    required this.stPrice,
    required this.sbPrice,
    required this.dlPrice,
    required this.swPrice,
  });

  factory ThaiBrand.fromJson(Map<String, dynamic> json) {
    return ThaiBrand(
      id: json['id'] as int? ?? 0,
      brandName: json['brand_name']?.toString() ?? '',
      osPrice: json['os_price'] as int? ?? 0,
      otPrice: json['ot_price'] as int? ?? 0,
      obPrice: json['ob_price'] as int? ?? 0,
      slPrice: json['sl_price'] as int? ?? 0,
      ilPrice: json['il_price'] as int? ?? 0,
      stPrice: json['st_price'] as int? ?? 0,
      sbPrice: json['sb_price'] as int? ?? 0,
      dlPrice: json['dl_price'] as int? ?? 0,
      swPrice: json['sw_price'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand_name': brandName,
      'os_price': osPrice,
      'ot_price': otPrice,
      'ob_price': obPrice,
      'sl_price': slPrice,
      'il_price': ilPrice,
      'st_price': stPrice,
      'sb_price': sbPrice,
      'dl_price': dlPrice,
      'sw_price': swPrice,
    };
  }

  // Helper method to access values dynamically by key matching calculator fields
  int getPriceByKey(String key) {
    switch (key) {
      case 'OS_price': return osPrice;
      case 'OT_price': return otPrice;
      case 'OB_price': return obPrice;
      case 'SL_price': return slPrice;
      case 'IL_price': return ilPrice;
      case 'ST_price': return stPrice;
      case 'SB_price': return sbPrice;
      case 'DL_price': return dlPrice;
      case 'SW_price': return swPrice;
      default: return 0;
    }
  }
}
