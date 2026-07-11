import 'thai_color_set.dart';
import 'glass_brand.dart';
import 'hardware_price.dart';

class WindowCalculation {
  final List<Map<String, dynamic>> windowsList;
  final ThaiColorSet? selectedThaiColorSet;
  final GlassBrand? selectedGlassBrand;
  final List<HardwarePrice> hardwarePrices;
  final int dlCount;
  final int swCount;
  final int scCount;
  final int snCount;
  final double labor;
  final double advance;

  // Optional manual override values for the 7 profiles
  final double? overrideOs;
  final double? overrideOt;
  final double? overrideOhb;
  final double? overrideSl;
  final double? overrideIl;
  final double? overrideSt;
  final double? overrideSb;

  WindowCalculation({
    required this.windowsList,
    required this.selectedThaiColorSet,
    required this.selectedGlassBrand,
    required this.hardwarePrices,
    required this.dlCount,
    required this.swCount,
    required this.scCount,
    required this.snCount,
    required this.labor,
    required this.advance,
    this.overrideOs,
    this.overrideOt,
    this.overrideOhb,
    this.overrideSl,
    this.overrideIl,
    this.overrideSt,
    this.overrideSb,
  });

  // Helper to fetch price for hardware with safe hardcoded fallbacks
  int _getHwPrice(String key, int defaultPrice) {
    for (var hw in hardwarePrices) {
      if (hw.itemKey == key) {
        return hw.price;
      }
    }
    return defaultPrice;
  }

  // Calculate Sft for a single window (Width * Height / 144) * Qty
  static double calcSft(double w, double h, int qty) {
    return ((w * h) / 144.0) * qty;
  }

  // Calculate total Sft for all windows
  double calcTotalSft() {
    double total = 0.0;
    for (var w in windowsList) {
      total += calcSft(
        (w['w'] as num).toDouble(),
        (w['h'] as num).toDouble(),
        (w['qty'] as num).toInt(),
      );
    }
    return total;
  }

  // Convert inches of cut to bar count
  static double inchToBars(double inch) {
    return inch / 192.0;
  }

  // Calculate cut inches breakdown
  Map<String, double> calcCutInches() {
    if (overrideOs != null &&
        overrideOt != null &&
        overrideOhb != null &&
        overrideSl != null &&
        overrideIl != null &&
        overrideSt != null &&
        overrideSb != null) {
      return {
        'os': overrideOs!,
        'ot': overrideOt!,
        'ohb': overrideOhb!,
        'sl': overrideSl!,
        'il': overrideIl!,
        'st': overrideSt!,
        'sb': overrideSb!,
      };
    }

    double os = 0, ot = 0, ohb = 0, sl = 0, il = 0, st = 0, sb = 0;
    for (var w in windowsList) {
      double width = (w['w'] as num).toDouble();
      double height = (w['h'] as num).toDouble();
      int qty = (w['qty'] as num).toInt();
      os += height * 2 * qty;
      ot += width * qty;
      ohb += width * qty;
      sl += (height - 1.5) * 2 * qty;
      il += (height - 1.5) * 2 * qty;
      st += ((width - 1.5) / 2) * 2 * qty;
      sb += ((width - 1.5) / 2) * 2 * qty;
    }
    return {
      'os': os,
      'ot': ot,
      'ohb': ohb,
      'sl': sl,
      'il': il,
      'st': st,
      'sb': sb,
    };
  }

  // Calculate total aluminum cost based on color set pricing
  int calcAluTotal() {
    if (selectedThaiColorSet == null) return 0;
    final cuts = calcCutInches();
    return (inchToBars(cuts['os']!) * selectedThaiColorSet!.priceOs +
        inchToBars(cuts['ot']!) * selectedThaiColorSet!.priceOt +
        inchToBars(cuts['ohb']!) * selectedThaiColorSet!.priceOhb +
        inchToBars(cuts['sl']!) * selectedThaiColorSet!.priceSl +
        inchToBars(cuts['il']!) * selectedThaiColorSet!.priceIl +
        inchToBars(cuts['st']!) * selectedThaiColorSet!.priceSt +
        inchToBars(cuts['sb']!) * selectedThaiColorSet!.priceSb).round();
  }

  // Calculate total hardware accessories cost
  int calcHwTotal() {
    final lockPrice = _getHwPrice('sliding_lock', 220);
    final wheelPrice = _getHwPrice('sliding_wheel', 45);
    final screwPrice = _getHwPrice('screw_pack', 150);
    final rubberPrice = _getHwPrice('rubber_pad', 10);

    return dlCount * lockPrice +
        swCount * wheelPrice +
        scCount * screwPrice +
        snCount * rubberPrice;
  }

  // Calculate total glass cost based on glass brand Sft rate
  double calcGlassTotal() {
    if (selectedGlassBrand == null) return 0;
    return calcTotalSft() * selectedGlassBrand!.pricePerSft;
  }

  // Calculate grand total cost
  double calcGrandTotal() {
    return calcAluTotal() + calcGlassTotal() + calcHwTotal() + labor;
  }

  // Calculate remaining due amount
  double calcDue() {
    return calcGrandTotal() - advance;
  }
}
