import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/window_calculation.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final int? invoiceIndex;
  const InvoiceDetailScreen({super.key, required this.invoice, this.invoiceIndex});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Map<String, dynamic> invoice;

  @override
  void initState() {
    super.initState();
    invoice = Map<String, dynamic>.from(widget.invoice);
  }

  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent = Color(0xFF00D4AA);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);
  static const Color cGreen = Color(0xFF22C55E);
  static const Color cYellow = Color(0xFFF59E0B);
  static const Color cRed = Color(0xFFEF4444);

  String _fmtTk(num amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  Future<void> _addPayment() async {
    final due = (invoice['due'] as num?)?.toDouble() ?? 0;
    if (due <= 0) return;

    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: cBorder)),
        title: Text("টাকা জমা দিন", style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("বাকি: ৳${_fmtTk(due)}", style: GoogleFonts.hindSiliguri(color: cAccent2, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            style: GoogleFonts.inter(color: cText, fontSize: 16),
            decoration: InputDecoration(
              labelText: "জমার টাকা (৳)",
              labelStyle: GoogleFonts.hindSiliguri(color: cMuted),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: cAccent)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("বাতিল", style: GoogleFonts.hindSiliguri(color: cMuted))),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(ctx, amount);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: cGreen),
            child: Text("জমা দিন", style: GoogleFonts.hindSiliguri(color: cBg, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      final currentAdvance = (invoice['advance'] as num?)?.toDouble() ?? 0;
      final total = (invoice['total'] as num?)?.toDouble() ?? 0;
      final newAdvance = currentAdvance + result;
      final newDue = total - newAdvance;

      setState(() {
        invoice['advance'] = newAdvance;
        invoice['due'] = newDue;
      });

      await _saveInvoice();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("৳${_fmtTk(result)} জমা হয়েছে! বাকি: ৳${_fmtTk(newDue > 0 ? newDue : 0)}",
                style: GoogleFonts.hindSiliguri(color: Colors.white)),
            backgroundColor: cGreen,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveInvoice() async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getString('saved_invoices');
    if (listStr == null) return;
    try {
      final List<dynamic> invoices = jsonDecode(listStr);
      if (widget.invoiceIndex != null && widget.invoiceIndex! >= 0 && widget.invoiceIndex! < invoices.length) {
        invoices[widget.invoiceIndex!] = invoice;
        await prefs.setString('saved_invoices', jsonEncode(invoices));
      }
    } catch (e) {
      print('Failed to save invoice: $e');
    }
  }

  double _inchToBars(double inch) {
    final specInches = WindowCalculation.calcSpecLengthInches(invoice['spec_length']?.toString());
    return WindowCalculation.inchToBars(inch, specLengthInches: specInches);
  }

  @override
  Widget build(BuildContext context) {
    final windows = (invoice['windows'] as List?) ?? [];
    final hasDetails = windows.isNotEmpty;
    final due = (invoice['due'] as num?)?.toDouble() ?? 0;
    final isPaid = due <= 0;
    final cuts = (invoice['cuts'] as Map?) ?? {};
    final cutPrices = (invoice['cutPrices'] as Map?) ?? {};
    final totalSft = (invoice['totalSft'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E17),
        elevation: 0,
        title: Text(invoice['name']?.toString() ?? 'হিসাব বিস্তারিত',
            style: GoogleFonts.hindSiliguri(color: cText, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: cGreen),
            tooltip: "WhatsApp এ পাঠান",
            onPressed: () => _shareWhatsApp(context),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── কাস্টমার তথ্য ──
                _buildCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(invoice['name']?.toString() ?? '',
                          style: GoogleFonts.hindSiliguri(color: cText, fontSize: 16, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: (isPaid ? cGreen : cAccent2).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(isPaid ? "✓ পরিশোধ" : "বাকি আছে",
                            style: GoogleFonts.hindSiliguri(
                                color: isPaid ? cGreen : cAccent2, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    if ((invoice['phone']?.toString() ?? '').isNotEmpty)
                      Text("📞 ${invoice['phone']}", style: GoogleFonts.inter(color: cMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      "📅 ${(invoice['date']?.toString() ?? '').split('T').first}",
                      style: GoogleFonts.inter(color: cMuted, fontSize: 13),
                    ),
                  ],
                )),
                const SizedBox(height: 12),

                // ── ব্র্যান্ড তথ্য ──
                _buildCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("⚙️ ব্র্যান্ড তথ্য", style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    _buildInfoRow("থাই ব্র্যান্ড", invoice['brand']?.toString() ?? '-'),
                    if ((invoice['color']?.toString() ?? '').isNotEmpty)
                      _buildInfoRow("কালার", invoice['color'].toString()),
                    if (invoice['profile_size'] != null || invoice['thickness'] != null)
                      _buildInfoRow(
                        invoice['profile_size'] != null ? "জানালার ধরন" : "পুরুত্ব",
                        invoice['profile_size'] != null
                            ? (invoice['profile_size'].toString().contains('4') ? '৪" (নেট সহ)' : '৩" (নেট ছাড়া)')
                            : "${invoice['thickness']} mm",
                      ),
                    if ((invoice['glassBrand']?.toString() ?? '').isNotEmpty)
                      _buildInfoRow("গ্লাস", invoice['glassBrand'].toString()),
                  ],
                )),
                const SizedBox(height: 12),

                // ── জানালার তালিকা ──
                _buildCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📐 জানালার তালিকা", style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (!hasDetails)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text("এই পুরনো হিসাবে বিস্তারিত জানালার তথ্য সংরক্ষিত নেই।",
                            style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                      )
                    else
                      ...List.generate(windows.length, (idx) {
                        final w = windows[idx] as Map;
                        final width = (w['w'] as num).toDouble();
                        final height = (w['h'] as num).toDouble();
                        final qty = (w['qty'] as num).toInt();
                        final sft = (width * height / 144.0) * qty;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFF12151F),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cBorder)),
                          child: Column(children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text("${w['name']}",
                                      style: GoogleFonts.hindSiliguri(color: cText, fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                                Text("${width.toStringAsFixed(0)}\"×${height.toStringAsFixed(0)}\" ×${qty}",
                                    style: GoogleFonts.inter(color: cMuted, fontSize: 12)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: cAccent, borderRadius: BorderRadius.circular(4)),
                                  child: Text("${sft.toStringAsFixed(1)} Sft",
                                      style: GoogleFonts.inter(color: cBg, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ]),
                        );
                      }),
                    if (hasDetails && invoice['totalSft'] != null) ...[
                      const Divider(color: cBorder, height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("মোট এলাকা", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13)),
                        Text("${(invoice['totalSft'] as num).toStringAsFixed(2)} Sft",
                            style: GoogleFonts.hindSiliguri(color: cAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ]),
                    ],
                  ],
                )),
                const SizedBox(height: 12),

                // ── অ্যালুমিনিয়াম কাটিং বিবরণ ──
                if (cuts.isNotEmpty) ...[
                  _buildCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🔩 অ্যালুমিনিয়াম কাটিং বিবরণ",
                          style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      // Header row - Bangla labels
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text("সেকশন", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11))),
                          SizedBox(width: 50, child: Text("ইঞ্চি", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
                          SizedBox(width: 50, child: Text("বার", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
                          SizedBox(width: 40, child: Text("দর/বার", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
                          SizedBox(width: 55, child: Text("দাম", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
                        ]),
                      ),
                      const Divider(color: cBorder, height: 1),
                      const SizedBox(height: 6),
                      _buildCutRow("O/S আউটার সাইড", cuts['os'], cutPrices['os']),
                      _buildCutRow("O/T আউটার টপ", cuts['ot'], cutPrices['ot']),
                      _buildCutRow("OHB আউটার হাই বটম", cuts['ohb'], cutPrices['ohb']),
                      _buildCutRow("S/L স্লাইডিং লক", cuts['sl'], cutPrices['sl']),
                      _buildCutRow("I/L ইন্টারলক", cuts['il'], cutPrices['il']),
                      _buildCutRow("S/T শাটার টপ", cuts['st'], cutPrices['st']),
                      _buildCutRow("S/B শাটার বটম", cuts['sb'], cutPrices['sb']),
                      if (invoice['profile_size']?.toString().contains('4') == true) ...[
                        _buildCutRow("N/S নেট সেকশন", cuts['ns'], cutPrices['ns']),
                        _buildCutRow("N/H নেট হ্যান্ডেল", cuts['nh'], cutPrices['nb']),
                      ],
                      const Divider(color: cBorder, height: 16),
                      _buildMoneyRow("মোট অ্যালুমিনিয়াম", (invoice['aluTotal'] as num?)?.toDouble() ?? 0,
                          isBold: true, color: cAccent),
                    ],
                  )),
                  const SizedBox(height: 12),
                ],

                // ── হার্ডওয়্যার ──
                if (invoice['hwTotal'] != null) ...[
                  _buildCard(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🔧 হার্ডওয়্যার",
                          style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (invoice['hwItems'] != null) ...[
                        _buildHwTableHeader(),
                        const Divider(color: cBorder, height: 1),
                        for (var item in (invoice['hwItems'] as List))
                          _buildHwRow(item as Map<String, dynamic>),
                        const Divider(color: cBorder, height: 16),
                      ],
                      _buildMoneyRow("হার্ডওয়্যার মোট", (invoice['hwTotal'] as num).toDouble(),
                          isBold: true, color: cYellow),
                    ],
                  )),
                  const SizedBox(height: 12),
                ],

                // ── খরচের বিবরণ ──
                _buildCard(
                  borderColor: cAccent2.withOpacity(0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("🧾 খরচের বিবরণ", style: GoogleFonts.hindSiliguri(color: cText, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (invoice['aluTotal'] != null)
                        _buildMoneyRow(
                            (invoice['brandDiscount'] != null && (invoice['brandDiscount'] as num).toDouble() > 0)
                                ? "🔩 অ্যালুমিনিয়াম (-${(invoice['brandDiscount'] as num).toStringAsFixed(0)}%)"
                                : "🔩 অ্যালুমিনিয়াম বার",
                            (invoice['aluTotal'] as num?)?.toDouble() ?? 0),
                      if (invoice['glassTotal'] != null)
                        _buildMoneyRow(
                            invoice['glassRate'] != null
                                ? "🪟 গ্লাস (${totalSft.toStringAsFixed(1)} Sft × ৳${_fmtTk((invoice['glassRate'] as num).toDouble())})"
                                : "🪟 গ্লাস",
                            (invoice['glassTotal'] as num).toDouble()),
                      if (invoice['hwTotal'] != null)
                        _buildMoneyRow("🔧 হার্ডওয়্যার", (invoice['hwTotal'] as num).toDouble()),
                      if (invoice['labor'] != null)
                        _buildMoneyRow(
                            invoice['laborRate'] != null
                                ? "👷 লেবার (${totalSft.toStringAsFixed(1)} Sft × ৳${_fmtTk((invoice['laborRate'] as num).toDouble())})"
                                : "👷 লেবার / ফিটিং",
                            (invoice['labor'] as num).toDouble()),
                      if (invoice['fare'] != null && (invoice['fare'] as num).toDouble() > 0)
                        _buildMoneyRow("🚗 গাড়ি ভাড়া", (invoice['fare'] as num).toDouble()),
                      const Divider(color: cBorder, height: 20),
                      _buildMoneyRow("মোট বিল (Grand Total)", (invoice['total'] as num).toDouble(),
                          isBold: true, color: cAccent, size: 16),
                      if (totalSft > 0) ...[
                        const SizedBox(height: 4),
                        _buildMoneyRow("গড় খরচ / Sft", (invoice['total'] as num).toDouble() / totalSft,
                            isBold: false, color: cText.withOpacity(0.85), size: 13),
                      ],
                      if (invoice['advance'] != null && (invoice['advance'] as num).toDouble() > 0)
                        _buildMoneyRow("(−) অগ্রিম জমা", (invoice['advance'] as num).toDouble(), color: cYellow),
                      const Divider(color: cAccent2, height: 20, thickness: 1.5),
                      _buildMoneyRow("বাকি (Due)", due, isBold: true, color: cAccent2, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!isPaid)
                  ElevatedButton.icon(
                    onPressed: _addPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cGreen,
                      foregroundColor: cBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.payment_rounded, size: 22),
                    label: Text("বাকি জমা দিন", style: GoogleFonts.hindSiliguri(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                if (isPaid)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: cGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cGreen.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text("✓ সম্পূর্ণ পরিশোধিত", style: GoogleFonts.hindSiliguri(color: cGreen, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _shareWhatsApp(BuildContext context) async {
    final name = invoice['name']?.toString() ?? '';
    final phone = invoice['phone']?.toString() ?? '';
    final brand = invoice['brand']?.toString() ?? '';
    final color = invoice['color']?.toString() ?? '';
    final glassBrand = invoice['glassBrand']?.toString() ?? '';
    final profileSize = invoice['profile_size']?.toString() ?? '';
    final totalSft = (invoice['totalSft'] as num?)?.toDouble() ?? 0;
    final aluTotalAfterDiscount = (invoice['aluTotal'] as num?)?.toDouble() ?? 0;
    final brandDiscount = (invoice['brandDiscount'] as num?)?.toDouble() ?? 0;
    final aluTotal = brandDiscount > 0 ? aluTotalAfterDiscount / (1 - brandDiscount / 100) : aluTotalAfterDiscount;
    final glassTotal = (invoice['glassTotal'] as num?)?.toDouble() ?? 0;
    final glassRate = (invoice['glassRate'] as num?)?.toDouble() ?? 0;
    final hwTotal = (invoice['hwTotal'] as num?)?.toDouble() ?? 0;
    final labor = (invoice['labor'] as num?)?.toDouble() ?? 0;
    final laborRate = (invoice['laborRate'] as num?)?.toDouble() ?? 0;
    final fare = (invoice['fare'] as num?)?.toDouble() ?? 0;
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final advance = (invoice['advance'] as num?)?.toDouble() ?? 0;
    final due = (invoice['due'] as num?)?.toDouble() ?? 0;
    final windows = (invoice['windows'] as List?) ?? [];
    final cuts = (invoice['cuts'] as Map?) ?? {};
    final cutPrices = (invoice['cutPrices'] as Map?) ?? {};
    final dateStr = (invoice['date']?.toString() ?? '');
    final formattedDate = dateStr.isNotEmpty
        ? DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(dateStr).toLocal())
        : '';
    final is4Inch = profileSize.contains('4');

    // Window list
    final windowBuffer = StringBuffer();
    if (windows.isNotEmpty) {
      windowBuffer.writeln("জানালার তালিকা:");
      windowBuffer.writeln("--------------------");
      for (var i = 0; i < windows.length; i++) {
        final w = windows[i] as Map;
        final width = (w['w'] as num?)?.toDouble() ?? 0;
        final height = (w['h'] as num?)?.toDouble() ?? 0;
        final qty = (w['qty'] as num?)?.toInt() ?? 1;
        final sft = (width * height / 144.0) * qty;
        windowBuffer.writeln("  ${i + 1}. ${w['name']} — ${width.toStringAsFixed(0)}\" x ${height.toStringAsFixed(0)}\" x ${qty}টি = ${sft.toStringAsFixed(2)} Sft");
      }
      windowBuffer.writeln("  মোট: ${totalSft.toStringAsFixed(2)} Sft");
      windowBuffer.writeln();
    }

    // Profile cut detail
    final cutBuffer = StringBuffer();
    if (brand.isNotEmpty) {
      cutBuffer.writeln("অ্যালুমিনিয়াম প্রোফাইল হিসাব:");
      cutBuffer.writeln("--------------------");
      cutBuffer.writeln("ব্র্যান্ড: $brand ($color)");
      cutBuffer.writeln("সাইজ: $profileSize");
      cutBuffer.writeln();

      final cutItems = [
        ['O/S (আউটার সাইড)', cuts['os'], cutPrices['os']],
        ['O/T (আউটার টপ)', cuts['ot'], cutPrices['ot']],
        ['OHB (আউটার হাই বটম)', cuts['ohb'], cutPrices['ohb']],
        ['S/L (স্লাইডিং লক)', cuts['sl'], cutPrices['sl']],
        ['I/L (ইন্টারলক)', cuts['il'], cutPrices['il']],
        ['S/T (শাটার টপ)', cuts['st'], cutPrices['st']],
        ['S/B (শাটার বটম)', cuts['sb'], cutPrices['sb']],
      ];
      if (is4Inch) {
        cutItems.add(['N/S (নেট সেকশন)', cuts['ns'], cutPrices['ns']]);
        cutItems.add(['N/H (নেট হ্যান্ডেল)', cuts['nh'], cutPrices['nb']]);
      }

      final specInches = WindowCalculation.calcSpecLengthInches(invoice['spec_length']?.toString());
      for (var item in cutItems) {
        final label = item[0] as String;
        final inch = (item[1] as num?)?.toDouble() ?? 0;
        final pricePerBar = (item[2] as num?)?.toInt() ?? 0;
        final bars = inch / specInches;
        final totalCut = (bars * pricePerBar).round();
        if (inch > 0) {
          cutBuffer.writeln("  $label");
          cutBuffer.writeln("    ইঞ্চি: ${inch.toStringAsFixed(0)}\"  |  বার: ${bars.toStringAsFixed(2)}  |  দর/বার: ৳$pricePerBar  |  মোট: ৳${_fmtTk(totalCut.toDouble())}");
        }
      }
      cutBuffer.writeln("  -------------------");
      if (brandDiscount > 0) {
        cutBuffer.writeln("  অ্যালুমিনিয়াম (মূল্য): ৳${_fmtTk(aluTotal)}");
        cutBuffer.writeln("  ডিসকাউন্ট (-${brandDiscount.toStringAsFixed(0)}%): -৳${_fmtTk(aluTotal - aluTotalAfterDiscount)}");
      }
      cutBuffer.writeln("  অ্যালুমিনিয়াম মোট: ৳${_fmtTk(aluTotalAfterDiscount)}");
      cutBuffer.writeln();
    }

    // Glass detail
    final glassBuffer = StringBuffer();
    if (glassBrand.isNotEmpty) {
      glassBuffer.writeln("গ্লাস হিসাব:");
      glassBuffer.writeln("--------------------");
      glassBuffer.writeln("ব্র্যান্ড: $glassBrand");
      if (glassRate > 0) glassBuffer.writeln("দর: ৳${_fmtTk(glassRate)} / Sft");
      if (totalSft > 0) glassBuffer.writeln("মোট এলাকা: ${totalSft.toStringAsFixed(2)} Sft");
      glassBuffer.writeln("গ্লাস মোট: ৳${_fmtTk(glassTotal)}");
      glassBuffer.writeln();
    }

    // Hardware breakdown
    final hwBuffer = StringBuffer();
    final hwItems = invoice['hwItems'] as List?;
    if (hwItems != null && hwItems.isNotEmpty) {
      hwBuffer.writeln("হার্ডওয়্যার হিসাব:");
      hwBuffer.writeln("--------------------");
      for (var item in hwItems) {
        final hwItem = item as Map<String, dynamic>;
        final cost = (hwItem['cost'] as num?)?.toDouble() ?? 0;
        final rate = (hwItem['rate'] as num?)?.toDouble() ?? 0;
        hwBuffer.writeln("  ${hwItem['name']} — ${hwItem['qty']} ${hwItem['unit']} × ৳${_fmtTk(rate)} = ৳${_fmtTk(cost)}");
      }
      hwBuffer.writeln("  -------------------");
      hwBuffer.writeln("  হার্ডওয়্যার মোট: ৳${_fmtTk(hwTotal)}");
      hwBuffer.writeln();
    } else if (hwTotal > 0) {
      hwBuffer.writeln("হার্ডওয়্যার: ৳${_fmtTk(hwTotal)}");
      hwBuffer.writeln();
    }

    // Main message — step 4 এর মতো একই ফরম্যাট
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
        "${brandDiscount > 0 ? "  ডিসকাউন্ট (-${brandDiscount.toStringAsFixed(0)}%)\n" : ""}"
        "====================================\n"
        "${glassBuffer}"
        "${hwBuffer}"
        "মজুরি/ফিটিং: ৳${_fmtTk(labor)}\n"
        "${fare > 0 ? "গাড়ি ভাড়া: ৳${_fmtTk(fare)}\n" : ""}"
        "\n"
        "====================================\n"
        "*সর্বমোট বিল: ৳${_fmtTk(total)}*\n"
        "${totalSft > 0 ? "গড় খরচ / Sft: ৳${_fmtTk(total / totalSft)}\n" : ""}"
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
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("WhatsApp চালু করা যায়নি!", style: GoogleFonts.hindSiliguri(color: Colors.white)),
                backgroundColor: cAccent2),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("WhatsApp শেয়ার ত্রুটি: $e", style: GoogleFonts.hindSiliguri(color: Colors.white)),
              backgroundColor: cAccent2),
        );
      }
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13)),
        Text(value, style: GoogleFonts.hindSiliguri(color: cText, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildCutRow(String label, dynamic inch, dynamic pricePerBar) {
    final inchVal = (inch as num?)?.toDouble() ?? 0;
    final priceVal = (pricePerBar as num?)?.toInt() ?? 0;
    final bars = _inchToBars(inchVal);
    final total = (bars * priceVal).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(flex: 3, child: Text(label, style: GoogleFonts.hindSiliguri(color: cText, fontSize: 12))),
        SizedBox(width: 50, child: Text("${inchVal.toStringAsFixed(0)}\"",
            style: GoogleFonts.inter(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
        SizedBox(width: 50, child: Text("${bars.toStringAsFixed(2)}P",
            style: GoogleFonts.inter(color: cAccent2, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
        SizedBox(width: 40, child: Text("৳$priceVal",
            style: GoogleFonts.inter(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
        SizedBox(width: 55, child: Text("৳$total",
            style: GoogleFonts.inter(color: cGreen, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _buildMoneyRow(String label, double amount, {bool isBold = false, Color? color, double size = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: GoogleFonts.hindSiliguri(
                color: isBold ? cText : cMuted, fontSize: size - 1, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Text("৳ ${_fmtTk(amount)}",
            style: GoogleFonts.inter(color: color ?? cText, fontSize: size, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildHwTableHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 3, child: Text("আইটেম", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11))),
        SizedBox(width: 45, child: Text("পরিমাণ", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
        SizedBox(width: 35, child: Text("ইউনিট", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
        SizedBox(width: 55, child: Text("দর", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
        SizedBox(width: 65, child: Text("মোট", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
      ]),
    );
  }

  Widget _buildHwRow(Map<String, dynamic> item) {
    final cost = (item['cost'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(flex: 3, child: Text(item['name'] as String? ?? '',
            style: GoogleFonts.hindSiliguri(color: cText, fontSize: 12))),
        SizedBox(width: 45, child: Text("${item['qty']}",
            style: GoogleFonts.inter(color: cText, fontSize: 12), textAlign: TextAlign.center)),
        SizedBox(width: 35, child: Text(item['unit'] as String? ?? '',
            style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11), textAlign: TextAlign.center)),
        SizedBox(width: 55, child: Text("৳${_fmtTk((item['rate'] as num?)?.toDouble() ?? 0)}",
            style: GoogleFonts.inter(color: cMuted, fontSize: 11), textAlign: TextAlign.right)),
        SizedBox(width: 65, child: Text("৳${_fmtTk(cost)}",
            style: GoogleFonts.inter(color: cGreen, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
      ]),
    );
  }
}
