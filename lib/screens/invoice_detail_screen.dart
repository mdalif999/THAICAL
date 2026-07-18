import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class InvoiceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> invoice;
  const InvoiceDetailScreen({super.key, required this.invoice});

  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent = Color(0xFF00D4AA);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);
  static const Color cGreen = Color(0xFF22C55E);
  static const Color cYellow = Color(0xFFF59E0B);

  String _fmtTk(num amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  double _inchToBars(double inch) => inch / 192.0;

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
                      _buildCutRow("O/S আউটার খাড়া", cuts['os'], cutPrices['os']),
                      _buildCutRow("O/T আউটার টপ", cuts['ot'], cutPrices['ot']),
                      _buildCutRow("O/B আউটার বটম", cuts['ohb'], cutPrices['ohb']),
                      _buildCutRow("S/L পাল্লা লক", cuts['sl'], cutPrices['sl']),
                      _buildCutRow("I/L পাল্লা ইন্টারলক", cuts['il'], cutPrices['il']),
                      _buildCutRow("S/T পাল্লা টপ", cuts['st'], cutPrices['st']),
                      _buildCutRow("S/B পাল্লা বটম", cuts['sb'], cutPrices['sb']),
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
                      _buildMoneyRow(
                          "হার্ডওয়্যার (${totalSft.toStringAsFixed(1)} Sft × ৳${_fmtTk((invoice['hwRate'] as num?)?.toDouble() ?? 25)})",
                          (invoice['hwTotal'] as num).toDouble()),
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
                        _buildMoneyRow("🔩 অ্যালুমিনিয়াম বার", (invoice['aluTotal'] as num).toDouble()),
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
                      const Divider(color: cBorder, height: 20),
                      _buildMoneyRow("মোট বিল (Grand Total)", (invoice['total'] as num).toDouble(),
                          isBold: true, color: cAccent, size: 16),
                      if (invoice['advance'] != null && (invoice['advance'] as num).toDouble() > 0)
                        _buildMoneyRow("(−) অগ্রিম জমা", (invoice['advance'] as num).toDouble(), color: cYellow),
                      const Divider(color: cAccent2, height: 20, thickness: 1.5),
                      _buildMoneyRow("বাকি (Due)", due, isBold: true, color: cAccent2, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
        SizedBox(width: 50, child: Text("${bars.toStringAsFixed(1)}P",
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
}
