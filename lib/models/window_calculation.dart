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

  // Parse specLength string (e.g. "21'-0\"") to total inches
  static double calcSpecLengthInches(String? specLength) {
    if (specLength == null || specLength.isEmpty) return 252.0;
    try {
      final feetMatch = RegExp(r"(\d+)'\s*-?\s*(\d+)?").firstMatch(specLength);
      if (feetMatch != null) {
        final feet = int.parse(feetMatch.group(1)!);
        final inches = int.tryParse(feetMatch.group(2) ?? '0') ?? 0;
        return (feet * 12 + inches).toDouble();
      }
      final plain = double.tryParse(specLength.replaceAll(RegExp(r'[^\d.]'), ''));
      if (plain != null) return plain;
    } catch (_) {}
    return 252.0;
  }

  // Convert inches of cut to bar count
  static double inchToBars(double inch, {double? specLengthInches}) {
    return inch / (specLengthInches ?? 252.0);
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
    final specInches = calcSpecLengthInches(selectedThaiColorSet!.specLength);
    double total = (inchToBars(cuts['os']!, specLengthInches: specInches) * selectedThaiColorSet!.priceOs +
        inchToBars(cuts['ot']!, specLengthInches: specInches) * selectedThaiColorSet!.priceOt +
        inchToBars(cuts['ohb']!, specLengthInches: specInches) * selectedThaiColorSet!.priceOhb +
        inchToBars(cuts['sl']!, specLengthInches: specInches) * selectedThaiColorSet!.priceSl +
        inchToBars(cuts['il']!, specLengthInches: specInches) * selectedThaiColorSet!.priceIl +
        inchToBars(cuts['st']!) * selectedThaiColorSet!.priceSt +
        inchToBars(cuts['sb']!) * selectedThaiColorSet!.priceSb);

    if (selectedThaiColorSet!.profileSize.contains('4')) {
      final nsPrice = selectedThaiColorSet!.priceNs ?? 0;
      final nbPrice = selectedThaiColorSet!.priceNb ?? 0;
      total += inchToBars(cuts['ns']!) * nsPrice + inchToBars(cuts['nh']!) * nbPrice;
    }
    return total.round();
  }

  // ── নতুন Hardware Calculation: per-window itemized system ──
  // Base window = 4.5' × 5' = 22.5 sft
  static const double _baseSft = 22.5;

  /// Returns detailed hardware items list with qty, rate, cost for each window
  List<Map<String, dynamic>> calcHardwareBreakdown() {
    final items = <Map<String, dynamic>>[];
    final is4Inch = selectedThaiColorSet?.profileSize.contains('4') == true;

    for (var w in windowsList) {
      final width = (w['w'] as num).toDouble();
      final height = (w['h'] as num).toDouble();
      final qty = (w['qty'] as num).toInt();
      final windowSft = width * height / 144.0;
      final ratio = windowSft / _baseSft;

      // ── ৩'' Fixed items (per window) ──
      items.add({'name': 'স্লাইডিং লক', 'unit': 'পিস', 'qty': 2 * qty, 'rate': 125.0, 'cost': 250.0 * qty});
      items.add({'name': 'স্লাইডিং হুইল', 'unit': 'পিস', 'qty': 4 * qty, 'rate': 45.0, 'cost': 180.0 * qty});
      items.add({'name': 'রয়্যাল প্লাগ', 'unit': 'পিস', 'qty': (50 * ratio).ceil() * qty, 'rate': 0.2, 'cost': 10.0 * ratio * qty});

      // ── ৩'' Scalable items (ratio based) ──
      final screwQty15 = (30 * ratio).ceil();
      items.add({'name': 'স্ক্রু ১.৫"', 'unit': 'পিস', 'qty': screwQty15 * qty, 'rate': 1.5, 'cost': 45.0 * ratio * qty});

      final screwQty05 = (10 * ratio).ceil();
      items.add({'name': 'স্ক্রু ০.৫"', 'unit': 'পিস', 'qty': screwQty05 * qty, 'rate': 0.8, 'cost': 8.0 * ratio * qty});

      final muhierFt = (12 * ratio).round();
      items.add({'name': 'মুহির', 'unit': 'ফুট', 'qty': muhierFt * qty, 'rate': 1.42, 'cost': 17.0 * ratio * qty});

      final rubberFt = (22.5 * ratio).round();
      items.add({'name': 'রাবার', 'unit': 'ফুট', 'qty': rubberFt * qty, 'rate': 2.0, 'cost': 45.0 * ratio * qty});

      // ── ৪'' Extra items (on top of ৩'') ──
      if (is4Inch) {
        items.add({'name': 'নেট এঙ্গেল', 'unit': 'পিস', 'qty': 4 * qty, 'rate': 25.0, 'cost': 100.0 * qty});
        items.add({'name': 'নেট হুইল', 'unit': 'পিস', 'qty': 4 * qty, 'rate': 25.0, 'cost': 100.0 * qty});

        final netFt = (12 * ratio).round();
        items.add({'name': 'নেট', 'unit': 'ফুট', 'qty': netFt * qty, 'rate': 10.0, 'cost': 120.0 * ratio * qty});

        final rippitQty = (16 * ratio).ceil();
        items.add({'name': 'রিপ্পিট', 'unit': 'পিস', 'qty': rippitQty * qty, 'rate': 0.69, 'cost': 11.0 * ratio * qty});
      }
    }
    // Same name er items ke merge koro (multiple window er qty/cost jog)
    final merged = <String, Map<String, dynamic>>{};
    for (var item in items) {
      final name = item['name'] as String;
      if (merged.containsKey(name)) {
        merged[name]!['qty'] = (merged[name]!['qty'] as int) + (item['qty'] as int);
        merged[name]!['cost'] = (merged[name]!['cost'] as double) + (item['cost'] as double);
      } else {
        merged[name] = Map<String, dynamic>.from(item);
      }
    }
    return merged.values.toList();
  }

  /// Total hardware cost from detailed breakdown
  double calcHwTotal() {
    final items = calcHardwareBreakdown();
    double total = 0;
    for (var item in items) {
      total += (item['cost'] as double);
    }
    return total;
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