import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/thai_color_set.dart';
import '../models/glass_brand.dart';
import '../models/hardware_price.dart';
import '../models/window_calculation.dart';
import '../services/database_service.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent = Color(0xFF00D4AA);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);
  static const Color cGreen = Color(0xFF22C55E);
  static const Color cRed = Color(0xFFEF4444);
  static const Color cYellow = Color(0xFFF59E0B);
  static const Color cWhatsApp = Color(0xFF25D366);

  // Database configurations
  List<ThaiColorSet> _thaiColorSets = [];
  List<GlassBrand> _glassBrands = [];
  List<HardwarePrice> _hardwarePrices = [];
  
  ThaiColorSet? _selectedThaiColorSet;
  GlassBrand? _selectedGlassBrand;
  
  // Cascading dropdown values
  String? _selectedBrandName;
  String? _selectedColorName;
  String? _selectedProfileSize;

  String? _selectedModel; // অথবা String _selectedModel = '';
  String? _selectedDoorBrandName;
  String? _selectedDoorColorName;
  double _doorBrandDiscount = 0;
  GlassBrand? _selectedDoorGlassBrand;

  bool _isLoadingBrands = true;
  double _brandDiscount = 0;
  Map<String, double> _allBrandDiscounts = {};
  List<String> _selectedBrands = [];
  bool _showBrandFilter = false;

  int _currentStep = 1;
  final List<Map<String, dynamic>> _windowsList = [];

  final _winNameController = TextEditingController(text: "Window 1");
  final _winWidthController = TextEditingController(text: "84");
  final _winHeightController = TextEditingController(text: "72");
  final _winQtyController = TextEditingController(text: "1");

  // ── Single Door এর জন্য নতুন ──
  String _addEntryType = 'window'; // 'window' অথবা 'door'
  final _gateWidthController = TextEditingController();
  bool _gateWidthTouched = false;

  final _osController = TextEditingController();
  final _otController = TextEditingController();
  final _ohbController = TextEditingController();
  final _slController = TextEditingController();
  final _ilController = TextEditingController();
  final _stController = TextEditingController();
  final _sbController = TextEditingController();
  final _nsController = TextEditingController();
  final _nhController = TextEditingController();

  int _dlCount = 0;
  int _swCount = 0;
  int _scCount = 0;
  int _snCount = 0;
  final _hwRateController = TextEditingController(text: "25");

  final _laborController = TextEditingController(text: "0");
  final _laborRateController = TextEditingController(text: "25");
  final _fareController = TextEditingController(text: "0");
  final _advanceController = TextEditingController(text: "0");

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final Map<String, double> _customHwRates = {};
  Map<String, double> _customGlassRates = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _winWidthController.addListener(_autoFillGateWidth);
  }

  void _autoFillGateWidth() {
    if (_addEntryType == 'door' && !_gateWidthTouched) {
      final w = double.tryParse(_winWidthController.text);
      if (w != null) {
        _gateWidthController.text = (w / 2).toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _winNameController.dispose();
    _winWidthController.dispose();
    _winHeightController.dispose();
    _winQtyController.dispose();
    _gateWidthController.dispose();

    _osController.dispose();
    _otController.dispose();
    _ohbController.dispose();
    _slController.dispose();
    _ilController.dispose();
    _stController.dispose();
    _sbController.dispose();
    _nsController.dispose();
    _nhController.dispose();
    _laborController.dispose();
    _laborRateController.dispose();
    _fareController.dispose();
    _advanceController.dispose();
    _hwRateController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    setState(() => _isLoadingBrands = true);
    try {
      final thais = await DatabaseService.instance.getThaiColorSets();
      final glasses = await DatabaseService.instance.getGlassBrands();
      final hardwares = await DatabaseService.instance.getHardwarePrices();
      final discounts = await DatabaseService.instance.getBrandDiscounts();
      final savedBrands = await DatabaseService.instance.getSelectedBrands();
      final glassRates = await DatabaseService.instance.getGlassRates();

      setState(() {
        _thaiColorSets = thais;
        _glassBrands = glasses;
        _hardwarePrices = hardwares;
        _allBrandDiscounts = discounts;
        _selectedBrands = savedBrands;
        _customGlassRates = glassRates;

        if (glasses.isNotEmpty) {
          _selectedGlassBrand = glasses.first;
        }

        if (thais.isNotEmpty) {
          final allModels = thais.map((e) => e.model).toSet().toList();
          _selectedModel = allModels.contains('general') ? 'general' : allModels.first;

          final allBrands = thais
              .where((e) => e.model == _selectedModel)
              .map((e) => e.brand)
              .toSet()
              .toList();
          final filteredBrands = _selectedBrands.isEmpty
              ? allBrands
              : allBrands.where((b) => _selectedBrands.contains(b)).toList();
          _selectedBrandName = filteredBrands.isNotEmpty ? filteredBrands.first : (allBrands.isNotEmpty ? allBrands.first : null);
          _brandDiscount = _selectedBrandName != null ? (discounts[_selectedBrandName!] ?? 0) : 0;
          if (_selectedBrandName != null) _updateColorsForBrand();

          final doorBrands = thais
              .where((e) => e.model == _selectedModel && e.profileSize == 'single_door')
              .map((e) => e.brand)
              .toSet()
              .toList();
          if (doorBrands.isNotEmpty) {
            _selectedDoorBrandName = doorBrands.first;
            final doorColors = thais
                .where((e) => e.model == _selectedModel && e.brand == _selectedDoorBrandName && e.profileSize == 'single_door')
                .map((e) => e.color)
                .toSet()
                .toList();
            _selectedDoorColorName = doorColors.isNotEmpty ? doorColors.first : null;
            _doorBrandDiscount = _selectedDoorBrandName != null ? (discounts['door_${_selectedDoorBrandName!}'] ?? 0) : 0;
          }
        }
        _isLoadingBrands = false;
      });
    } catch (e) {
      setState(() => _isLoadingBrands = false);
    }
  }

  void _updateColorsForBrand() {
    if (_selectedBrandName == null || _thaiColorSets.isEmpty) return;

    final colors = _thaiColorSets
        .where((e) => e.model == _selectedModel && e.brand == _selectedBrandName)
        .map((e) => e.color)
        .toSet()
        .toList();

    setState(() {
      _selectedColorName = colors.isNotEmpty ? colors.first : null;
      _brandDiscount = _allBrandDiscounts[_selectedBrandName!] ?? 0;
      _updateProfileSizesForColor();
    });
  }

  Future<void> _showStep1DiscountDialog() async {
    if (_selectedBrandName == null) return;
    final brand = _selectedBrandName!;
    final controller = TextEditingController(
        text: _brandDiscount > 0 ? _brandDiscount.toString() : '');

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: cBorder),
        ),
        title: Text(
          "ডিসকাউন্ট সেট করুন",
          style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "ব্র্যান্ড: $brand",
              style: GoogleFonts.hindSiliguri(color: cAccent, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(color: cText, fontSize: 16),
              decoration: InputDecoration(
                labelText: "ডিসকাউন্ট (%)",
                labelStyle: GoogleFonts.hindSiliguri(color: cMuted),
                suffixText: "%",
                suffixStyle: GoogleFonts.inter(color: cAccent, fontSize: 16, fontWeight: FontWeight.bold),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cAccent)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "0 = কোনো ডিসকাউন্ট নেই (0-100%)",
              style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("বাতিল", style: GoogleFonts.hindSiliguri(color: cMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = (double.tryParse(controller.text) ?? 0).clamp(0.0, 100.0);
              Navigator.pop(ctx, val);
            },
            style: ElevatedButton.styleFrom(backgroundColor: cAccent),
            child: Text("সেভ করুন", style: GoogleFonts.hindSiliguri(color: cBg, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await DatabaseService.instance.saveBrandDiscount(brand, result);
      setState(() {
        _brandDiscount = result;
        _allBrandDiscounts[brand] = result;
      });
    }
    Future.delayed(const Duration(milliseconds: 300), () => controller.dispose());
  }

  Future<void> _showDoorDiscountDialog() async {
    if (_selectedDoorBrandName == null) return;
    final brand = _selectedDoorBrandName!;
    final controller = TextEditingController(
        text: _doorBrandDiscount > 0 ? _doorBrandDiscount.toString() : '');

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: cBorder),
        ),
        title: Text(
          "সিঙ্গেল ডোর ডিসকাউন্ট",
          style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "ব্র্যান্ড: $brand",
              style: GoogleFonts.hindSiliguri(color: cAccent2, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(color: cText, fontSize: 16),
              decoration: InputDecoration(
                labelText: "ডিসকাউন্ট (%)",
                labelStyle: GoogleFonts.hindSiliguri(color: cMuted),
                suffixText: "%",
                suffixStyle: GoogleFonts.inter(color: cAccent2, fontSize: 16, fontWeight: FontWeight.bold),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cAccent2)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("বাতিল", style: GoogleFonts.hindSiliguri(color: cMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = (double.tryParse(controller.text) ?? 0).clamp(0.0, 100.0);
              Navigator.pop(ctx, val);
            },
            style: ElevatedButton.styleFrom(backgroundColor: cAccent2),
            child: Text("সেভ করুন", style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await DatabaseService.instance.saveBrandDiscount('door_$brand', result);
      setState(() {
        _doorBrandDiscount = result;
        _allBrandDiscounts['door_$brand'] = result;
      });
    }
    Future.delayed(const Duration(milliseconds: 300), () => controller.dispose());
  }

  GlassBrand? _getActiveDoorGlassBrand() {
    final glass = _selectedDoorGlassBrand;
    if (glass == null) return null;
    final rate = _customGlassRates[glass.brandName] ?? glass.pricePerSft.toDouble();
    return GlassBrand(id: glass.id, brandName: glass.brandName, pricePerSft: rate.round());
  }

  ThaiColorSet? _getDoorColorSet() {
    try {
      return _thaiColorSets.firstWhere((e) =>
          e.model == _selectedModel &&
          e.brand == _selectedDoorBrandName &&
          e.color == _selectedDoorColorName &&
          e.profileSize == 'single_door');
    } catch (_) {
      return null;
    }
  }

  GlassBrand? _getActiveGlassBrand() {
    if (_selectedGlassBrand == null) return null;
    final rate = _customGlassRates[_selectedGlassBrand!.brandName] ?? _selectedGlassBrand!.pricePerSft.toDouble();
    return GlassBrand(
      id: _selectedGlassBrand!.id,
      brandName: _selectedGlassBrand!.brandName,
      pricePerSft: rate.round(),
    );
  }

  Future<void> _showGlassRateDialog() async {
    if (_selectedGlassBrand == null) return;
    final glass = _selectedGlassBrand!;
    final currentRate = _customGlassRates[glass.brandName] ?? glass.pricePerSft.toDouble();
    final controller = TextEditingController(text: currentRate.toStringAsFixed(0));

    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: cBorder),
        ),
        title: Text(
          "গ্লাস রেট সেট করুন",
          style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ব্র্যান্ড/টাইপ: ${glass.brandName}",
              style: GoogleFonts.hindSiliguri(color: cAccent, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "মূল দর (প্রাইস লিস্ট): ৳${_fmtTk(glass.pricePerSft.toDouble())} / Sft",
              style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: GoogleFonts.inter(color: cText, fontSize: 16),
              decoration: InputDecoration(
                labelText: "দর / Sft (Tk)",
                labelStyle: GoogleFonts.hindSiliguri(color: cMuted),
                suffixText: "Tk",
                suffixStyle: GoogleFonts.inter(color: cAccent, fontSize: 16, fontWeight: FontWeight.bold),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: cAccent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, -1.0),
            child: Text("রিসেট করুন", style: GoogleFonts.hindSiliguri(color: cRed)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("বাতিল", style: GoogleFonts.hindSiliguri(color: cMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx, val);
            },
            style: ElevatedButton.styleFrom(backgroundColor: cAccent),
            child: Text("সেভ করুন", style: GoogleFonts.hindSiliguri(color: cBg, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      if (result == -1.0) {
        await DatabaseService.instance.removeGlassRate(glass.brandName);
        setState(() {
          _customGlassRates.remove(glass.brandName);
        });
      } else {
        await DatabaseService.instance.saveGlassRate(glass.brandName, result);
        setState(() {
          _customGlassRates[glass.brandName] = result;
        });
      }
    }
    Future.delayed(const Duration(milliseconds: 300), () => controller.dispose());
  }

  Future<void> _showBrandFilterDialog() async {
    final allBrands = _thaiColorSets.map((e) => e.brand).toSet().toList();
    final tempSelected = Set<String>.from(_selectedBrands);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: cBorder),
          ),
          title: Text(
            "ব্র্যান্ড সিলেক্ট করুন",
            style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "যেসব ব্র্যান্ড নিয়ে কাজ করবেন সেগুলো সিলেক্ট করুন।",
                style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        if (tempSelected.length == allBrands.length) {
                          tempSelected.clear();
                        } else {
                          tempSelected.addAll(allBrands);
                        }
                      });
                    },
                    child: Text(
                      tempSelected.length == allBrands.length ? "সব বাদ দিন" : "সব সিলেক্ট",
                      style: GoogleFonts.hindSiliguri(color: cAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allBrands.map((brand) {
                  final isSelected = tempSelected.contains(brand);
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        if (isSelected) {
                          tempSelected.remove(brand);
                        } else {
                          tempSelected.add(brand);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? cAccent.withOpacity(0.15) : cBorder.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: isSelected ? cAccent : cBorder),
                      ),
                      child: Text(
                        brand,
                        style: GoogleFonts.hindSiliguri(
                          color: isSelected ? cAccent : cMuted,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("বাতিল", style: GoogleFonts.hindSiliguri(color: cMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, tempSelected.toList()),
              style: ElevatedButton.styleFrom(backgroundColor: cAccent),
              child: Text("সেভ করুন", style: GoogleFonts.hindSiliguri(color: cBg, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await DatabaseService.instance.saveSelectedBrands(result);
      setState(() {
        _selectedBrands = result;
        // Reset selected brand if it's no longer in filtered list
        final allBrands = _thaiColorSets.map((e) => e.brand).toSet().toList();
        final filteredBrands = _selectedBrands.isEmpty
            ? allBrands
            : allBrands.where((b) => _selectedBrands.contains(b)).toList();
        if (!filteredBrands.contains(_selectedBrandName)) {
          _selectedBrandName = filteredBrands.isNotEmpty ? filteredBrands.first : allBrands.first;
          _updateColorsForBrand();
        }
      });
    }
  }

  void _updateProfileSizesForColor() {
    if (_selectedBrandName == null || _selectedColorName == null || _thaiColorSets.isEmpty) return;
    
    final sizes = _thaiColorSets
        .where((e) =>
            e.model == _selectedModel &&
            e.brand == _selectedBrandName &&
            e.color == _selectedColorName &&
            e.profileSize != 'single_door')
        .map((e) => e.profileSize)
        .toSet()
        .toList();
        
    setState(() {
      // ডিফল্টভাবে ৩" (নেট ছাড়া) সিলেক্ট হবে
      if (sizes.isNotEmpty) {
        _selectedProfileSize = sizes.contains('3"') ? '3"' : sizes.first;
      } else {
        _selectedProfileSize = null;
      }
      _updateSelectedThaiColorSet();
    });
  }

  void _updateSelectedThaiColorSet() {
  try {
    _selectedThaiColorSet = _thaiColorSets.firstWhere((e) =>
        e.model == _selectedModel &&
        e.brand == _selectedBrandName &&
        e.color == _selectedColorName &&
        e.profileSize == _selectedProfileSize);
  } catch (_) {
    if (_thaiColorSets.isNotEmpty) {
      _selectedThaiColorSet = _thaiColorSets.first;
    }
  }
  _refreshNsNhIfNeeded();
 }

// ৪" প্রোফাইলে পাল্টালে N/S, N/H ফাঁকা/০ থাকলে windowsList থেকে recalculate করে বসিয়ে দেয়
  void _refreshNsNhIfNeeded() {
  if (_selectedThaiColorSet == null) return;
  if (_selectedThaiColorSet!.profileSize.contains('4') && _windowsList.isNotEmpty) {
    if (_nsController.text.trim().isEmpty && _nhController.text.trim().isEmpty) {
      final cuts = _getCalculation().calcCutInches();
      _nsController.text = (cuts['ns'] ?? 0).toStringAsFixed(1);
      _nhController.text = (cuts['nh'] ?? 0).toStringAsFixed(1);
    }
  }
}

  WindowCalculation _getCalculation() {
    return WindowCalculation(
      windowsList: _windowsList,
      selectedThaiColorSet: _selectedThaiColorSet,
      selectedDoorColorSet: _getDoorColorSet(),
      selectedGlassBrand: _getActiveGlassBrand(),
      selectedDoorGlassBrand: _getActiveDoorGlassBrand(),
      hardwarePrices: _hardwarePrices,
      dlCount: _dlCount,
      swCount: _swCount,
      scCount: _scCount,
      snCount: _snCount,
      hwRatePerSft: double.tryParse(_hwRateController.text) ?? 25,
      labor: double.tryParse(_laborController.text) ?? 0,
      advance: double.tryParse(_advanceController.text) ?? 0,
      overrideOs: double.tryParse(_osController.text),
      overrideOt: double.tryParse(_otController.text),
      overrideOhb: double.tryParse(_ohbController.text),
      overrideSl: double.tryParse(_slController.text),
      overrideIl: double.tryParse(_ilController.text),
      overrideSt: double.tryParse(_stController.text),
      overrideSb: double.tryParse(_sbController.text),
      overrideNs: double.tryParse(_nsController.text),
      overrideNh: double.tryParse(_nhController.text),
    );
  }

  double _calcTotalSft() => _getCalculation().calcTotalSft();

  int _calcWindowAluTotalDiscounted() {
    final base = _getCalculation().calcAluTotal();
    return (base * (1 - _brandDiscount / 100)).round();
  }

  int _calcDoorAluTotalDiscounted() {
    final base = _getCalculation().calcDoorAluTotal();
    return (base * (1 - _doorBrandDiscount / 100)).round();
  }

  int _calcAluTotal() {
    return _calcWindowAluTotalDiscounted() + _calcDoorAluTotalDiscounted();
  }
  double _calcHwTotal() => _getCalculation().calcHwTotal();
  double _calcSft(double w, double h, int qty) => WindowCalculation.calcSft(w, h, qty);
  double _inchToBars(double inch) {
    final specInches = WindowCalculation.calcSpecLengthInches(_selectedThaiColorSet?.specLength);
    return WindowCalculation.inchToBars(inch, specLengthInches: specInches);
  }

  double _calcHwTotalCustom() {
    final calc = _getCalculation();
    final hwItems = [...calc.calcHardwareBreakdown(), ...calc.calcDoorHardwareBreakdown()];
    double total = 0;
    for (var item in hwItems) {
      final name = item['name'] as String;
      final qty = (item['qty'] as num).toInt();
      final rate = _customHwRates[name] ?? (item['rate'] as num?)?.toDouble() ?? 0;
      total += qty * rate;
    }
    return total;
  }

  String _formatBar(double bar) {
    if (bar == bar.toInt()) {
      return "${bar.toInt()}P";
    }
    return "${bar.toStringAsFixed(2)}P";
  }

  void _addWindow() {
    double? w = double.tryParse(_winWidthController.text);
    double? h = double.tryParse(_winHeightController.text);
    int? q = int.tryParse(_winQtyController.text);
    String name = _winNameController.text.trim();
    if (w == null || h == null || q == null) {
      _showSnackBar("সঠিক সংখ্যা দিন!", cRed);
      return;
    }

    double? gateWidth;
    if (_addEntryType == 'door') {
      gateWidth = double.tryParse(_gateWidthController.text) ?? (w / 2);
    }

    if (name.isEmpty) {
      name = _addEntryType == 'door'
          ? "Door ${_windowsList.where((e) => e['type'] == 'door').length + 1}"
          : "Window ${_windowsList.where((e) => e['type'] != 'door').length + 1}";
    }

    setState(() {
      _windowsList.add({
        'name': name,
        'type': _addEntryType,
        'w': w,
        'h': h,
        'qty': q,
        if (_addEntryType == 'door') 'gateWidth': gateWidth,
      });
      final nextIsDoor = _addEntryType == 'door';
      _winNameController.text = nextIsDoor
          ? "Door ${_windowsList.where((e) => e['type'] == 'door').length + 1}"
          : "Window ${_windowsList.where((e) => e['type'] != 'door').length + 1}";
      _gateWidthTouched = false;
      _gateWidthController.clear();
    });
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.hindSiliguri(color: cText)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _nextStep() {
  if (_currentStep == 1) {
    if (_windowsList.isEmpty) {
      _showSnackBar("অন্তত ১টি জানালা যোগ করুন!", cRed);
      return;
    }
    // Purono override values clear koro — notun kore calculate hobe
    _osController.clear();
    _otController.clear();
    _ohbController.clear();
    _slController.clear();
    _ilController.clear();
    _stController.clear();
    _sbController.clear();
    _nsController.clear();
    _nhController.clear();

    final cuts = _getCalculation().calcCutInches();
    setState(() {
      _osController.text = cuts['os']!.toStringAsFixed(1);
      _otController.text = cuts['ot']!.toStringAsFixed(1);
      _ohbController.text = cuts['ohb']!.toStringAsFixed(1);
      _slController.text = cuts['sl']!.toStringAsFixed(1);
      _ilController.text = cuts['il']!.toStringAsFixed(1);
      _stController.text = cuts['st']!.toStringAsFixed(1);
      _sbController.text = cuts['sb']!.toStringAsFixed(1);

      // ৪" হলে তবেই N/S, N/H বসাও — নাহলে খালি রাখো
      if (_selectedThaiColorSet?.profileSize.contains('4') == true) {
        _nsController.text = cuts['ns']!.toStringAsFixed(1);
        _nhController.text = cuts['nh']!.toStringAsFixed(1);
      } else {
        _nsController.clear();
        _nhController.clear();
      }

      int totalQty = 0;
      for (var w in _windowsList) {
        totalQty += (w['qty'] as num).toInt();
      }
      _dlCount = totalQty * 2;
      _swCount = totalQty * 2;
      _scCount = (totalQty / 2).ceil();
      _snCount = (totalQty / 4).ceil();

      // Labor auto-calculate: 3 inch = 25 Tk/sqft, 4 inch = 30 Tk/sqft
      double totalSft = _calcTotalSft();
      double laborRate = (_selectedThaiColorSet?.profileSize.contains('4') == true) ? 30 : 25;
      _laborRateController.text = laborRate.toStringAsFixed(0);
      _laborController.text = (totalSft * laborRate).toStringAsFixed(0);

      _currentStep = 2;
    });
  } else if (_currentStep == 2) {
    setState(() => _currentStep = 3);
  } else if (_currentStep == 3) {
    setState(() => _currentStep = 4);
  }
}

  void _backStep() {
    if (_currentStep > 1) setState(() => _currentStep--);
  }

  void _resetAll() {
    setState(() {
      _windowsList.clear();
      _currentStep = 1;
      _dlCount = _swCount = _scCount = _snCount = 0;
      _winNameController.text = "Window 1";
      _winWidthController.text = "60";
      _winHeightController.text = "60";
      _winQtyController.text = "1";
      _osController.clear();
      _otController.clear();
      _ohbController.clear();
      _slController.clear();
      _ilController.clear();
      _stController.clear();
      _sbController.clear();
      _nsController.clear();
      _nhController.clear();
      _laborController.text = "0";
      _laborRateController.text = "25";
      _fareController.text = "0";
      _advanceController.text = "0";
      _customerNameController.clear();
      _customerPhoneController.clear();
      _customHwRates.clear();
    });
  }

  Future<void> _shareWhatsApp() async {
    final calc = _getCalculation();
    double totalSft = calc.calcTotalSft();
    int aluTotal = calc.calcAluTotal();
    int aluTotalAfterDiscount = _calcAluTotal();
    double hwTotal = _calcHwTotalCustom();
    double glassTotal = calc.calcGlassTotal();
    double labor = calc.labor;
    double fare = double.tryParse(_fareController.text) ?? 0;
    double advance = calc.advance;
    double grandTotal = aluTotalAfterDiscount.toDouble() + glassTotal + hwTotal + labor + fare;
    double due = grandTotal - advance;
    final hwItems = calc.calcHardwareBreakdown();

    final name = _customerNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar("কাস্টমারের নাম দিন!", cRed);
      return;
    }
    final phone = _customerPhoneController.text.trim();

    final formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    final windows = calc.windowsList;
    final cuts = calc.calcCutInches();
    final thaiSet = calc.selectedThaiColorSet;
    final glassBrand = calc.selectedGlassBrand;
    final is4Inch = thaiSet?.profileSize.contains('4') == true;
    final hasDoors = _windowsList.any((w) => w['type'] == 'door');
    final hasWindows = _windowsList.any((w) => (w['type'] ?? 'window') != 'door');
    final doorSet = calc.selectedDoorColorSet;
    final doorCuts = calc.calcDoorCutInches();
    final doorAluTotal = calc.calcDoorAluTotal();

    // Window/Door list
    final windowBuffer = StringBuffer();
    if (windows.isNotEmpty) {
      windowBuffer.writeln("জানালা/দরজার তালিকা:");
      windowBuffer.writeln("--------------------");
      for (var i = 0; i < windows.length; i++) {
        final w = windows[i];
        final width = (w['w'] as num?)?.toDouble() ?? 0;
        final height = (w['h'] as num?)?.toDouble() ?? 0;
        final qty = (w['qty'] as num?)?.toInt() ?? 1;
        final sft = (width * height / 144.0) * qty;
        final isDoor = w['type'] == 'door';
        final tag = isDoor ? "[দরজা]" : "[জানালা]";
        final gateWidth = (w['gateWidth'] as num?)?.toDouble();
        final dimsText = isDoor && gateWidth != null
            ? "${height.toStringAsFixed(0)}\" x ${width.toStringAsFixed(0)}\" x ${gateWidth.toStringAsFixed(0)}\""
            : "${height.toStringAsFixed(0)}\" x ${width.toStringAsFixed(0)}\"";
        windowBuffer.writeln("  ${i + 1}. $tag ${w['name']} — $dimsText x ${qty}টি = ${sft.toStringAsFixed(2)} Sft");
      }
      windowBuffer.writeln("  মোট: ${totalSft.toStringAsFixed(2)} Sft");
      windowBuffer.writeln();
    }

    // Hardware breakdown
    final hwBuffer = StringBuffer();
    hwBuffer.writeln("হার্ডওয়্যার হিসাব:");
    hwBuffer.writeln("--------------------");
    for (var item in hwItems) {
      final name = item['name'] as String;
      final qty = (item['qty'] as num).toInt();
      final rate = _customHwRates[name] ?? (item['rate'] as num?)?.toDouble() ?? 0;
      final cost = qty * rate;
      hwBuffer.writeln("  $name — $qty ${item['unit']} × ৳${_fmtRate(rate)} = ৳${_fmtTk(cost)}");
    }
    hwBuffer.writeln("  -------------------");
    hwBuffer.writeln("  হার্ডওয়্যার মোট: ৳${_fmtTk(hwTotal)}");
    hwBuffer.writeln();

    // Profile cut detail
    final cutBuffer = StringBuffer();
    if (thaiSet != null && hasWindows) {
      cutBuffer.writeln("অ্যালুমিনিয়াম প্রোফাইল হিসাব:");
      cutBuffer.writeln("--------------------");
      cutBuffer.writeln("ব্র্যান্ড: ${thaiSet.brand} (${thaiSet.color})");
      cutBuffer.writeln("সাইজ: ${thaiSet.profileSize}");
      cutBuffer.writeln();

      final cutItems = [
        ['O/S (আউটার সাইড)', cuts['os'], thaiSet.priceOs],
        ['O/T (আউটার টপ)', cuts['ot'], thaiSet.priceOt],
        ['OHB (আউটার হাই বটম)', cuts['ohb'], thaiSet.priceOhb],
        ['S/L (স্লাইডিং লক)', cuts['sl'], thaiSet.priceSl],
        ['I/L (ইন্টারলক)', cuts['il'], thaiSet.priceIl],
        ['S/T (শাটার টপ)', cuts['st'], thaiSet.priceSt],
        ['S/B (শাটার বটম)', cuts['sb'], thaiSet.priceSb],
      ];
      if (is4Inch) {
        cutItems.add(['N/S (নেট সেকশন)', cuts['ns'], thaiSet.priceNs ?? 0]);
        cutItems.add(['N/H (নেট হ্যান্ডেল)', cuts['nh'], thaiSet.priceNb ?? 0]);
      }

      for (var item in cutItems) {
        final label = item[0] as String;
        final inch = (item[1] as num?)?.toDouble() ?? 0;
        final pricePerBar = (item[2] as num?)?.toInt() ?? 0;
        final specInches = WindowCalculation.calcSpecLengthInches(_selectedThaiColorSet?.specLength);
        final bars = inch / specInches;
        final total = (bars * pricePerBar).round();
        if (inch > 0) {
          cutBuffer.writeln("  $label");
          cutBuffer.writeln("    ইঞ্চি: ${inch.toStringAsFixed(0)}\"  |  বার: ${bars.toStringAsFixed(2)}  |  দর/বার: ৳$pricePerBar  |  মোট: ৳${_fmtTk(total.toDouble())}");
        }
      }
      cutBuffer.writeln("  -------------------");
      cutBuffer.writeln("  জানালা অ্যালুমিনিয়াম: ৳${_fmtTk(calc.calcAluTotal().toDouble())}");
      cutBuffer.writeln();
    }

    // Single Door detail
    if (hasDoors && doorSet != null) {
      cutBuffer.writeln("সিঙ্গেল ডোর প্রোফাইল হিসাব:");
      cutBuffer.writeln("--------------------");
      cutBuffer.writeln("ব্র্যান্ড: ${doorSet.brand} (${doorSet.color})");
      cutBuffer.writeln();

      final doorCutItems = [
        ['O/S (আউটার সাইড)', doorCuts['os'], doorSet.priceOs],
        ['O/T (আউটার টপ)', doorCuts['ot'], doorSet.priceOt],
        ['Low Bottom', doorCuts['ohb'], doorSet.priceOhb],
        ['Shutter Lock', doorCuts['sl'], doorSet.priceSl],
        ['Shutter Top', doorCuts['st'], doorSet.priceSt],
        ['Shutter Bottom', doorCuts['sb'], doorSet.priceSb],
        ['1.75 Box', doorCuts['box'], doorSet.priceBox175 ?? 0],
        ['Fitting Angle', doorCuts['fittingAngle'], doorSet.priceFittingAngle ?? 0],
      ];

      final doorSpecInches = WindowCalculation.calcSpecLengthInches(doorSet.specLength);
      for (var item in doorCutItems) {
        final label = item[0] as String;
        final inch = (item[1] as num?)?.toDouble() ?? 0;
        final pricePerBar = (item[2] as num?)?.toInt() ?? 0;
        final bars = inch / doorSpecInches;
        final total = (bars * pricePerBar).round();
        if (inch > 0) {
          cutBuffer.writeln("  $label");
          cutBuffer.writeln("    ইঞ্চি: ${inch.toStringAsFixed(0)}\"  |  বার: ${bars.toStringAsFixed(2)}  |  দর/বার: ৳$pricePerBar  |  মোট: ৳${_fmtTk(total.toDouble())}");
        }
      }
      cutBuffer.writeln("  -------------------");
      cutBuffer.writeln("  ডোর অ্যালুমিনিয়াম: ৳${_fmtTk(doorAluTotal.toDouble())}");
      cutBuffer.writeln();

      cutBuffer.writeln("  ==========================");
      if (_brandDiscount > 0) {
        cutBuffer.writeln("  জানালা অ্যালু (মূল্য): ৳${_fmtTk(aluTotal.toDouble())}");
        cutBuffer.writeln("  জানালা ডিসকাউন্ট (-${_brandDiscount.toStringAsFixed(0)}%): -৳${_fmtTk((aluTotal - _calcWindowAluTotalDiscounted()).toDouble())}");
      }
      if (_doorBrandDiscount > 0) {
        cutBuffer.writeln("  ডোর অ্যালু (মূল্য): ৳${_fmtTk(doorAluTotal.toDouble())}");
        cutBuffer.writeln("  ডোর ডিসকাউন্ট (-${_doorBrandDiscount.toStringAsFixed(0)}%): -৳${_fmtTk((doorAluTotal - _calcDoorAluTotalDiscounted()).toDouble())}");
      }
      cutBuffer.writeln("  অ্যালুমিনিয়াম সর্বমোট: ৳${_fmtTk(aluTotalAfterDiscount.toDouble())}");
      cutBuffer.writeln();
    } else if (_brandDiscount > 0) {
      cutBuffer.writeln("  অ্যালুমিনিয়াম (মূল্য): ৳${_fmtTk(aluTotal.toDouble())}");
      cutBuffer.writeln("  ডিসকাউন্ট (-${_brandDiscount.toStringAsFixed(0)}%): -৳${_fmtTk((aluTotal - aluTotalAfterDiscount).toDouble())}");
      cutBuffer.writeln("  অ্যালুমিনিয়াম মোট: ৳${_fmtTk(aluTotalAfterDiscount.toDouble())}");
      cutBuffer.writeln();
    }

    // Glass detail
    final glassBuffer = StringBuffer();
    if (hasWindows && hasDoors && calc.hasSeparateDoorGlass) {
      glassBuffer.writeln("গ্লাস হিসাব:");
      glassBuffer.writeln("--------------------");
      if (glassBrand != null) {
        glassBuffer.writeln("🪟 জানালার গ্লাস: ${glassBrand.brandName}");
        glassBuffer.writeln("  দর: ৳${_fmtTk(glassBrand.pricePerSft.toDouble())} / Sft  |  এলাকা: ${calc.calcWindowSft().toStringAsFixed(2)} Sft  |  মোট: ৳${_fmtTk(calc.calcWindowGlassTotal())}");
      }
      final doorGlass = calc.selectedDoorGlassBrand;
      if (doorGlass != null) {
        glassBuffer.writeln("🚪 ডোরের গ্লাস: ${doorGlass.brandName}");
        glassBuffer.writeln("  দর: ৳${_fmtTk(doorGlass.pricePerSft.toDouble())} / Sft  |  এলাকা: ${calc.calcDoorSft().toStringAsFixed(2)} Sft  |  মোট: ৳${_fmtTk(calc.calcDoorGlassTotal())}");
      }
      glassBuffer.writeln("  -------------------");
      glassBuffer.writeln("গ্লাস সর্বমোট: ৳${_fmtTk(glassTotal)}");
      glassBuffer.writeln();
    } else if (glassBrand != null) {
      glassBuffer.writeln("গ্লাস হিসাব:");
      glassBuffer.writeln("--------------------");
      glassBuffer.writeln("ব্র্যান্ড: ${glassBrand.brandName}");
      glassBuffer.writeln("দর: ৳${_fmtTk(glassBrand.pricePerSft.toDouble())} / Sft");
      glassBuffer.writeln("মোট এলাকা: ${totalSft.toStringAsFixed(2)} Sft");
      glassBuffer.writeln("গ্লাস মোট: ৳${_fmtTk(glassTotal)}");
      glassBuffer.writeln();
    }

    final message = "*Thai Calc Pro - বিল রশিদ*\n"
        "------------------------------------\n"
        "\n"
        "কাস্টমার: $name\n"
        "${phone.isNotEmpty ? "ফোন: $phone\n" : ""}"
        "তারিখ: $formattedDate\n"
        "\n"
        "====================================\n"
        "${windowBuffer}"
        "====================================\n"
        "${cutBuffer}"
        "====================================\n"
        "${glassBuffer}"
        "${hwBuffer}"
        "মজুরি/ফিটিং: ৳${_fmtTk(labor)}\n"
        "${fare > 0 ? "গাড়ি ভাড়া: ৳${_fmtTk(fare)}\n" : ""}"
        "\n"
        "====================================\n"
        "*সর্বমোট বিল: ৳${_fmtTk(grandTotal)}*\n"
        "${totalSft > 0 ? "গড় খরচ / Sft: ৳${_fmtTk(grandTotal / totalSft)}\n" : ""}"
        "${advance > 0 ? "অগ্রিম জমা: ৳${_fmtTk(advance)}\n" : ""}"
        "*বাকি (Due): ৳${_fmtTk(due)}*\n"
        "====================================\n"
        "\n"
        "Thai Calc Pro ব্যবহার করার জন্য ধন্যবাদ!";

    final encodedMessage = Uri.encodeComponent(message);
    var cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isNotEmpty) {
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '88$cleanPhone';
      }
    }

    final url = cleanPhone.isNotEmpty
        ? "https://wa.me/$cleanPhone?text=$encodedMessage"
        : "https://wa.me/?text=$encodedMessage";

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSnackBar("WhatsApp শেয়ার সম্পন্ন হয়েছে!", cGreen);
      } else {
        _showSnackBar("WhatsApp চালু করা যায়নি!", cRed);
      }
    } catch (e) {
      _showSnackBar("WhatsApp শেয়ার ত্রুটি: $e", cRed);
    }
  }

  Future<void> _saveInvoice() async {
    final name = _customerNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar("কাস্টমারের নাম দিন!", cRed);
      return;
    }
    setState(() => _isSaving = true);
    
    try {
      final calc = _getCalculation();
      final windowHwItems = calc.calcHardwareBreakdown();
      final doorHwItemsList = calc.calcDoorHardwareBreakdown();
      for (var item in [...windowHwItems, ...doorHwItemsList]) {
        final name = item['name'] as String;
        if (_customHwRates.containsKey(name)) {
          item['rate'] = _customHwRates[name];
          item['cost'] = (item['qty'] as int) * _customHwRates[name]!;
        }
      }
      final aluTotal = calc.calcCombinedAluTotal();
      final aluTotalAfterDiscount = _calcAluTotal();
      final hasDoors = _windowsList.any((w) => w['type'] == 'door');
      final hasWindowsEntries = _windowsList.any((w) => (w['type'] ?? 'window') != 'door');
      final doorCuts = calc.calcDoorCutInches();

      final fare = double.tryParse(_fareController.text) ?? 0;
      final grandTotal = aluTotalAfterDiscount.toDouble() + calc.calcGlassTotal() + _calcHwTotalCustom() + calc.labor + fare;
      final doorSet = _getDoorColorSet();
      final invoice = {
        'name': name,
        'phone': _customerPhoneController.text.trim(),
        'brand': _selectedThaiColorSet?.brand ?? 'Thai',
        'color': _selectedThaiColorSet?.color ?? '',
        'thickness': (_selectedThaiColorSet?.profileSize.contains('4') == true) ? 4.0 : 3.0,
        'profile_size': _selectedThaiColorSet?.profileSize ?? '3"',
        'spec_length': _selectedThaiColorSet?.specLength ?? "21'-0\"",
        'glassBrand': _getActiveGlassBrand()?.brandName ?? '',
        'glassRate': _getActiveGlassBrand()?.pricePerSft ?? 0,
        'laborRate': double.tryParse(_laborRateController.text) ?? 0,
        'brandDiscount': _brandDiscount,
        'total': grandTotal,
        'due': grandTotal - calc.advance,
        'date': DateTime.now().toIso8601String(),
        'windows': _windowsList,
        'totalSft': calc.calcTotalSft(),
        'aluTotal': aluTotalAfterDiscount,
        'windowAluTotal': hasWindowsEntries ? _calcWindowAluTotalDiscounted() : 0,
        'glassTotal': calc.calcGlassTotal(),
        'windowGlassTotal': calc.calcWindowGlassTotal(),
        'doorGlassTotal': calc.calcDoorGlassTotal(),
        'hasSeparateDoorGlass': calc.hasSeparateDoorGlass,
        'hwTotal': _calcHwTotalCustom(),
        'hwItems': [...windowHwItems, ...doorHwItemsList],
        'windowHwItems': windowHwItems,
        'doorHwItems': doorHwItemsList,
        'hasDoors': hasDoors,
        'hasWindows': hasWindowsEntries,
        'doorCuts': hasDoors ? doorCuts : null,
        'doorBrand': hasDoors ? _selectedDoorBrandName : null,
        'doorColor': hasDoors ? _selectedDoorColorName : null,
        'doorBrandDiscount': hasDoors ? _doorBrandDiscount : 0,
        'doorAluTotal': hasDoors ? _calcDoorAluTotalDiscounted() : 0,
        'doorGlassBrand': hasDoors ? (_getActiveDoorGlassBrand()?.brandName ?? _getActiveGlassBrand()?.brandName ?? '') : '',
        'doorGlassRate': hasDoors ? (_getActiveDoorGlassBrand()?.pricePerSft ?? _getActiveGlassBrand()?.pricePerSft ?? 0) : 0,
        'doorSpecLength': hasDoors ? doorSet?.specLength : null,
        'doorCutPrices': hasDoors && doorSet != null
            ? {
                'os': doorSet.priceOs,
                'ot': doorSet.priceOt,
                'ohb': doorSet.priceOhb,
                'sl': doorSet.priceSl,
                'st': doorSet.priceSt,
                'sb': doorSet.priceSb,
                'box': doorSet.priceBox175 ?? 0,
                'fittingAngle': doorSet.priceFittingAngle ?? 0,
              }
            : null,
        'labor': calc.labor,
        'fare': fare,
        'advance': calc.advance,
        'dlCount': _dlCount,
        'swCount': _swCount,
        'scCount': _scCount,
        'snCount': _snCount,
        'cuts': hasWindowsEntries ? {
          'os': double.tryParse(_osController.text) ?? 0,
          'ot': double.tryParse(_otController.text) ?? 0,
          'ohb': double.tryParse(_ohbController.text) ?? 0,
          'sl': double.tryParse(_slController.text) ?? 0,
          'il': double.tryParse(_ilController.text) ?? 0,
          'st': double.tryParse(_stController.text) ?? 0,
          'sb': double.tryParse(_sbController.text) ?? 0,
          'ns': double.tryParse(_nsController.text) ?? 0,
          'nh': double.tryParse(_nhController.text) ?? 0,
        } : null,
        'cutPrices': {
          'os': _selectedThaiColorSet?.priceOs ?? 0,
          'ot': _selectedThaiColorSet?.priceOt ?? 0,
          'ohb': _selectedThaiColorSet?.priceOhb ?? 0,
          'sl': _selectedThaiColorSet?.priceSl ?? 0,
          'il': _selectedThaiColorSet?.priceIl ?? 0,
          'st': _selectedThaiColorSet?.priceSt ?? 0,
          'sb': _selectedThaiColorSet?.priceSb ?? 0,
          'ns': _selectedThaiColorSet?.priceNs ?? 0,
          'nb': _selectedThaiColorSet?.priceNb ?? 0,
        },
      };
      
      await DatabaseService.instance.saveInvoice(invoice);
      if (mounted) {
        _showSnackBar("হিসাব সেভ হয়েছে! ✓", cGreen);
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showSnackBar("সেভ করার সময় ত্রুটি ঘটেছে: $e", cRed);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E17),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Thai Calc Pro",
                style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cAccent)),
            Text("ধাপ $_currentStep / ৪ — ${_getStepTitle()}",
                style: GoogleFonts.hindSiliguri(fontSize: 12, color: cMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: cAccent),
            tooltip: "হোমে ফিরুন",
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            }
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: cMuted),
            onPressed: () async {
              await DatabaseService.instance.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF0B0E17),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: _buildStepIndicatorRow(),
          ),
          Expanded(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCurrentStepContent(),
                      const SizedBox(height: 16),
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1: return "মাপ ও সেটআপ";
      case 2: return "অ্যালুমিনিয়াম হিসাব";
      case 3: return "হার্ডওয়্যার ও ফিটিংস";
      case 4: return "ফাইনাল ইনভয়েস";
      default: return "";
    }
  }

  Widget _buildStepIndicatorRow() {
    final stepNames = ["মাপ", "অ্যালু", "H/W", "ইনভয়েস"];
    List<Widget> children = [];
    for (int i = 1; i <= 4; i++) {
      bool active = i == _currentStep, done = i < _currentStep;
      children.add(Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active || done ? (active ? cAccent : cGreen) : cCard,
            border: Border.all(
              color: active || done ? (active ? cAccent : cGreen) : cBorder,
              width: 2),
          ),
          alignment: Alignment.center,
          child: Text(done ? "✓" : i.toString(),
              style: GoogleFonts.inter(
                  color: active ? cBg : cText,
                  fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(height: 4),
        Text(stepNames[i - 1],
            style: GoogleFonts.hindSiliguri(
                fontSize: 10,
                color: active ? cAccent : cMuted,
                fontWeight: active ? FontWeight.bold : FontWeight.normal)),
      ]));
      if (i < 4) {
        children.add(Expanded(
            child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 14),
                color: done ? cGreen : cBorder)));
      }
    }
    return Row(children: children);
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1: return _buildStep1();
      case 2: return _buildStep2();
      case 3: return _buildStep3();
      case 4: return _buildStep4();
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildCard({required Widget child, Color? borderColor}) {
    return Container(
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? cBorder),
      ),
      padding: const EdgeInsets.all(16.0),
      child: child,
    );
  }

  Widget _buildHeading(String title) => Text(title,
      style: GoogleFonts.hindSiliguri(
          color: cText, fontSize: 15, fontWeight: FontWeight.bold));

  Widget _buildStep1() {
    // Collect distinct brand list (model অনুযায়ী ফিল্টার, door mode হলে single_door সাপোর্টেড brand-ই দেখাবে)
    final allBrandsList = _thaiColorSets
        .where((e) => e.model == _selectedModel && e.profileSize != 'single_door')
        .map((e) => e.brand)
        .toSet()
        .toList();
    final brandsList = _selectedBrands.isEmpty
        ? allBrandsList
        : allBrandsList.where((b) => _selectedBrands.contains(b)).toList();
    // Colors matching selected brand + model
    final colorsList = _thaiColorSets
        .where((e) => e.model == _selectedModel && e.brand == _selectedBrandName)
        .map((e) => e.color)
        .toSet()
        .toList();
    // Profile size list matching selected brand and color (single_door বাদে)
    final profileSizeList = _thaiColorSets
        .where((e) =>
            e.model == _selectedModel &&
            e.brand == _selectedBrandName &&
            e.color == _selectedColorName &&
            e.profileSize != 'single_door')
        .map((e) => e.profileSize)
        .toSet()
        .toList();

    final hasWindowEntries = _windowsList.any((w) => (w['type'] ?? 'window') != 'door');
    final hasDoorEntries = _windowsList.any((w) => w['type'] == 'door');
    final showWindowFields = hasWindowEntries || _addEntryType == 'window';
    final showDoorFields = hasDoorEntries || _addEntryType == 'door';
    final bothTypesPresent = showWindowFields && showDoorFields;
    final doorGlassOnlyMode = showDoorFields && !showWindowFields;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Brand Filter Card
      _buildCard(
        borderColor: _selectedBrands.isNotEmpty ? cAccent.withOpacity(0.3) : null,
        child: GestureDetector(
          onTap: _showBrandFilterDialog,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Icon(Icons.filter_list_rounded,
                  color: _selectedBrands.isNotEmpty ? cAccent : cMuted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ব্র্যান্ড ফিল্টার",
                      style: GoogleFonts.hindSiliguri(
                        color: cText, fontSize: 13, fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedBrands.isEmpty
                          ? "সব ব্র্যান্ড দেখাচ্ছে — ট্যাপ করে ফিল্টার করুন"
                          : "${_selectedBrands.length} টি ব্র্যান্ড সিলেক্টেড — ট্যাপ করে পরিবর্তন করুন",
                      style: GoogleFonts.hindSiliguri(
                        color: _selectedBrands.isNotEmpty ? cAccent : cMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cMuted, size: 20),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeading("⚙️ সেটআপ"),
        const SizedBox(height: 12),
        if (_isLoadingBrands)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: cAccent, strokeWidth: 2),
            ),
          )
        else ...[
          // Model Dropdown
          DropdownButtonFormField<String>(
            value: _selectedModel,
            dropdownColor: cCard,
            style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
            decoration: InputDecoration(
              labelText: "মডেল সিলেক্ট করুন",
              labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
              filled: true, fillColor: const Color(0xFF12151F),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cAccent)),
            ),
            items: _thaiColorSets.map((e) => e.model).toSet().toList().map((v) =>
                DropdownMenuItem<String>(value: v, child: Text(v == 'general' ? 'General' : v.toUpperCase()))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedModel = v;
                final allBrands = _thaiColorSets
                    .where((e) => e.model == _selectedModel)
                    .map((e) => e.brand)
                    .toSet()
                    .toList();
                _selectedBrandName = allBrands.isNotEmpty ? allBrands.first : null;
                if (_selectedBrandName != null) {
                  _updateColorsForBrand();
                } else {
                  _selectedColorName = null;
                  _selectedProfileSize = null;
                  _selectedThaiColorSet = null;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          if (showWindowFields) ...[
          // Cascading Brand Dropdown with discount badge
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: brandsList.contains(_selectedBrandName) ? _selectedBrandName : null,
                dropdownColor: cCard,
                style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "থাই অ্যালুমিনিয়াম ব্র্যান্ড সিলেক্ট করুন",
                  labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                  filled: true, fillColor: const Color(0xFF12151F),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: cBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: cAccent)),
                ),
                items: brandsList.map((v) =>
                    DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedBrandName = v;
                    _updateColorsForBrand();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showStep1DiscountDialog(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  color: _brandDiscount > 0
                      ? cGreen.withOpacity(0.15)
                      : cBorder.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _brandDiscount > 0
                        ? cGreen.withOpacity(0.4)
                        : cBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _brandDiscount > 0
                          ? "-${_brandDiscount.toStringAsFixed(0)}%"
                          : "0%",
                      style: GoogleFonts.inter(
                        color: _brandDiscount > 0 ? cGreen : cMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_rounded,
                        color: _brandDiscount > 0 ? cGreen : cMuted, size: 12),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          // Cascading Color Dropdown
          DropdownButtonFormField<String>(
            value: colorsList.contains(_selectedColorName) ? _selectedColorName : null,
            dropdownColor: cCard,
            style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
            decoration: InputDecoration(
              labelText: "কালার সিলেক্ট করুন",
              labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
              filled: true, fillColor: const Color(0xFF12151F),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cAccent)),
            ),
            items: colorsList.map((v) =>
                DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
            onChanged: (v) {
              setState(() {
                _selectedColorName = v;
                _updateProfileSizesForColor();
              });
            },
          ),
          const SizedBox(height: 12),
          // Profile Size (৩"/৪") Dropdown
          DropdownButtonFormField<String>(
            value: profileSizeList.contains(_selectedProfileSize) ? _selectedProfileSize : null,
            dropdownColor: cCard,
            style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
            decoration: InputDecoration(
              labelText: "প্রোফাইল সাইজ সিলেক্ট করুন",
              labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
              filled: true, fillColor: const Color(0xFF12151F),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: cAccent)),
            ),
            items: profileSizeList.map((v) =>
                DropdownMenuItem<String>(
                  value: v,
                  child: Text(v.contains('4') ? '৪" (নেট সহ)' : '৩" (নেট ছাড়া)'),
                )).toList(),
            onChanged: (v) {
              setState(() {
                _selectedProfileSize = v;
                _updateSelectedThaiColorSet();
              });
              double totalSft = _calcTotalSft();
              double newRate = (v != null && v.contains('4')) ? 30 : 25;
              _laborRateController.text = newRate.toStringAsFixed(0);
              _laborController.text = (totalSft * newRate).toStringAsFixed(0);
            },
          ),
          ],
          const SizedBox(height: 12),
          if (showDoorFields) ...[
            // Door mode হলে door-এর নিজস্ব Brand/Color Dropdown দেখাবে
            Builder(builder: (_) {
              final doorBrandsList = _thaiColorSets
                  .where((e) => e.model == _selectedModel && e.profileSize == 'single_door')
                  .map((e) => e.brand)
                  .toSet()
                  .toList();
              final doorColorsList = _thaiColorSets
                  .where((e) =>
                      e.model == _selectedModel &&
                      e.brand == _selectedDoorBrandName &&
                      e.profileSize == 'single_door')
                  .map((e) => e.color)
                  .toSet()
                  .toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: doorBrandsList.contains(_selectedDoorBrandName) ? _selectedDoorBrandName : null,
                      dropdownColor: cCard,
                      style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "সিঙ্গেল ডোর ব্র্যান্ড",
                        labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                        filled: true, fillColor: const Color(0xFF12151F),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: cBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: cAccent2)),
                      ),
                      items: doorBrandsList.map((v) =>
                          DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedDoorBrandName = v;
                          final doorColors = _thaiColorSets
                              .where((e) => e.model == _selectedModel && e.brand == v && e.profileSize == 'single_door')
                              .map((e) => e.color)
                              .toSet()
                              .toList();
                          _selectedDoorColorName = doorColors.isNotEmpty ? doorColors.first : null;
                          _doorBrandDiscount = v != null ? (_allBrandDiscounts['door_$v'] ?? 0) : 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showDoorDiscountDialog(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      decoration: BoxDecoration(
                        color: _doorBrandDiscount > 0
                            ? cGreen.withOpacity(0.15)
                            : cBorder.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _doorBrandDiscount > 0 ? cGreen.withOpacity(0.4) : cBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _doorBrandDiscount > 0 ? "-${_doorBrandDiscount.toStringAsFixed(0)}%" : "0%",
                            style: GoogleFonts.inter(
                              color: _doorBrandDiscount > 0 ? cGreen : cMuted,
                              fontSize: 13, fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded,
                              color: _doorBrandDiscount > 0 ? cGreen : cMuted, size: 12),
                        ],
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: doorColorsList.contains(_selectedDoorColorName) ? _selectedDoorColorName : null,
                  dropdownColor: cCard,
                  style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "সিঙ্গেল ডোর কালার",
                    labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                    filled: true, fillColor: const Color(0xFF12151F),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: cBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: cAccent2)),
                  ),
                  items: doorColorsList.map((v) =>
                      DropdownMenuItem<String>(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setState(() => _selectedDoorColorName = v),
                ),
                const SizedBox(height: 8),
                if (_getDoorColorSet() == null)
                  Text("এই ব্র্যান্ড/কালারে সিঙ্গেল ডোরের রেট নেই",
                      style: GoogleFonts.hindSiliguri(color: cRed, fontSize: 11)),
                const SizedBox(height: 8),
                if (doorGlassOnlyMode) ...[
                  // শুধু Door লিস্টে থাকলে — একটাই Glass dropdown, Window ভ্যারিয়েবল শেয়ার করবে
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<GlassBrand>(
                        value: _selectedGlassBrand,
                        dropdownColor: cCard,
                        isExpanded: true,
                        style: GoogleFonts.hindSiliguri(color: cText, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: "দরজার গ্লাস ব্র্যান্ড / টাইপ সিলেক্ট করুন",
                          labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11),
                          filled: true, fillColor: const Color(0xFF12151F),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: cBorder)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: cAccent2)),
                        ),
                        items: _glassBrands.map((v) => DropdownMenuItem<GlassBrand>(value: v, child: Text(v.brandName, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _selectedGlassBrand = v),
                      ),
                    ),
                    if (_selectedGlassBrand != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showGlassRateDialog(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          decoration: BoxDecoration(
                            color: cBorder.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "৳${_fmtTk(_getActiveGlassBrand()?.pricePerSft.toDouble() ?? 0)}",
                                style: GoogleFonts.inter(
                                  color: cAccent2,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded, color: cAccent2, size: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),
                ] else if (bothTypesPresent) ...[
                  // Window + Door দুটোই লিস্টে থাকলে — Door এর আলাদা dropdown, ডিফল্ট window এর glass দিয়ে
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<GlassBrand>(
                        value: _selectedDoorGlassBrand ?? _selectedGlassBrand,
                        dropdownColor: cCard,
                        isExpanded: true,
                        style: GoogleFonts.hindSiliguri(color: cText, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: "দরজার গ্লাস ব্র্যান্ড / টাইপ সিলেক্ট করুন",
                          labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11),
                          filled: true, fillColor: const Color(0xFF12151F),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: cBorder)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: cAccent2)),
                        ),
                        items: _glassBrands.map((v) => DropdownMenuItem<GlassBrand>(value: v, child: Text(v.brandName, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _selectedDoorGlassBrand = v),
                      ),
                    ),
                    if (_selectedDoorGlassBrand != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final prevSelected = _selectedGlassBrand;
                          setState(() => _selectedGlassBrand = _selectedDoorGlassBrand);
                          _showGlassRateDialog().then((_) {
                            setState(() => _selectedGlassBrand = prevSelected);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          decoration: BoxDecoration(
                            color: cBorder.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "৳${_fmtTk(_getActiveDoorGlassBrand()?.pricePerSft.toDouble() ?? 0)}",
                                style: GoogleFonts.inter(
                                  color: cAccent2,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.edit_rounded, color: cAccent2, size: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),
                ],
              ]);
            }),
          ],
          if (!doorGlassOnlyMode) ...[
            const SizedBox(height: 12),
            // Glass Brand Dropdown (Window)
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<GlassBrand>(
                  value: _selectedGlassBrand,
                  dropdownColor: cCard,
                  style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: " জানালার গ্লাস ব্র্যান্ড / টাইপ সিলেক্ট করুন",
                    labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                    filled: true, fillColor: const Color(0xFF12151F),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: cBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: cAccent)),
                  ),
                  items: _glassBrands.map((v) =>
                      DropdownMenuItem<GlassBrand>(value: v, child: Text(v.brandName))).toList(),
                  onChanged: (v) => setState(() => _selectedGlassBrand = v),
                ),
              ),
              if (_selectedGlassBrand != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showGlassRateDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: cBorder.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "৳${_fmtTk(_getActiveGlassBrand()?.pricePerSft.toDouble() ?? 0)}",
                          style: GoogleFonts.inter(
                            color: cAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_rounded, color: cAccent, size: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
          ],
        ],
      ])),
      const SizedBox(height: 14),
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeading("➕ নতুন জানালা / দরজা যোগ করুন"),
        const SizedBox(height: 12),
        // ── Type Toggle ──
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _addEntryType = 'window';
                _winNameController.text = "Window ${_windowsList.where((e) => e['type'] != 'door').length + 1}";
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _addEntryType == 'window' ? cAccent.withOpacity(0.15) : cBorder.withOpacity(0.3),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  border: Border.all(color: _addEntryType == 'window' ? cAccent : cBorder),
                ),
                alignment: Alignment.center,
                child: Text("🪟 জানালা",
                    style: GoogleFonts.hindSiliguri(
                        color: _addEntryType == 'window' ? cAccent : cMuted,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _addEntryType = 'door';
                _winNameController.text = "Door ${_windowsList.where((e) => e['type'] == 'door').length + 1}";
                _gateWidthTouched = false;
                _autoFillGateWidth();
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _addEntryType == 'door' ? cAccent2.withOpacity(0.15) : cBorder.withOpacity(0.3),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  border: Border.all(color: _addEntryType == 'door' ? cAccent2 : cBorder),
                ),
                alignment: Alignment.center,
                child: Text("🚪 সিঙ্গেল ডোর",
                    style: GoogleFonts.hindSiliguri(
                        color: _addEntryType == 'door' ? cAccent2 : cMuted,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _buildTextInput(controller: _winNameController, label: _addEntryType == 'door' ? "দরজার নাম / লোকেশন" : "জানালার নাম / লোকেশন"),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildTextInput(controller: _winHeightController, label: "উচ্চতা (H) ইঞ্চি", isNumber: true)),
          const SizedBox(width: 8),
          Expanded(child: _buildTextInput(controller: _winWidthController, label: "প্রস্থ (W) ইঞ্চি", isNumber: true)),
          const SizedBox(width: 8),
          Expanded(child: _buildTextInput(controller: _winQtyController, label: "পরিমাণ (Qty)", isNumber: true)),
        ]),
        if (_addEntryType == 'door') ...[
          const SizedBox(height: 8),
          _buildTextInput(
            controller: _gateWidthController,
            label: "পাল্লার/গেটের প্রস্থ (ইঞ্চি)",
            isNumber: true,
            onChanged: (v) => _gateWidthTouched = true,
          ),
        ],
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _addWindow,
          style: ElevatedButton.styleFrom(
              backgroundColor: _addEntryType == 'door' ? cAccent2 : cAccent,
              foregroundColor: _addEntryType == 'door' ? cText : cBg,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          icon: const Icon(Icons.add, size: 20),
          label: Text(_addEntryType == 'door' ? "ADD DOOR" : "ADD WINDOW", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        ),
      ])),
      const SizedBox(height: 14),
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeading("📐 জানালার তালিকা"),
        const SizedBox(height: 12),
        if (_windowsList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text("কোনো জানালা যোগ করা হয়নি।",
                textAlign: TextAlign.center,
                style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _windowsList.length,
            itemBuilder: (ctx, idx) {
              final w = _windowsList[idx];
              double sft = _calcSft(w['w'], w['h'], w['qty']);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF12151F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cBorder)),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: (w['type'] == 'door' ? cAccent2 : cAccent).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: w['type'] == 'door' ? cAccent2 : cAccent),
                        ),
                        child: Text(w['type'] == 'door' ? "🚪 ডোর" : "🪟 জানালা",
                            style: GoogleFonts.hindSiliguri(
                                color: w['type'] == 'door' ? cAccent2 : cAccent,
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      Text("#${idx + 1}  ${w['name']}",
                          style: GoogleFonts.hindSiliguri(
                              color: cText, fontWeight: FontWeight.bold, fontSize: 14)),
                    ]),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: cAccent, borderRadius: BorderRadius.circular(4)),
                      child: Text("${sft.toStringAsFixed(1)} Sft",
                          style: GoogleFonts.inter(color: cBg, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(
                      child: Text(
                        w['type'] == 'door'
                            ? "H: ${w['h']}\"  ×  W: ${w['w']}\"  ×  Gate: ${w['gateWidth']}\"  ×  Qty: ${w['qty']}"
                            : "H: ${w['h']}\"  ×  W: ${w['w']}\"  ×  Qty: ${w['qty']}",
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: GoogleFonts.inter(color: cMuted, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        _windowsList.removeAt(idx);
                        // Renumber remaining windows
                        for (int i = 0; i < _windowsList.length; i++) {
                          _windowsList[i]['name'] = "Window ${i + 1}";
                        }
                        _winNameController.text = "Window ${_windowsList.length + 1}";
                      }),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: Text("🗑 মুছুন",
                          style: GoogleFonts.hindSiliguri(color: cRed, fontSize: 12)),
                    ),
                  ]),
                ]),
              );
            },
          ),
        const Divider(color: cBorder, height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("মোট জানালা: ${_windowsList.fold<int>(0, (sum, w) => sum + ((w['qty'] as num?)?.toInt() ?? 1))} টি",
              style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14)),
          Text("মোট এলাকা: ${_calcTotalSft().toStringAsFixed(2)} Sft",
              style: GoogleFonts.hindSiliguri(
                  color: cAccent, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ])),
    ]);
  }

  Widget _buildStep2() {
    final hasDoors = _windowsList.any((w) => w['type'] == 'door');
    final hasWindows = _windowsList.any((w) => (w['type'] ?? 'window') != 'door');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (hasDoors) ...[
        _buildCard(
          borderColor: cAccent2.withOpacity(0.3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildHeading("🚪 সিঙ্গেল ডোর হিসাব"),
            const SizedBox(height: 12),
            _buildDoorBreakdownTable(),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showDoorDiscountDialog(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _doorBrandDiscount > 0 ? cYellow.withOpacity(0.08) : cBorder.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _doorBrandDiscount > 0 ? cYellow.withOpacity(0.3) : cBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.local_offer_rounded,
                          color: _doorBrandDiscount > 0 ? cYellow : cMuted, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        _doorBrandDiscount > 0
                            ? "ডোর ডিসকাউন্ট (-${_doorBrandDiscount.toStringAsFixed(0)}%)"
                            : "ডোর ডিসকাউন্ট (0%)",
                        style: GoogleFonts.hindSiliguri(
                          color: _doorBrandDiscount > 0 ? cYellow : cMuted,
                          fontSize: 13, fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.edit_rounded,
                          color: _doorBrandDiscount > 0 ? cYellow : cMuted, size: 14),
                    ]),
                    if (_doorBrandDiscount > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        "মূল দাম: ৳ ${_fmtTk(_getCalculation().calcDoorAluTotal().toDouble())}",
                        style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12, decoration: TextDecoration.lineThrough)),
                      const SizedBox(height: 2),
                      Text(
                        "ছাড়: -৳ ${_fmtTk((_getCalculation().calcDoorAluTotal() - _calcDoorAluTotalDiscounted()).toDouble())}",
                        style: GoogleFonts.hindSiliguri(color: cGreen, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "ডোর অ্যালুমিনিয়াম সাবটোটাল: ৳ ${_fmtTk(_calcDoorAluTotalDiscounted().toDouble())}",
              style: GoogleFonts.hindSiliguri(color: cAccent2, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ]),
        ),
        const SizedBox(height: 14),
      ],
      if (hasWindows) ...[
        _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildHeading("কাটিং ইঞ্চি (ওভাররাইড করা যাবে)"),
          Text("প্রয়োজন অনুযায়ী এডিট করুন।",
              style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _buildTextInput(controller: _osController, label: "O/S আউটার সাইড মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: _buildTextInput(controller: _otController, label: "O/T আউটার টপ মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildTextInput(controller: _ohbController, label: "OHB আউটার হাই বটম মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: _buildTextInput(controller: _slController, label: "S/L শাটার লক মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildTextInput(controller: _ilController, label: "I/L ইন্টারলক মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
            const SizedBox(width: 8),
            Expanded(child: _buildTextInput(controller: _stController, label: "S/T শাটার টপ মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _buildTextInput(controller: _sbController, label: "S/B শাটার বটম মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
            const SizedBox(width: 8),
            if (_selectedThaiColorSet?.profileSize.contains('4') == true)
              Expanded(child: _buildTextInput(controller: _nsController, label: "N/S নেট সেকশন মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {})))
            else
              const Expanded(child: SizedBox()),
          ]),
          if (_selectedThaiColorSet?.profileSize.contains('4') == true) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _buildTextInput(controller: _nhController, label: "N/H নেট হ্যান্ডেল মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ]),
          ],
        ])),
        const SizedBox(height: 14),
        _buildCard(
          borderColor: cAccent.withOpacity(0.3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildHeading("📊 বার ব্রেকডাউন"),
            const SizedBox(height: 12),
            _buildAluBreakdownTable(),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showStep1DiscountDialog(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _brandDiscount > 0
                      ? cYellow.withOpacity(0.08)
                      : cBorder.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _brandDiscount > 0
                        ? cYellow.withOpacity(0.3)
                        : cBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_offer_rounded,
                            color: _brandDiscount > 0 ? cYellow : cMuted, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _brandDiscount > 0
                              ? "ডিসকাউন্ট (-${_brandDiscount.toStringAsFixed(0)}%)"
                              : "ডিসকাউন্ট (0%)",
                          style: GoogleFonts.hindSiliguri(
                            color: _brandDiscount > 0 ? cYellow : cMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.edit_rounded,
                            color: _brandDiscount > 0 ? cYellow : cMuted, size: 14),
                      ],
                    ),
                    if (_brandDiscount > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        "মূল দাম: ৳ ${_fmtTk(_getCalculation().calcAluTotal().toDouble())}",
                        style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12, decoration: TextDecoration.lineThrough)),
                      const SizedBox(height: 2),
                      Text(
                        "ছাড়: -৳ ${_fmtTk((_getCalculation().calcAluTotal() - _calcWindowAluTotalDiscounted()).toDouble())}",
                        style: GoogleFonts.hindSiliguri(color: cGreen, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            Text(
              "অ্যালুমিনিয়াম সাবটোটাল: ৳ ${_fmtTk(_calcAluTotal().toDouble())}",
              style: GoogleFonts.hindSiliguri(color: cGreen, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ),
      ],
    ]);
  }
  Widget _buildDoorBreakdownTable() {
    final doorSet = _getDoorColorSet();
    if (doorSet == null) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text("এই ব্র্যান্ড/কালারে সিঙ্গেল ডোরের রেট পাওয়া যায়নি",
            style: GoogleFonts.hindSiliguri(color: cRed, fontSize: 12)),
      );
    }
    final cuts = _getCalculation().calcDoorCutInches();
    final specInches = WindowCalculation.calcSpecLengthInches(doorSet.specLength);

    final rows = [
      {"name": "O/S আউটার সাইড", "inch": cuts['os']!, "price": doorSet.priceOs},
      {"name": "O/T আউটার টপ", "inch": cuts['ot']!, "price": doorSet.priceOt},
      {"name": "Low Bottom", "inch": cuts['ohb']!, "price": doorSet.priceOhb},
      {"name": "Shutter Lock", "inch": cuts['sl']!, "price": doorSet.priceSl},
      {"name": "Shutter Top", "inch": cuts['st']!, "price": doorSet.priceSt},
      {"name": "Shutter Bottom", "inch": cuts['sb']!, "price": doorSet.priceSb},
      {"name": "1.75 Box", "inch": cuts['box']!, "price": doorSet.priceBox175 ?? 0},
      {"name": "Fitting Angle", "inch": cuts['fittingAngle']!, "price": doorSet.priceFittingAngle ?? 0},
    ];

    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(flex: 3, child: Text("সেকশন", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11))),
        SizedBox(width: 42, child: Text("ইঞ্চি", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
        SizedBox(width: 40, child: Text("বার", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
        SizedBox(width: 55, child: Text("দর/বার", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
        SizedBox(width: 65, child: Text("দাম (Tk)", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
      ]),
      const SizedBox(height: 6),
      const Divider(color: cBorder, height: 1),
      const SizedBox(height: 8),
      for (var row in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(flex: 3, child: Text(row['name'] as String,
                style: GoogleFonts.hindSiliguri(color: cText, fontSize: 13))),
            SizedBox(width: 42,
                child: Text("${(row['inch'] as double).toStringAsFixed(0)}\"",
                    style: GoogleFonts.inter(color: cMuted, fontSize: 12),
                    textAlign: TextAlign.right)),
            Container(width: 40, alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: cAccent2, borderRadius: BorderRadius.circular(4)),
                  child: Text(_formatBar(WindowCalculation.inchToBars(row['inch'] as double, specLengthInches: specInches)),
                      style: GoogleFonts.inter(color: cBg, fontSize: 10, fontWeight: FontWeight.bold)),
                )),
            SizedBox(width: 55,
                child: _doorBrandDiscount > 0
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("${row['price']}",
                              style: GoogleFonts.inter(color: cMuted, fontSize: 12)),
                          Text("${((row['price'] as int) * (1 - _doorBrandDiscount / 100)).round()}",
                              style: GoogleFonts.inter(color: cGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      )
                    : Text("${row['price']}",
                        style: GoogleFonts.inter(color: cMuted, fontSize: 12),
                        textAlign: TextAlign.right)),
            SizedBox(width: 65,
                child: Text("${(WindowCalculation.inchToBars(row['inch'] as double, specLengthInches: specInches) * (row['price'] as int) * (1 - _doorBrandDiscount / 100)).round()}",
                    style: GoogleFonts.inter(color: cGreen, fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right)),
          ]),
        ),
    ]);
  }

  Widget _buildAluBreakdownTable() {
  if (_selectedThaiColorSet == null) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text("সেটআপ সম্পন্ন হয়নি", style: GoogleFonts.hindSiliguri(color: cMuted)),
    );
  }
  double osI = double.tryParse(_osController.text) ?? 0;
  double otI = double.tryParse(_otController.text) ?? 0;
  double ohbI = double.tryParse(_ohbController.text) ?? 0;
  double slI = double.tryParse(_slController.text) ?? 0;
  double ilI = double.tryParse(_ilController.text) ?? 0;
  double stI = double.tryParse(_stController.text) ?? 0;
  double sbI = double.tryParse(_sbController.text) ?? 0;

  final rows = [
    {"name": "O/S আউটার সাইড", "inch": osI, "price": _selectedThaiColorSet!.priceOs},
    {"name": "O/T আউটার টপ", "inch": otI, "price": _selectedThaiColorSet!.priceOt},
    {"name": "OHB আউটার হাই বটম", "inch": ohbI, "price": _selectedThaiColorSet!.priceOhb},
    {"name": "S/L শাটার লক", "inch": slI, "price": _selectedThaiColorSet!.priceSl},
    {"name": "I/L ইন্টারলক", "inch": ilI, "price": _selectedThaiColorSet!.priceIl},
    {"name": "S/T শাটার টপ", "inch": stI, "price": _selectedThaiColorSet!.priceSt},
    {"name": "S/B শাটার বটম", "inch": sbI, "price": _selectedThaiColorSet!.priceSb},
  ];
  if (_selectedThaiColorSet!.profileSize.contains('4')) {
    double nsI = double.tryParse(_nsController.text) ?? 0;
    double nhI = double.tryParse(_nhController.text) ?? 0;
    rows.add({"name": "N/S নেট সেকশন", "inch": nsI, "price": _selectedThaiColorSet!.priceNs ?? 0});
    rows.add({"name": "N/H নেট হ্যান্ডেল", "inch": nhI, "price": _selectedThaiColorSet!.priceNb ?? 0});
  }
  return Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Expanded(flex: 3, child: Text("সেকশন", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11))),
      SizedBox(width: 42, child: Text("ইঞ্চি", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
      SizedBox(width: 40, child: Text("বার", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
      SizedBox(width: 55, child: Text("দর/বার", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
      SizedBox(width: 65, child: Text("দাম (Tk)", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
    ]),
    const SizedBox(height: 6),
    const Divider(color: cBorder, height: 1),
    const SizedBox(height: 8),
    for (var row in rows)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(flex: 3, child: Text(row['name'] as String,
              style: GoogleFonts.hindSiliguri(color: cText, fontSize: 13))),
          SizedBox(width: 42,
              child: Text("${(row['inch'] as double).toStringAsFixed(0)}\"",
                  style: GoogleFonts.inter(color: cMuted, fontSize: 12),
                  textAlign: TextAlign.right)),
          Container(width: 40, alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(color: cAccent2, borderRadius: BorderRadius.circular(4)),
                child: Text(_formatBar(_inchToBars(row['inch'] as double)),
                    style: GoogleFonts.inter(color: cBg, fontSize: 10, fontWeight: FontWeight.bold)),
              )),
          SizedBox(width: 55,
              child: _brandDiscount > 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${row['price']}",
                            style: GoogleFonts.inter(color: cMuted, fontSize: 12)),
                        Text("${((row['price'] as int) * (1 - _brandDiscount / 100)).round()}",
                            style: GoogleFonts.inter(color: cGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    )
                  : Text("${row['price']}",
                      style: GoogleFonts.inter(color: cMuted, fontSize: 12),
                      textAlign: TextAlign.right)),
          SizedBox(width: 65,
              child: Text("${(_inchToBars(row['inch'] as double) * (row['price'] as int) * (1 - _brandDiscount / 100)).round()}",
                  style: GoogleFonts.inter(color: cGreen, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
        ]),
      ),
  ]);
}

  Widget _buildStep3() {
    final calc = _getCalculation();
    final hasWindows = _windowsList.any((w) => (w['type'] ?? 'window') != 'door');
    final hwItems = calc.calcHardwareBreakdown();
    final doorHwItems = calc.calcDoorHardwareBreakdown();
    final is4Inch = _selectedThaiColorSet?.profileSize.contains('4') == true;

    // Apply custom rates
    for (var item in hwItems) {
      final name = item['name'] as String;
      if (_customHwRates.containsKey(name)) {
        item['rate'] = _customHwRates[name];
        item['cost'] = (item['qty'] as int) * _customHwRates[name]!;
      }
    }

    // Group items by category
    final fixed3 = hwItems.where((i) => ['স্লাইডিং লক', 'স্লাইডিং হুইল', 'সিলিকন গাম', 'রয়্যাল প্লাগ'].contains(i['name'])).toList();
    final scalable3 = hwItems.where((i) => ['স্ক্রু ১.৫"', 'স্ক্রু ০.৫"', 'মুহির', 'রাবার'].contains(i['name'])).toList();
    final fixed4 = hwItems.where((i) => ['নেট এঙ্গেল', 'নেট হুইল'].contains(i['name'])).toList();
    final scalable4 = hwItems.where((i) => ['নেট', 'রিপ্পিট'].contains(i['name'])).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── ৩'' Hardware ──
      if (hasWindows) ...[
        _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildHeading("🛠️ ৩'' হার্ডওয়্যার"),
          const SizedBox(height: 12),
          _buildHwTableHeader(),
          const Divider(color: cBorder, height: 1),
          for (var item in fixed3) _buildHwRow(item),
          for (var item in scalable3) _buildHwRow(item),
        ])),

        // ── ৪'' Extra Hardware ──
        if (is4Inch) ...[
          const SizedBox(height: 14),
          _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildHeading("🕸️ ৪'' এক্সট্রা (নেট সহ)"),
            const SizedBox(height: 12),
            _buildHwTableHeader(),
            const Divider(color: cBorder, height: 1),
            for (var item in fixed4) _buildHwRow(item),
            for (var item in scalable4) _buildHwRow(item),
          ])),
        ],
      ],

      // ── সিঙ্গেল ডোর হার্ডওয়্যার ──
      if (doorHwItems.isNotEmpty) ...[
        const SizedBox(height: 14),
        _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildHeading("🚪 সিঙ্গেল ডোর হার্ডওয়্যার"),
          const SizedBox(height: 12),
          _buildHwTableHeader(),
          const Divider(color: cBorder, height: 1),
          for (var item in doorHwItems) _buildHwRow(item),
        ])),
      ],

      const SizedBox(height: 14),
      // ── Total ──
      _buildCard(
        borderColor: cYellow.withOpacity(0.3),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("মোট এলাকা: ${_calcTotalSft().toStringAsFixed(2)} Sft",
              style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13)),
          Text("হার্ডওয়্যার সাবটোটাল: ৳ ${_fmtTk(_calcHwTotalCustom())}",
              style: GoogleFonts.hindSiliguri(color: cYellow, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ),
    ]);
  }

  Widget _buildHwTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 3, child: Text("আইটেম", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11))),
        SizedBox(width: 45, child: Text("পরিমাণ", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
        SizedBox(width: 35, child: Text("ইউনিট", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
        SizedBox(width: 70, child: Text("দর ✏️", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
        SizedBox(width: 65, child: Text("মোট", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _buildHwRow(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final customRate = _customHwRates[name];
    final defaultRate = (item['rate'] as num?)?.toDouble() ?? 0;
    final rate = customRate ?? defaultRate;
    final qty = item['qty'];
    final cost = (qty is int ? qty : (qty as num).toInt()) * rate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 3, child: Text("$name",
            style: GoogleFonts.hindSiliguri(color: cText, fontSize: 12))),
        SizedBox(width: 45, child: Text("$qty",
            style: GoogleFonts.inter(color: cText, fontSize: 12), textAlign: TextAlign.center)),
        SizedBox(width: 35, child: Text("${item['unit']}",
            style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
        SizedBox(width: 70, child: GestureDetector(
          onTap: () => _showRateEditDialog(name, rate),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: customRate != null ? cAccent2.withOpacity(0.15) : cBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: customRate != null ? cAccent2.withOpacity(0.5) : cBorder),
            ),
            child: Text("৳${_fmtRate(rate)} ✏",
                style: GoogleFonts.inter(
                  color: customRate != null ? cAccent2 : cAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ), textAlign: TextAlign.right),
          ),
        )),
        SizedBox(width: 65, child: Text("৳${_fmtTk(cost)}",
            style: GoogleFonts.inter(color: cGreen, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ]),
    );
  }

  void _showRateEditDialog(String name, double currentRate) {
    final calc = _getCalculation();
    final hwItems = calc.calcHardwareBreakdown();
    double defaultRate = 0;
    for (var item in hwItems) {
      if (item['name'] == name) {
        defaultRate = (item['rate'] as num?)?.toDouble() ?? 0;
        break;
      }
    }
    final controller = TextEditingController(text: currentRate.toStringAsFixed(currentRate == currentRate.roundToDouble() ? 0 : 2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCard,
        title: Text("$name — দর পরিবর্তন", style: GoogleFonts.hindSiliguri(color: cText)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: GoogleFonts.inter(color: cText, fontSize: 16),
          decoration: InputDecoration(
            labelText: "নতুন দর (৳)",
            labelStyle: GoogleFonts.hindSiliguri(color: cMuted),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); setState(() => _customHwRates.remove(name)); },
            child: Text("রিসেট", style: GoogleFonts.hindSiliguri(color: cAccent2)),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("বাতিল", style: GoogleFonts.hindSiliguri(color: cMuted))),
          ElevatedButton(
            onPressed: () {
              final newRate = double.tryParse(controller.text);
              if (newRate != null && newRate >= 0) {
                setState(() {
                  if (newRate == defaultRate) {
                    _customHwRates.remove(name);
                  } else {
                    _customHwRates[name] = newRate;
                  }
                });
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: cAccent),
            child: Text("সেভ", style: GoogleFonts.hindSiliguri(color: cBg)),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterRow(String label, int value, ValueChanged<int> onChange) {
    return Row(children: [
      Expanded(child: Text(label, style: GoogleFonts.hindSiliguri(color: cText, fontSize: 13))),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFF12151F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.remove, color: cRed, size: 18),
              onPressed: () => onChange(math.max(0, value - 1))),
          SizedBox(width: 32,
              child: Text(value.toString(), textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: cText, fontWeight: FontWeight.bold, fontSize: 14))),
          IconButton(icon: const Icon(Icons.add, color: cGreen, size: 18),
              onPressed: () => onChange(value + 1)),
        ]),
      ),
    ]);
  }

  Widget _buildStep4() {
    final calc = _getCalculation();
    final hasWindows = _windowsList.any((w) => (w['type'] ?? 'window') != 'door');
    final hasDoors = _windowsList.any((w) => w['type'] == 'door');
    double totalSft = calc.calcTotalSft();
    int aluTotal = calc.calcAluTotal();
    int aluTotalAfterDiscount = _calcAluTotal();
    double hwTotal = _calcHwTotalCustom();
    double glassTotal = calc.calcGlassTotal();
    double labor = calc.labor;
    double fare = double.tryParse(_fareController.text) ?? 0;
    double advance = calc.advance;
    double grandTotal = aluTotalAfterDiscount.toDouble() + glassTotal + hwTotal + labor + fare;
    double due = grandTotal - advance;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeading("👤 কাস্টমারের তথ্য"),
        const SizedBox(height: 12),
        _buildTextInput(
          controller: _customerNameController,
          label: "কাস্টমারের নাম *",
          onChanged: (v) => setState(() {}),
        ),
        const SizedBox(height: 10),
        _buildTextInput(
          controller: _customerPhoneController,
          label: "ফোন নম্বর (WhatsApp)",
          isNumber: true,
        ),
      ])),
      const SizedBox(height: 14),
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeading("💰 লেবার ও অগ্রিম"),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildTextInput(
            controller: _laborRateController,
            label: "দর / Sft (Tk)",
            isNumber: true,
            onChanged: (v) {
              double rate = double.tryParse(v) ?? 0;
              double totalSft = _calcTotalSft();
              setState(() {
                _laborController.text = (totalSft * rate).toStringAsFixed(0);
              });
            },
          )),
          const SizedBox(width: 8),
          Expanded(child: _buildTextInput(
            controller: _laborController,
            label: "মোট লেবার (Tk)",
            isNumber: true,
            onChanged: (v) {
              double total = double.tryParse(v) ?? 0;
              double totalSft = _calcTotalSft();
              if (totalSft > 0) {
                _laborRateController.text = (total / totalSft).toStringAsFixed(1);
              }
            },
          )),
        ]),
        const SizedBox(height: 6),
        Text("মোট এলাকা: ${_calcTotalSft().toStringAsFixed(2)} Sft",
            style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11)),
        const SizedBox(height: 10),
        _buildTextInput(
          controller: _fareController,
          label: "গাড়ি ভাড়া — Transport Fare (Tk)",
          isNumber: true,
          onChanged: (v) => setState(() {}),
        ),
        const SizedBox(height: 10),
        _buildTextInput(
          controller: _advanceController,
          label: "অগ্রিম জমা — Advance (Tk)",
          isNumber: true,
          onChanged: (v) => setState(() {}),
        ),
      ])),
      const SizedBox(height: 14),
      _buildCard(
        borderColor: cAccent2.withOpacity(0.4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildHeading("🧾 ফাইনাল ইনভয়েস"),
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final hasWindowsHere = _windowsList.any((w) => (w['type'] ?? 'window') != 'door');
            final hasDoorsHere = _windowsList.any((w) => w['type'] == 'door');

            final brandItems = (() {
              final allB = _thaiColorSets
                  .where((e) => e.model == _selectedModel && e.profileSize != 'single_door')
                  .map((e) => e.brand)
                  .toSet()
                  .toList();
              return _selectedBrands.isEmpty
                  ? allB
                  : allB.where((b) => _selectedBrands.contains(b)).toList();
            })();

            final colorItems = _thaiColorSets
                .where((e) =>
                    e.model == _selectedModel &&
                    e.brand == _selectedBrandName &&
                    e.profileSize != 'single_door')
                .map((e) => e.color)
                .toSet()
                .toList();

            final doorBrandItems = _thaiColorSets
                .where((e) => e.model == _selectedModel && e.profileSize == 'single_door')
                .map((e) => e.brand)
                .toSet()
                .toList();
            final doorColorItems = _thaiColorSets
                .where((e) =>
                    e.model == _selectedModel &&
                    e.brand == _selectedDoorBrandName &&
                    e.profileSize == 'single_door')
                .map((e) => e.color)
                .toSet()
                .toList();

            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (hasWindowsHere) ...[
                Text("🪟 জানালার প্রোফাইল", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: _buildCompactDropdown(
                    label: "ব্র্যান্ড",
                    value: brandItems.contains(_selectedBrandName) ? _selectedBrandName : null,
                    items: brandItems,
                    onChanged: (v) => setState(() {
                      _selectedBrandName = v;
                      _updateColorsForBrand();
                    }),
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: _buildCompactDropdown(
                    label: "কালার",
                    value: colorItems.contains(_selectedColorName) ? _selectedColorName : null,
                    items: colorItems,
                    onChanged: (v) => setState(() {
                      _selectedColorName = v;
                      _updateProfileSizesForColor();
                    }),
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: _buildCompactProfileSizeDropdown()),
                ]),
              ],
              if (hasWindowsHere && hasDoorsHere) const SizedBox(height: 10),
              if (hasDoorsHere) ...[
                Text("🚪 সিঙ্গেল ডোর প্রোফাইল", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: _buildCompactDropdown(
                    label: "ব্র্যান্ড",
                    value: doorBrandItems.contains(_selectedDoorBrandName) ? _selectedDoorBrandName : null,
                    items: doorBrandItems,
                    onChanged: (v) => setState(() {
                      _selectedDoorBrandName = v;
                      final dc = _thaiColorSets
                          .where((e) => e.model == _selectedModel && e.brand == v && e.profileSize == 'single_door')
                          .map((e) => e.color)
                          .toSet()
                          .toList();
                      _selectedDoorColorName = dc.isNotEmpty ? dc.first : null;
                    }),
                  )),
                  const SizedBox(width: 6),
                  Expanded(child: _buildCompactDropdown(
                    label: "কালার",
                    value: doorColorItems.contains(_selectedDoorColorName) ? _selectedDoorColorName : null,
                    items: doorColorItems,
                    onChanged: (v) => setState(() => _selectedDoorColorName = v),
                  )),
                ]),
              ],
            ]);
          }),
          const SizedBox(height: 14),
          if (hasWindows && _brandDiscount > 0) ...[
            _buildInvoiceRow("🪟 জানালা অ্যালু (মূল)", calc.calcAluTotal().toDouble(), color: cMuted),
            _buildInvoiceRow("  (-${_brandDiscount.toStringAsFixed(0)}% ডিসকাউন্ট)", -(calc.calcAluTotal().toDouble() - _calcWindowAluTotalDiscounted().toDouble()), color: cYellow),
          ],
          if (hasDoors && _doorBrandDiscount > 0) ...[
            _buildInvoiceRow("🚪 ডোর অ্যালু (মূল)", calc.calcDoorAluTotal().toDouble(), color: cMuted),
            _buildInvoiceRow("  (-${_doorBrandDiscount.toStringAsFixed(0)}% ডিসকাউন্ট)", -(calc.calcDoorAluTotal().toDouble() - _calcDoorAluTotalDiscounted().toDouble()), color: cYellow),
          ],
          _buildInvoiceRow("🔩 অ্যালুমিনিয়াম বার", aluTotalAfterDiscount.toDouble()),
          if (hasWindows && hasDoors && calc.hasSeparateDoorGlass) ...[
            _buildInvoiceRow("🪟 জানালার গ্লাস (${calc.calcWindowSft().toStringAsFixed(1)} Sft)", calc.calcWindowGlassTotal()),
            _buildInvoiceRow("🚪 ডোরের গ্লাস (${calc.calcDoorSft().toStringAsFixed(1)} Sft)", calc.calcDoorGlassTotal()),
          ] else
            _buildInvoiceRow("🪟 গ্লাস (${totalSft.toStringAsFixed(1)} Sft)", glassTotal),
          _buildInvoiceRow("🔧 হার্ডওয়্যার", hwTotal),
          _buildInvoiceRow("👷 লেবার / ফিটিং", labor),
          if (fare > 0) _buildInvoiceRow("🚗 গাড়ি ভাড়া", fare),
          const SizedBox(height: 6),
          const Divider(color: cBorder),
          const SizedBox(height: 6),
          _buildInvoiceRow("মোট বিল (Grand Total)", grandTotal,
              isBold: true, color: cAccent, size: 16),
          if (totalSft > 0) ...[
            const SizedBox(height: 4),
            _buildInvoiceRow("গড় খরচ / Sft", grandTotal / totalSft,
                isBold: false, color: cText.withOpacity(0.85), size: 13),
          ],
          const SizedBox(height: 4),
          _buildInvoiceRow("(−) অগ্রিম জমা", advance, color: cYellow),
          const SizedBox(height: 6),
          const Divider(color: cAccent2, thickness: 1.5),
          const SizedBox(height: 6),
          _buildInvoiceRow("বাকি (Due)", due,
              isBold: true, color: cAccent2, size: 20),
        ]),
      ),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: _shareWhatsApp,
        style: ElevatedButton.styleFrom(
          backgroundColor: cWhatsApp,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.send_rounded, size: 18),
        label: Text("WhatsApp-এ বিল পাঠান",
            style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 10),
      ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveInvoice,
        style: ElevatedButton.styleFrom(
          backgroundColor: cAccent,
          foregroundColor: cBg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          disabledBackgroundColor: cAccent.withOpacity(0.4),
        ),
        icon: _isSaving
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.save_rounded, size: 18),
        label: Text(_isSaving ? "সেভ হচ্ছে..." : "হিসাব সেভ করুন",
            style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _buildCompactDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      dropdownColor: cCard,
      style: GoogleFonts.hindSiliguri(color: cText, fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 9),
        filled: true, fillColor: const Color(0xFF12151F),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: cBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: cAccent2)),
      ),
      items: items.map((v) =>
          DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildCompactProfileSizeDropdown() {
    final profileSizeList = _thaiColorSets
        .where((e) =>
            e.model == _selectedModel &&
            e.brand == _selectedBrandName &&
            e.color == _selectedColorName &&
            e.profileSize != 'single_door')
        .map((e) => e.profileSize)
        .toSet()
        .toList();
    return DropdownButtonFormField<String>(
      value: profileSizeList.contains(_selectedProfileSize) ? _selectedProfileSize : null,
      isExpanded: true,
      dropdownColor: cCard,
      style: GoogleFonts.hindSiliguri(color: cText, fontSize: 11),
      decoration: InputDecoration(
        labelText: "জানালার ধরন",
        labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 9),
        filled: true, fillColor: const Color(0xFF12151F),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: cBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: cAccent2)),
      ),
      items: profileSizeList.map((v) =>
          DropdownMenuItem(
            value: v, 
            child: Text(v.contains('4') ? '৪" (নেট সহ)' : '৩" (নেট ছাড়া)', style: const TextStyle(fontSize: 10)),
          )).toList(),
      onChanged: (v) {
        setState(() {
          _selectedProfileSize = v;
          _updateSelectedThaiColorSet();
        });
        // Profile size change hole labor rate auto update
        double totalSft = _calcTotalSft();
        double newRate = (v != null && v.contains('4')) ? 30 : 25;
        _laborRateController.text = newRate.toStringAsFixed(0);
        _laborController.text = (totalSft * newRate).toStringAsFixed(0);
      },
    );
  }

  Widget _buildInvoiceRow(String label, double amount,
      {bool isBold = false, Color? color, double size = 14}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: GoogleFonts.hindSiliguri(
                color: isBold ? cText : cMuted,
                fontSize: size - 1,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text("৳ ${_fmtTk(amount)}",
            style: GoogleFonts.inter(
                color: color ?? cText, fontSize: size, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String label,
    bool isNumber = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: GoogleFonts.inter(color: cText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12),
        filled: true, fillColor: const Color(0xFF12151F),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: cBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: cAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    if (_currentStep == 1) {
      return ElevatedButton(
        onPressed: _nextStep,
        style: ElevatedButton.styleFrom(
            backgroundColor: cAccent, foregroundColor: cBg,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text("পরবর্তী: অ্যালুমিনিয়াম →",
            style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.bold)),
      );
    } else if (_currentStep == 4) {
      return Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _backStep,
            style: OutlinedButton.styleFrom(
                foregroundColor: cMuted,
                side: const BorderSide(color: cBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text("← পেছনে",
                style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _resetAll,
            style: ElevatedButton.styleFrom(
                backgroundColor: cAccent2, foregroundColor: cText,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text("🔄 নতুন হিসাব",
                style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ]);
    } else {
      String nextText = _currentStep == 2 ? "পরবর্তী: হার্ডওয়্যার →" : "পরবর্তী: ফাইনাল বিল →";
      return Row(children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _backStep,
            style: OutlinedButton.styleFrom(
                foregroundColor: cMuted,
                side: const BorderSide(color: cBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text("← পেছনে",
                style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
                backgroundColor: cAccent, foregroundColor: cBg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(nextText,
                style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ]);
    }
  }

  String _fmtTk(double amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  // রেট যদি পূর্ণসংখ্যা না হয়, দশমিক সহ দেখানো হয় যাতে দর × পরিমাণ = মোট ঠিকঠাক মিলে
  String _fmtRate(double rate) {
    if (rate == rate.roundToDouble()) {
      // পূর্ণসংখ্যা রেট — যেমন ২, ১২৫
      return _fmtTk(rate);
    }
    // দশমিক রেট — trailing zero বাদ দিয়ে যত ডিজিট দরকার তত দেখাবে (সর্বোচ্চ ২ ঘর)
    String s = rate.toStringAsFixed(2);
    if (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}