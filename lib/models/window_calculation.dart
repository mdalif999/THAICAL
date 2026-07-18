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
  final double hwRatePerSft;
  final double labor;
  final double advance;

  // Optional manual override values for the profiles
  final double? overrideOs;
  final double? overrideOt;
  final double? overrideOhb;
  final double? overrideSl;
  final double? overrideIl;
  final double? overrideSt;
  final double? overrideSb;
  final double? overrideNs;
  final double? overrideNh;

  WindowCalculation({
    required this.windowsList,
    required this.selectedThaiColorSet,
    required this.selectedGlassBrand,
    required this.hardwarePrices,
    required this.dlCount,
    required this.swCount,
    required this.scCount,
    required this.snCount,
    required this.hwRatePerSft,
    required this.labor,
    required this.advance,
    this.overrideOs,
    this.overrideOt,
    this.overrideOhb,
    this.overrideSl,
    this.overrideIl,
    this.overrideSt,
    this.overrideSb,
    this.overrideNs,
    this.overrideNh,
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

  // Calculate cut inches breakdown (মিস্ত্রিদের খাঁটি বাংলাদেশি প্র্যাক্টিক্যাল হিসাব)
  Map<String, double> calcCutInches() {
    double os = overrideOs ?? 0;
    double ot = overrideOt ?? 0;
    double ohb = overrideOhb ?? 0;
    double sl = overrideSl ?? 0;
    double il = overrideIl ?? 0;
    double st = overrideSt ?? 0;
    double sb = overrideSb ?? 0;
    double ns = overrideNs ?? 0;
    double nh = overrideNh ?? 0;

    if (overrideOs == null ||
        overrideOt == null ||
        overrideOhb == null ||
        overrideSl == null ||
        overrideIl == null ||
        overrideSt == null ||
        overrideSb == null ||
        (selectedThaiColorSet?.profileSize.contains('4') == true && (overrideNs == null || overrideNh == null))) {
      os = 0; ot = 0; ohb = 0; sl = 0; il = 0; st = 0; sb = 0;
      ns = 0; nh = 0;
      
      for (var w in windowsList) {
        double width = (w['w'] as num).toDouble();
        double height = (w['h'] as num).toDouble();
        int qty = (w['qty'] as num).toInt();
        
        // ৫বাই৫ জানালার জন্য ১২০ ইঞ্চি হিসাব (উচ্চতা * ২ টা খাড়া)
        os += height * 2 * qty;
        
        // ৫বাই৫ জানালার জন্য ৬০ ইঞ্চি হিসাব (১ টা করে আড়াআড়ি আউটার ফ্রেম)
        ot += width * qty;
        ohb += width * qty;
        
        // পাল্লা লক ও ইন্টারলক ডিরেক্ট ১২০ ইঞ্চি (কোনো মাইনাস ছাড়া)
        sl += height * 2 * qty;
        il += height * 2 * qty;
        
        // পাল্লা টপ ও বটম ডিরেক্ট ৬০ ইঞ্চি
        st += width * qty;
        sb += width * qty;

        // ৪ ইঞ্চি ফ্রেম হলে মশার নেটের ৩ সাইডের ১৮০ ইঞ্চি এবং ৪ ইঞ্চি করে নেট হ্যান্ডেলের বার কাটিং
        if (selectedThaiColorSet?.profileSize.contains('4') == true) {
          ns += (height * 2 + width) * qty; // ৬০*২ + ৬০ = ১৮০ ইঞ্চি
          nh += 4.0 * qty; // প্রতি জানালায় ৪ ইঞ্চি বারের খরচ যোগ হবে
        }
      }
    }
    return {
      'os': overrideOs ?? os,
      'ot': overrideOt ?? ot,
      'ohb': overrideOhb ?? ohb,
      'sl': overrideSl ?? sl,
      'il': overrideIl ?? il,
      'st': overrideSt ?? st,
      'sb': overrideSb ?? sb,
      'ns': overrideNs ?? ns,
      'nh': overrideNh ?? nh,
    };
  }

  // Calculate total aluminum cost based on color set pricing
  int calcAluTotal() {
    if (selectedThaiColorSet == null) return 0;
    final cuts = calcCutInches();
    double total = (inchToBars(cuts['os']!) * selectedThaiColorSet!.priceOs +
        inchToBars(cuts['ot']!) * selectedThaiColorSet!.priceOt +
        inchToBars(cuts['ohb']!) * selectedThaiColorSet!.priceOhb +
        inchToBars(cuts['sl']!) * selectedThaiColorSet!.priceSl +
        inchToBars(cuts['il']!) * selectedThaiColorSet!.priceIl +
        inchToBars(cuts['st']!) * selectedThaiColorSet!.priceSt +
        inchToBars(cuts['sb']!) * selectedThaiColorSet!.priceSb);

    if (selectedThaiColorSet!.profileSize.contains('4')) {
      final nsPrice = selectedThaiColorSet!.priceNs ?? 0;
      final nbPrice = selectedThaiColorSet!.priceNb ?? 0;
      total += inchToBars(cuts['ns']!) * nsPrice + inchToBars(cuts['nh']!) * nbPrice;
    }
    return total.round();
  }

  // Calculate total hardware cost — sqft ভিত্তিক rate, override করা যায়
  double calcHwTotal() {
    return calcTotalSft() * hwRatePerSft;
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