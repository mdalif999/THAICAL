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

  @override
  Widget build(BuildContext context) {
    final windows = (invoice['windows'] as List?) ?? [];
    final hasDetails = windows.isNotEmpty;
    final due = (invoice['due'] as num?)?.toDouble() ?? 0;
    final isPaid = due <= 0;

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
                    if (invoice['thickness'] != null)
                      _buildInfoRow("পুরুত্ব", "${invoice['thickness']} mm"),
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
                          child: Row(
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
                        _buildMoneyRow("🪟 গ্লাস", (invoice['glassTotal'] as num).toDouble()),
                      if (invoice['hwTotal'] != null)
                        _buildMoneyRow("🔧 হার্ডওয়্যার", (invoice['hwTotal'] as num).toDouble()),
                      if (invoice['labor'] != null)
                        _buildMoneyRow("👷 লেবার / ফিটিং", (invoice['labor'] as num).toDouble()),
                      const Divider(color: cBorder, height: 20),
                      _buildMoneyRow("মোট বিল (Grand Total)", (invoice['total'] as num).toDouble(),
                          isBold: true, color: cAccent, size: 16),
                      if (invoice['advance'] != null)
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