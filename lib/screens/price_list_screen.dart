import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import '../models/thai_color_set.dart';
import '../models/glass_brand.dart';
import '../models/hardware_price.dart';

class PriceListScreen extends StatefulWidget {
  const PriceListScreen({super.key});

  @override
  State<PriceListScreen> createState() => _PriceListScreenState();
}

class _PriceListScreenState extends State<PriceListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<ThaiColorSet> _thaiList = [];
  List<GlassBrand> _glassList = [];
  List<HardwarePrice> _hardwareList = [];
  Map<String, double> _brandDiscounts = {};
  bool _isLoading = true;

  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent = Color(0xFF00D4AA);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);
  static const Color cGreen = Color(0xFF22C55E);
  static const Color cYellow = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPrices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrices() async {
    setState(() => _isLoading = true);
    try {
      final thai = await DatabaseService.instance.getThaiColorSets();
      final glass = await DatabaseService.instance.getGlassBrands();
      final hw = await DatabaseService.instance.getHardwarePrices();
      final discounts = await DatabaseService.instance.getBrandDiscounts();
      if (mounted) {
        setState(() {
          _thaiList = thai;
          _glassList = glass;
          _hardwareList = hw;
          _brandDiscounts = discounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showDiscountDialog(String brand) async {
    final currentDiscount = _brandDiscounts[brand] ?? 0;
    final controller = TextEditingController(text: currentDiscount > 0 ? currentDiscount.toStringAsFixed(0) : '');

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
              "0 = কোনো ডিসকাউন্ট নেই",
              style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("বাতিল", style: GoogleFonts.hindSiliguri(color: cMuted)),
          ),
          if (currentDiscount > 0)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, 0.0);
              },
              child: Text("মুছুন", style: GoogleFonts.hindSiliguri(color: cAccent2)),
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
      await DatabaseService.instance.saveBrandDiscount(brand, result);
      setState(() {
        if (result > 0) {
          _brandDiscounts[brand] = result;
        } else {
          _brandDiscounts.remove(brand);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E17),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: cText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text("প্রাইস লিস্ট",
            style: GoogleFonts.hindSiliguri(fontSize: 18, fontWeight: FontWeight.bold, color: cText)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: cMuted),
            tooltip: "রিফ্রেশ",
            onPressed: _loadPrices,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: cAccent,
          labelColor: cAccent,
          unselectedLabelColor: cMuted,
          labelStyle: GoogleFonts.hindSiliguri(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.hindSiliguri(fontSize: 13),
          tabs: const [
            Tab(text: "থাই/অ্যালুমিনিয়াম"),
            Tab(text: "কাচ"),
            Tab(text: "হার্ডওয়্যার"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: cAccent))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildThaiTab(),
                _buildGlassTab(),
                _buildHardwareTab(),
              ],
            ),
    );
  }

  // ── Thai / Aluminum Tab ──
  Widget _buildThaiTab() {
    if (_thaiList.isEmpty) {
      return _buildEmpty("কোনো থাই/অ্যালুমিনিয়াম দাম পাওয়া যায়নি");
    }

    // Brand wise group
    final Map<String, List<ThaiColorSet>> grouped = {};
    for (var item in _thaiList) {
      grouped.putIfAbsent(item.brand, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: grouped.length,
      itemBuilder: (ctx, brandIdx) {
        final brand = grouped.keys.elementAt(brandIdx);
        final items = grouped[brand]!;
        final discount = _brandDiscounts[brand] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand header with discount button
              GestureDetector(
                onTap: () => _showDiscountDialog(brand),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: cAccent.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        brand,
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: cAccent),
                      ),
                      Row(
                        children: [
                          if (discount > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cGreen.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "-${discount.toStringAsFixed(0)}%",
                                style: GoogleFonts.inter(color: cGreen, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Icon(Icons.edit_rounded, color: cMuted, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Items
              for (var item in items)
                _buildThaiItem(item, discount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThaiItem(ThaiColorSet item, double brandDiscount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: cBorder, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cAccent2.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(item.color,
                    style: GoogleFonts.inter(color: cAccent2, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cMuted.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text("${item.profileSize} | ${item.specLength}",
                    style: GoogleFonts.inter(color: cMuted, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Price grid
          _buildPriceRow("O/S আউটার খাড়া", item.priceOs, brandDiscount),
          _buildPriceRow("O/T আউটার টপ", item.priceOt, brandDiscount),
          _buildPriceRow("O/B আউটার বটম", item.priceOhb, brandDiscount),
          _buildPriceRow("S/L পাল্লা লক", item.priceSl, brandDiscount),
          _buildPriceRow("I/L ইন্টারলক", item.priceIl, brandDiscount),
          _buildPriceRow("S/T পাল্লা টপ", item.priceSt, brandDiscount),
          _buildPriceRow("S/B পাল্লা বটম", item.priceSb, brandDiscount),
          if (item.profileSize.contains('4')) ...[
            if (item.priceNs != null) _buildPriceRow("N/S নেট সেকশন", item.priceNs!, brandDiscount),
            if (item.priceNb != null) _buildPriceRow("N/H নেট হ্যান্ডেল", item.priceNb!, brandDiscount),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, int price, double brandDiscount) {
    final discountedPrice = (price * (1 - brandDiscount / 100)).round();
    final hasDiscount = brandDiscount > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.hindSiliguri(color: cText, fontSize: 12)),
          Row(
            children: [
              if (hasDiscount) ...[
                Text(
                  "৳ $price",
                  style: GoogleFonts.inter(
                    color: cMuted,
                    fontSize: 11,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                "৳ ${hasDiscount ? discountedPrice : price} / বার",
                style: GoogleFonts.inter(
                  color: hasDiscount ? cGreen : cAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Glass Tab ──
  Widget _buildGlassTab() {
    if (_glassList.isEmpty) {
      return _buildEmpty("কোনো কাচের দাম পাওয়া যায়নি");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _glassList.length,
      itemBuilder: (ctx, idx) {
        final item = _glassList[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(item.brandName,
                    style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text("৳ ${item.pricePerSft}/SQF",
                    style: GoogleFonts.inter(color: cAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Hardware Tab ──
  Widget _buildHardwareTab() {
    if (_hardwareList.isEmpty) {
      return _buildEmpty("কোনো হার্ডওয়্যার দাম পাওয়া যায়নি");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _hardwareList.length,
      itemBuilder: (ctx, idx) {
        final item = _hardwareList[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cCard,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(item.itemName,
                    style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: cAccent2.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text("৳ ${item.price}",
                    style: GoogleFonts.inter(color: cAccent2, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmpty(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: cMuted.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(msg, style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 14)),
        ],
      ),
    );
  }
}