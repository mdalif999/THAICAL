import 'thai_color_set.dart';
import 'glass_brand.dart';
import 'hardware_price.dart';

class WindowCalculation {
  final List<Map<String, dynamic>> windowsList;
  final ThaiColorSet? selectedThaiColorSet; // window (3"/4") রেট
  final ThaiColorSet? selectedDoorColorSet; // single door রেট
  final GlassBrand? selectedGlassBrand;
  final GlassBrand? selectedDoorGlassBrand;
  final List<HardwarePrice> hardwarePrices;
  final int dlCount;
  final int swCount;
  final int scCount;
  final int snCount;
  final double hwRatePerSft;
  final double labor;
  final double advance;

  // Optional manual override values (শুধু window অংশের জন্য প্রযোজ্য)
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
    this.selectedDoorColorSet,
    required this.selectedGlassBrand,
    this.selectedDoorGlassBrand,
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

  List<Map<String, dynamic>> get _windowEntries =>
      windowsList.where((w) => (w['type'] ?? 'window') != 'door').toList();

  List<Map<String, dynamic>> get _doorEntries =>
      windowsList.where((w) => w['type'] == 'door').toList();

  // Calculate Sft for a single window (Width * Height / 144) * Qty
  static double calcSft(double w, double h, int qty) {
    return ((w * h) / 144.0) * qty;
  }

  // Calculate total Sft for all entries (window + door)
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

  // শুধু window entries এর Sft
  double calcWindowSft() {
    double total = 0.0;
    for (var w in _windowEntries) {
      total += calcSft(
        (w['w'] as num).toDouble(),
        (w['h'] as num).toDouble(),
        (w['qty'] as num).toInt(),
      );
    }
    return total;
  }

  // শুধু door entries এর Sft
  double calcDoorSft() {
    double total = 0.0;
    for (var d in _doorEntries) {
      total += calcSft(
        (d['w'] as num).toDouble(),
        (d['h'] as num).toDouble(),
        (d['qty'] as num).toInt(),
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

  // ── Window (sliding) cut inches — শুধু windowsList এর 'window' type entries ──
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

      for (var w in _windowEntries) {
        double width = (w['w'] as num).toDouble();
        double height = (w['h'] as num).toDouble();
        int qty = (w['qty'] as num).toInt();

        os += height * 2 * qty;
        ot += width * qty;
        ohb += width * qty;
        sl += height * 2 * qty;
        il += height * 2 * qty;
        st += width * qty;
        sb += width * qty;

        if (selectedThaiColorSet?.profileSize.contains('4') == true) {
          ns += (height * 2 + width) * qty;
          nh += 4.0 * qty;
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

  // ── Single Door cut inches — শুধু 'door' type entries ──
  // Outer Side = H, Outer Top = W, Low Bottom = W (ফ্রেম থেকে)
  // Shutter Lock = GateH×2, Shutter Top/Bottom = GateW (GateH = ফ্রেম H)
  // Box = GateH×2, Fitting Angle = 1f ফিক্সড প্রতি door
  Map<String, double> calcDoorCutInches() {
    double os = 0, ot = 0, ohb = 0, sl = 0, st = 0, sb = 0, box = 0, fittingAngle = 0;

    for (var d in _doorEntries) {
      double width = (d['w'] as num).toDouble();
      double height = (d['h'] as num).toDouble();
      int qty = (d['qty'] as num).toInt();
      double gateWidth = (d['gateWidth'] as num?)?.toDouble() ?? (width / 2);
      double gateHeight = height; // গেট উচ্চতা = ফ্রেম উচ্চতা

      os += height * 2 * qty;
      ot += width * qty;
      ohb += width * qty;

      sl += gateHeight * 2 * qty;
      st += gateWidth * qty;
      sb += gateWidth * qty;

      box += gateHeight * 2 * qty;
      fittingAngle += 12.0 * qty; // ফিক্সড ১ ফুট (১২ ইঞ্চি) প্রতি দরজা
    }

    return {
      'os': os, 'ot': ot, 'ohb': ohb,
      'sl': sl, 'st': st, 'sb': sb,
      'box': box, 'fittingAngle': fittingAngle,
    };
  }

  // Calculate total aluminum cost — window অংশ (existing profileSize রেট দিয়ে)
  int calcAluTotal() {
    if (selectedThaiColorSet == null || _windowEntries.isEmpty) return 0;
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

  // Calculate total aluminum cost — door অংশ (single_door রেট দিয়ে)
  int calcDoorAluTotal() {
    if (selectedDoorColorSet == null || _doorEntries.isEmpty) return 0;
    final cuts = calcDoorCutInches();
    final specInches = calcSpecLengthInches(selectedDoorColorSet!.specLength);
    final boxPrice = selectedDoorColorSet!.priceBox175 ?? 0;
    final fittingPrice = selectedDoorColorSet!.priceFittingAngle ?? 0;

    double total = inchToBars(cuts['os']!, specLengthInches: specInches) * selectedDoorColorSet!.priceOs +
        inchToBars(cuts['ot']!, specLengthInches: specInches) * selectedDoorColorSet!.priceOt +
        inchToBars(cuts['ohb']!, specLengthInches: specInches) * selectedDoorColorSet!.priceOhb +
        inchToBars(cuts['sl']!, specLengthInches: specInches) * selectedDoorColorSet!.priceSl +
        inchToBars(cuts['st']!, specLengthInches: specInches) * selectedDoorColorSet!.priceSt +
        inchToBars(cuts['sb']!, specLengthInches: specInches) * selectedDoorColorSet!.priceSb +
        inchToBars(cuts['box']!, specLengthInches: specInches) * boxPrice +
        inchToBars(cuts['fittingAngle']!, specLengthInches: specInches) * fittingPrice;

    return total.round();
  }

  // দুটোর মিলিত অ্যালুমিনিয়াম টোটাল (ডিসকাউন্টের আগে, calculator_screen এ ডিসকাউন্ট এপ্লাই হয়)
  int calcCombinedAluTotal() => calcAluTotal() + calcDoorAluTotal();

  // ── Window Hardware (আগের মতোই, শুধু window entries থেকে) ──
  static const double _baseSft = 22.5;

  List<Map<String, dynamic>> calcHardwareBreakdown() {
    final items = <Map<String, dynamic>>[];
    final is4Inch = selectedThaiColorSet?.profileSize.contains('4') == true;

    for (var w in _windowEntries) {
      final width = (w['w'] as num).toDouble();
      final height = (w['h'] as num).toDouble();
      final qty = (w['qty'] as num).toInt();
      final windowSft = width * height / 144.0;
      final ratio = windowSft / _baseSft;

      items.add({'name': 'স্লাইডিং লক', 'unit': 'পিস', 'qty': 2 * qty, 'rate': 125.0, 'cost': 250.0 * qty});
      items.add({'name': 'স্লাইডিং হুইল', 'unit': 'পিস', 'qty': 4 * qty, 'rate': 45.0, 'cost': 180.0 * qty});
      items.add({'name': 'সিলিকন গাম', 'unit': 'পিস', 'qty': ((qty + 3) ~/ 4), 'rate': 100.0, 'cost': ((qty + 3) ~/ 4) * 100.0});
      items.add({'name': 'রয়্যাল প্লাগ', 'unit': 'পিস', 'qty': (50 * ratio).ceil() * qty, 'rate': 0.2, 'cost': 10.0 * ratio * qty});

      final screwQty15 = (30 * ratio).ceil();
      items.add({'name': 'স্ক্রু ১.৫"', 'unit': 'পিস', 'qty': screwQty15 * qty, 'rate': 1.5, 'cost': 45.0 * ratio * qty});

      final screwQty05 = (10 * ratio).ceil();
      items.add({'name': 'স্ক্রু ০.৫"', 'unit': 'পিস', 'qty': screwQty05 * qty, 'rate': 0.8, 'cost': 8.0 * ratio * qty});

      final muhierFt = (12 * ratio).round();
      items.add({'name': 'মুহির', 'unit': 'ফুট', 'qty': muhierFt * qty, 'rate': 1.42, 'cost': 17.0 * ratio * qty});

      final rubberFt = (22.5 * ratio).round();
      items.add({'name': 'রাবার', 'unit': 'ফুট', 'qty': rubberFt * qty, 'rate': 2.0, 'cost': 45.0 * ratio * qty});

      if (is4Inch) {
        items.add({'name': 'নেট এঙ্গেল', 'unit': 'পিস', 'qty': 4 * qty, 'rate': 25.0, 'cost': 100.0 * qty});
        items.add({'name': 'নেট হুইল', 'unit': 'পিস', 'qty': 4 * qty, 'rate': 25.0, 'cost': 100.0 * qty});

        final netFt = (12 * ratio).round();
        items.add({'name': 'নেট', 'unit': 'ফুট', 'qty': netFt * qty, 'rate': 10.0, 'cost': 120.0 * ratio * qty});

        final rippitQty = (16 * ratio).ceil();
        items.add({'name': 'রিপ্পিট', 'unit': 'পিস', 'qty': rippitQty * qty, 'rate': 0.69, 'cost': 11.0 * ratio * qty});
      }
    }
    return _mergeItems(items);
  }

  // ── Door Hardware (ফিক্সড, per door — এডিটেবল রেট calculator_screen এ) ──
  List<Map<String, dynamic>> calcDoorHardwareBreakdown() {
    final items = <Map<String, dynamic>>[];

    for (var d in _doorEntries) {
      final qty = (d['qty'] as num).toInt();
      items.add({'name': 'S/L', 'unit': 'পিস', 'qty': 1 * qty, 'rate': 125.0, 'cost': 125.0 * qty});
      items.add({'name': 'Key/Lock', 'unit': 'পিস', 'qty': 1 * qty, 'rate': 350.0, 'cost': 350.0 * qty});
      items.add({'name': 'D/W', 'unit': 'পিস', 'qty': 2 * qty, 'rate': 60.0, 'cost': 120.0 * qty});
      items.add({'name': 'Rippit', 'unit': 'পিস', 'qty': 20 * qty, 'rate': 0.69, 'cost': 13.8 * qty});
      items.add({'name': 'S/R', 'unit': 'ফুট', 'qty': 50 * qty, 'rate': 2.0, 'cost': 100.0 * qty});
      items.add({'name': 'M/R', 'unit': 'ফুট', 'qty': 20 * qty, 'rate': 2.0, 'cost': 40.0 * qty});
    }
    return _mergeItems(items);
  }

  List<Map<String, dynamic>> _mergeItems(List<Map<String, dynamic>> items) {
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

  double calcHwTotal() {
    double total = 0;
    for (var item in calcHardwareBreakdown()) {
      total += (item['cost'] as double);
    }
    for (var item in calcDoorHardwareBreakdown()) {
      total += (item['cost'] as double);
    }
    return total;
  }

  // শুধু জানালার গ্লাস খরচ
  double calcWindowGlassTotal() {
    if (selectedGlassBrand == null) return 0;
    return calcWindowSft() * selectedGlassBrand!.pricePerSft;
  }

  // শুধু দরজার গ্লাস খরচ (ডোরের নিজস্ব গ্লাস সিলেক্ট না থাকলে জানালার গ্লাস রেট ব্যবহার হয়)
  double calcDoorGlassTotal() {
    final doorGlass = selectedDoorGlassBrand ?? selectedGlassBrand;
    if (doorGlass == null) return 0;
    return calcDoorSft() * doorGlass.pricePerSft;
  }

  // দরজার জন্য জানালার থেকে ভিন্ন গ্লাস সিলেক্ট করা হয়েছে কিনা
  bool get hasSeparateDoorGlass =>
      selectedDoorGlassBrand != null &&
      _doorEntries.isNotEmpty &&
      (selectedGlassBrand == null || selectedDoorGlassBrand!.brandName != selectedGlassBrand!.brandName);

  double calcGlassTotal() {
    return calcWindowGlassTotal() + calcDoorGlassTotal();
  }

  double calcGrandTotal() {
    return calcCombinedAluTotal() + calcGlassTotal() + calcHwTotal() + labor;
  }

  double calcDue() {
    return calcGrandTotal() - advance;
  }
}