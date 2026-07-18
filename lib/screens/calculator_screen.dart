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

  bool _isLoadingBrands = true;

  int _currentStep = 1;
  final List<Map<String, dynamic>> _windowsList = [];

  final _winNameController = TextEditingController(text: "Window 1");
  final _winWidthController = TextEditingController(text: "84");
  final _winHeightController = TextEditingController(text: "72");
  final _winQtyController = TextEditingController(text: "1");

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
  final _advanceController = TextEditingController(text: "0");

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  @override
  void dispose() {
    _winNameController.dispose();
    _winWidthController.dispose();
    _winHeightController.dispose();
    _winQtyController.dispose();
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
      
      setState(() {
        _thaiColorSets = thais;
        _glassBrands = glasses;
        _hardwarePrices = hardwares;
        
        if (glasses.isNotEmpty) {
          _selectedGlassBrand = glasses.first;
        }
        
        if (thais.isNotEmpty) {
          _selectedBrandName = thais.first.brand;
          _updateColorsForBrand();
        }
        
        _isLoadingBrands = false;
      });
    } catch (e) {
      print("Error loading brands from database: $e");
      setState(() => _isLoadingBrands = false);
    }
  }

  void _updateColorsForBrand() {
    if (_selectedBrandName == null || _thaiColorSets.isEmpty) return;
    
    final colors = _thaiColorSets
        .where((e) => e.brand == _selectedBrandName)
        .map((e) => e.color)
        .toSet()
        .toList();
    
    setState(() {
      _selectedColorName = colors.isNotEmpty ? colors.first : null;
      _updateProfileSizesForColor();
    });
  }

  void _updateProfileSizesForColor() {
    if (_selectedBrandName == null || _selectedColorName == null || _thaiColorSets.isEmpty) return;
    
    final sizes = _thaiColorSets
        .where((e) => e.brand == _selectedBrandName && e.color == _selectedColorName)
        .map((e) => e.profileSize)
        .toSet()
        .toList();
        
    setState(() {
      _selectedProfileSize = sizes.isNotEmpty ? sizes.first : null;
      _updateSelectedThaiColorSet();
    });
  }

  void _updateSelectedThaiColorSet() {
  try {
    _selectedThaiColorSet = _thaiColorSets.firstWhere((e) =>
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
      selectedGlassBrand: _selectedGlassBrand,
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
  int _calcAluTotal() => _getCalculation().calcAluTotal();
  double _calcHwTotal() => _getCalculation().calcHwTotal();
  double _calcSft(double w, double h, int qty) => WindowCalculation.calcSft(w, h, qty);
  double _inchToBars(double inch) => WindowCalculation.inchToBars(inch);

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
    if (name.isEmpty) name = "Window ${_windowsList.length + 1}";
    setState(() {
      _windowsList.add({'name': name, 'w': w, 'h': h, 'qty': q});
      _winNameController.text = "Window ${_windowsList.length + 1}";
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
      _advanceController.text = "0";
      _customerNameController.clear();
      _customerPhoneController.clear();
    });
  }

  Future<void> _shareWhatsApp() async {
    final calc = _getCalculation();
    double totalSft = calc.calcTotalSft();
    int aluTotal = calc.calcAluTotal();
    double hwTotal = calc.calcHwTotal();
    double glassTotal = calc.calcGlassTotal();
    double labor = calc.labor;
    double advance = calc.advance;
    double grandTotal = calc.calcGrandTotal();
    double due = calc.calcDue();

    final name = _customerNameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar("কাস্টমারের নাম দিন!", cRed);
      return;
    }
    final phone = _customerPhoneController.text.trim();

    final formattedDate = DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());

    final message = "*Thai Calc Pro - বিল রশিদ*\n"
        "------------------------------------\n"
        "👤 কাস্টমার: $name\n"
        "${phone.isNotEmpty ? "📞 ফোন: $phone\n" : ""}"
        "📅 তারিখ: $formattedDate\n"
        "------------------------------------\n"
        "📐 মোট মাপ: ${totalSft.toStringAsFixed(1)} Sft\n"
        "💵 অ্যালুমিনিয়াম খরচ: ৳ ${_fmtTk(aluTotal.toDouble())}\n"
        "🥛 গ্লাস খরচ: ৳ ${_fmtTk(glassTotal)}\n"
        "🔩 হার্ডওয়্যার খরচ: ৳ ${_fmtTk(hwTotal.toDouble())}\n"
        "🛠️ মজুরি / ফিটিং: ৳ ${_fmtTk(labor)}\n"
        "------------------------------------\n"
        "💰 সর্বমোট বিল: ৳ ${_fmtTk(grandTotal)}\n"
        "💳 অগ্রিম জমা: ৳ ${_fmtTk(advance)}\n"
        "🔴 বকেয়া / বাকি: ৳ ${_fmtTk(due)}\n"
        "------------------------------------\n"
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
      final invoice = {
        'name': name,
        'phone': _customerPhoneController.text.trim(),
        'brand': _selectedThaiColorSet?.brand ?? 'Thai',
        'color': _selectedThaiColorSet?.color ?? '',
        'thickness': (_selectedThaiColorSet?.profileSize.contains('4') == true) ? 4.0 : 3.0,
        'profile_size': _selectedThaiColorSet?.profileSize ?? '3"',
        'glassBrand': _selectedGlassBrand?.brandName ?? '',
        'glassRate': _selectedGlassBrand?.pricePerSft ?? 0,
        'hwRate': double.tryParse(_hwRateController.text) ?? 25,
        'laborRate': double.tryParse(_laborRateController.text) ?? 0,
        'total': calc.calcGrandTotal(),
        'due': calc.calcDue(),
        'date': DateTime.now().toIso8601String(),
        'windows': _windowsList,
        'totalSft': calc.calcTotalSft(),
        'aluTotal': calc.calcAluTotal(),
        'glassTotal': calc.calcGlassTotal(),
        'hwTotal': calc.calcHwTotal(),
        'labor': calc.labor,
        'advance': calc.advance,
        'dlCount': _dlCount,
        'swCount': _swCount,
        'scCount': _scCount,
        'snCount': _snCount,
        'cuts': {
          'os': double.tryParse(_osController.text) ?? 0,
          'ot': double.tryParse(_otController.text) ?? 0,
          'ohb': double.tryParse(_ohbController.text) ?? 0,
          'sl': double.tryParse(_slController.text) ?? 0,
          'il': double.tryParse(_ilController.text) ?? 0,
          'st': double.tryParse(_stController.text) ?? 0,
          'sb': double.tryParse(_sbController.text) ?? 0,
          'ns': double.tryParse(_nsController.text) ?? 0,
          'nh': double.tryParse(_nhController.text) ?? 0,
        },
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
      _showSnackBar("হিসাব সেভ হয়েছে! ✓", cGreen);
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
    // Collect distinct brand list
    final brandsList = _thaiColorSets.map((e) => e.brand).toSet().toList();
    // Colors matching selected brand
    final colorsList = _thaiColorSets
        .where((e) => e.brand == _selectedBrandName)
        .map((e) => e.color)
        .toSet()
        .toList();
    // Profile size list matching selected brand and color
    final profileSizeList = _thaiColorSets
        .where((e) => e.brand == _selectedBrandName && e.color == _selectedColorName)
        .map((e) => e.profileSize)
        .toSet()
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
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
          // Cascading Brand Dropdown
          DropdownButtonFormField<String>(
            value: _selectedBrandName,
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
          const SizedBox(height: 12),
          // Cascading Color Dropdown
          DropdownButtonFormField<String>(
            value: _selectedColorName,
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
          // Cascading Profile Size Dropdown
          DropdownButtonFormField<String>(
            value: _selectedProfileSize,
            dropdownColor: cCard,
            style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
            decoration: InputDecoration(
              labelText: "জানালার ধরন সিলেক্ট করুন",
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
                  child: Text(v.contains('4') ? '৪" (নেট সহ)' : '৩" (নেট ছাড়া)'),
                )).toList(),
            onChanged: (v) {
              setState(() {
                _selectedProfileSize = v;
                _updateSelectedThaiColorSet();
              });
            },
          ),
          const SizedBox(height: 12),
          // Glass Brand Dropdown
          DropdownButtonFormField<GlassBrand>(
            value: _selectedGlassBrand,
            dropdownColor: cCard,
            style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14),
            decoration: InputDecoration(
              labelText: "গ্লাস ব্র্যান্ড / টাইপ সিলেক্ট করুন",
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
        ],
      ])),
      const SizedBox(height: 14),
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeading("➕ নতুন জানালা যোগ করুন"),
        const SizedBox(height: 12),
        _buildTextInput(controller: _winNameController, label: "জানালার নাম / লোকেশন"),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildTextInput(controller: _winWidthController, label: "উচ্চতা (H) ইঞ্চি", isNumber: true)),
          const SizedBox(width: 8),
          Expanded(child: _buildTextInput(controller: _winHeightController, label: "প্রস্থ (W) ইঞ্চি", isNumber: true)),
          const SizedBox(width: 8),
          Expanded(child: _buildTextInput(controller: _winQtyController, label: "পরিমাণ (Qty)", isNumber: true)),
        ]),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _addWindow,
          style: ElevatedButton.styleFrom(
              backgroundColor: cAccent, foregroundColor: cBg,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          icon: const Icon(Icons.add, size: 20),
          label: Text("ADD WINDOW", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
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
                    Text("#${idx + 1}  ${w['name']}",
                        style: GoogleFonts.hindSiliguri(
                            color: cText, fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: cAccent, borderRadius: BorderRadius.circular(4)),
                      child: Text("${sft.toStringAsFixed(1)} Sft",
                          style: GoogleFonts.inter(color: cBg, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("W: ${w['w']}\"  ×  H: ${w['h']}\"  ×  Qty: ${w['qty']}",
                        style: GoogleFonts.inter(color: cMuted, fontSize: 12)),
                    TextButton(
                      onPressed: () => setState(() => _windowsList.removeAt(idx)),
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
          Text("মোট জানালা: ${_windowsList.length} টি",
              style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14)),
          Text("মোট এলাকা: ${_calcTotalSft().toStringAsFixed(2)} Sft",
              style: GoogleFonts.hindSiliguri(
                  color: cAccent, fontWeight: FontWeight.bold, fontSize: 15)),
        ]),
      ])),
    ]);
  }

  Widget _buildStep2() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildHeading("🔩 কাটিং ইঞ্চি (ওভাররাইড করা যাবে)"),
        Text("প্রয়োজন অনুযায়ী এডিট করুন।",
            style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11, fontStyle: FontStyle.italic)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _buildTextInput(controller: _osController, label: "O/S আউটার খাড়া মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: _buildTextInput(controller: _otController, label: "O/T আউটার টপ মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildTextInput(controller: _ohbController, label: "O/B আউটার বটম মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: _buildTextInput(controller: _slController, label: "S/L পাল্লা লক মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildTextInput(controller: _ilController, label: "I/L পাল্লা ইন্টারলক মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: _buildTextInput(controller: _stController, label: "S/T পাল্লা টপ মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _buildTextInput(controller: _sbController, label: "S/B পাল্লা বটম মোট ইঞ্চি", isNumber: true, onChanged: (v) => setState(() {}))),
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
          Text(
            "অ্যালুমিনিয়াম সাবটোটাল: ৳ ${_fmtTk(_calcAluTotal().toDouble())}",
            style: GoogleFonts.hindSiliguri(color: cGreen, fontWeight: FontWeight.bold, fontSize: 15)),
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
    {"name": "O/S আউটার খাড়া", "inch": osI, "price": _selectedThaiColorSet!.priceOs},
    {"name": "O/T আউটার টপ", "inch": otI, "price": _selectedThaiColorSet!.priceOt},
    {"name": "O/B আউটার বটম", "inch": ohbI, "price": _selectedThaiColorSet!.priceOhb},
    {"name": "S/L পাল্লা লক খাড়া", "inch": slI, "price": _selectedThaiColorSet!.priceSl},
    {"name": "I/L পাল্লা ইন্টারলক", "inch": ilI, "price": _selectedThaiColorSet!.priceIl},
    {"name": "S/T পাল্লা টপ চওড়া", "inch": stI, "price": _selectedThaiColorSet!.priceSt},
    {"name": "S/B পাল্লা বটম চওড়া", "inch": sbI, "price": _selectedThaiColorSet!.priceSb},
  ];
  if (_selectedThaiColorSet!.profileSize.contains('4')) {
    double nsI = double.tryParse(_nsController.text) ?? 0;
    double nhI = double.tryParse(_nhController.text) ?? 0;
    rows.add({"name": "N/S নেট সেকশন", "inch": nsI, "price": _selectedThaiColorSet!.priceNs ?? 0});
    rows.add({"name": "N/H - নেট হ্যান্ডেল", "inch": nhI, "price": _selectedThaiColorSet!.priceNb ?? 0});
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
              child: Text("${row['price']}",
                  style: GoogleFonts.inter(color: cMuted, fontSize: 12),
                  textAlign: TextAlign.right)),
          SizedBox(width: 65,
              child: Text("${(_inchToBars(row['inch'] as double) * (row['price'] as int)).round()}",
                  style: GoogleFonts.inter(color: cGreen, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right)),
        ]),
      ),
  ]);
}

  Widget _buildStep3() {
    return _buildCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHeading("🛠️ হার্ডওয়্যার"),
      Text("লক, চাকা, স্ক্রু, রাবার সব মিলিয়ে প্রতি বর্গফুট রেট। প্রয়োজনে বদলান।",
          style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11, fontStyle: FontStyle.italic)),
      const SizedBox(height: 16),
      _buildTextInput(
        controller: _hwRateController,
        label: "হার্ডওয়্যার প্রতি বর্গফুট (৳)",
        isNumber: true,
        onChanged: (v) => setState(() {}),
      ),
      const SizedBox(height: 16),
      const Divider(color: cBorder),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text("মোট এলাকা: ${_calcTotalSft().toStringAsFixed(2)} Sft",
            style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13)),
        Text("হার্ডওয়্যার সাবটোটাল: ৳ ${_fmtTk(_calcHwTotal())}",
            style: GoogleFonts.hindSiliguri(color: cYellow, fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
    ]));
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
    double totalSft = calc.calcTotalSft();
    int aluTotal = calc.calcAluTotal();
    double hwTotal = calc.calcHwTotal();
    double glassTotal = calc.calcGlassTotal();
    double labor = calc.labor;
    double advance = calc.advance;
    double grandTotal = calc.calcGrandTotal();
    double due = calc.calcDue();

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
          Row(children: [
            Expanded(child: _buildCompactDropdown(
              label: "ব্র্যান্ড",
              value: _selectedBrandName,
              items: _thaiColorSets.map((e) => e.brand).toSet().toList(),
              onChanged: (v) => setState(() {
                _selectedBrandName = v;
                _updateColorsForBrand();
              }),
            )),
            const SizedBox(width: 6),
            Expanded(child: _buildCompactDropdown(
              label: "কালার",
              value: _selectedColorName,
              items: _thaiColorSets
                  .where((e) => e.brand == _selectedBrandName)
                  .map((e) => e.color)
                  .toSet()
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedColorName = v;
                _updateProfileSizesForColor();
              }),
            )),
            const SizedBox(width: 6),
            Expanded(child: _buildCompactProfileSizeDropdown()),
          ]),
          const SizedBox(height: 14),
          _buildInvoiceRow("🔩 অ্যালুমিনিয়াম বার", aluTotal.toDouble()),
          _buildInvoiceRow("🪟 গ্লাস (${totalSft.toStringAsFixed(1)} Sft)", glassTotal),
          _buildInvoiceRow("🔧 হার্ডওয়্যার", hwTotal),
          _buildInvoiceRow("👷 লেবার / ফিটিং", labor),
          const SizedBox(height: 6),
          const Divider(color: cBorder),
          const SizedBox(height: 6),
          _buildInvoiceRow("মোট বিল (Grand Total)", grandTotal,
              isBold: true, color: cAccent, size: 16),
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
        .where((e) => e.brand == _selectedBrandName && e.color == _selectedColorName)
        .map((e) => e.profileSize)
        .toSet()
        .toList();
    return DropdownButtonFormField<String>(
      value: _selectedProfileSize,
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
}