import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import 'invoice_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent = Color(0xFF00D4AA);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);
  static const Color cGreen = Color(0xFF22C55E);

  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final list = await DatabaseService.instance.getSavedInvoices();
      setState(() {
        _invoices = list;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading invoices: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalDue = 0;
    for (var inv in _invoices) {
      totalDue += (inv['due'] as num).toDouble();
    }
    int totalInvoices = _invoices.length;

    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E17),
        elevation: 0,
        leading: Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.menu_rounded, color: cText),
      onPressed: () => Scaffold.of(context).openDrawer(),
       ),
       ),
        title: Text("Thai Calc Pro",
            style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.bold, color: cAccent)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: cMuted),
            tooltip: "রিফ্রেশ করুন",
            onPressed: _loadInvoices,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: cMuted),
            onPressed: () async {
              await DatabaseService.instance.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          )
        ],
      ),
      drawer: Drawer(
  backgroundColor: cBg,
  child: SafeArea(
    child: Column(
      children: [
        ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: DatabaseService.instance.currentUserProfileNotifier,
          builder: (context, user, _) {
            final name = user?['name']?.toString() ?? 'ইউজার';
            final phone = user?['phone_email']?.toString() ?? '';
            final isPaid = user?['is_paid'] == true;
            return Container(
              padding: const EdgeInsets.all(20),
              width: double.infinity,
              color: const Color(0xFF0B0E17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cAccent.withOpacity(0.15),
                    child: const Icon(Icons.person, color: cAccent, size: 30),
                  ),
                  const SizedBox(height: 10),
                  Text(name, style: GoogleFonts.hindSiliguri(color: cText, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(phone, style: GoogleFonts.inter(color: cMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isPaid ? cGreen : cAccent2).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isPaid ? "✓ পেইড অ্যাকাউন্ট" : "ফ্রি অ্যাকাউন্ট",
                      style: GoogleFonts.hindSiliguri(
                          color: isPaid ? cGreen : cAccent2, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (user != null)
                    Builder(builder: (context) {
                      final remaining = DatabaseService.instance.timeRemaining(user);
                      if (remaining != null && remaining.inDays > 18250) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            "মেয়াদ: আনলিমিটেড",
                            style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11),
                          ),
                        );
                      }

                      final days = DatabaseService.instance.daysRemaining(user);
                      final dateStr = isPaid
                          ? user['subscription_expires_at']?.toString()
                          : user['trial_ends_at']?.toString();
                      if (dateStr == null) return const SizedBox.shrink();
                      final localDate = DateTime.parse(dateStr).toLocal();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          "মেয়াদ: ${localDate.day}/${localDate.month}/${localDate.year}"
                          "${days != null ? " (আর $days দিন)" : ""}",
                          style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
        const Divider(color: cBorder, height: 1),
        ListTile(
          leading: const Icon(Icons.help_outline_rounded, color: cMuted),
          title: Text("সাহায্য / যোগাযোগ", style: GoogleFonts.hindSiliguri(color: cText)),
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: cCard,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              builder: (ctx) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: cBorder, borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text("যোগাযোগ", style: GoogleFonts.hindSiliguri(color: cText, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: const Color(0xFF12151F),
                      leading: const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                      title: Text("WhatsApp-এ যোগাযোগ", style: GoogleFonts.hindSiliguri(color: cText)),
                      subtitle: Text("01710460274", style: GoogleFonts.inter(color: cMuted, fontSize: 11)),
                      onTap: () async {
                        final uri = Uri.parse("https://wa.me/8801710460274");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: const Color(0xFF12151F),
                      leading: const Icon(Icons.call_rounded, color: cAccent),
                      title: Text("কল করুন (১)", style: GoogleFonts.hindSiliguri(color: cText)),
                      subtitle: Text("01305232039", style: GoogleFonts.inter(color: cMuted, fontSize: 11)),
                      onTap: () async {
                        final uri = Uri.parse("tel:+8801305232039");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      tileColor: const Color(0xFF12151F),
                      leading: const Icon(Icons.call_rounded, color: cAccent),
                      title: Text("কল করুন (২)", style: GoogleFonts.hindSiliguri(color: cText)),
                      subtitle: Text("01787203830", style: GoogleFonts.inter(color: cMuted, fontSize: 11)),
                      onTap: () async {
                        final uri = Uri.parse("tel:+8801787203830");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded, color: cMuted),
          title: Text("অ্যাপ সম্পর্কে", style: GoogleFonts.hindSiliguri(color: cText)),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: "Thai Calc Pro",
              applicationVersion: "1.0.0",
            );
          },
        ),
        const Spacer(),
        const Divider(color: cBorder, height: 1),
        ListTile(
          leading: const Icon(Icons.logout_rounded, color: cAccent2),
          title: Text("লগআউট করুন", style: GoogleFonts.hindSiliguri(color: cAccent2, fontWeight: FontWeight.bold)),
          onTap: () async {
            await DatabaseService.instance.logout();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/');
          },
        ),
        const SizedBox(height: 12),
      ],
    ),
  ),
),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            children: [
              // ── Reminder Banner ──
              _ReminderBanner(
                cAccent2: cAccent2,
              ),

              // ── Summary Cards ──
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.receipt_long_rounded,
                        label: "মোট হিসাব",
                        value: totalInvoices.toString(),
                        color: cAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        icon: Icons.account_balance_wallet_rounded,
                        label: "মোট বাকি",
                        value: "৳ ${_fmtTk(totalDue)}",
                        color: cAccent2,
                      ),
                    ),
                  ],
                ),
              ),

              // ── History List ──
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: cAccent),
                      )
                    : _invoices.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _invoices.length,
                            itemBuilder: (ctx, idx) {
                              return _buildInvoiceCard(_invoices[idx]);
                            },
                          ),
              ),

              // ── Bottom Action Button ──
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/calculator').then((_) {
                      _loadInvoices();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cAccent,
                    foregroundColor: cBg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  icon: const Icon(Icons.calculate_rounded, size: 22),
                  label: Text(
                    "  নতুন হিসাব করুন",
                    style: GoogleFonts.hindSiliguri(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: GoogleFonts.inter(
                  color: cText, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 56, color: cMuted.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text("কোনো হিসাব সেভ করা নেই",
              style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 14)),
          const SizedBox(height: 4),
          Text("নিচের বাটনে চাপ দিয়ে নতুন হিসাব শুরু করুন",
              style: GoogleFonts.hindSiliguri(
                  color: cMuted.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> inv) {
    double due = (inv['due'] as num).toDouble();
    bool isPaid = due <= 0;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => InvoiceDetailScreen(invoice: inv)),
        );
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(inv['name']?.toString() ?? '',
                    style: GoogleFonts.hindSiliguri(
                        color: cText, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: cAccent2, borderRadius: BorderRadius.circular(4)),
                child: Text(inv['brand']?.toString() ?? '',
                    style: GoogleFonts.inter(
                        color: cBg, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(inv['phone']?.toString() ?? '',
              style: GoogleFonts.inter(color: cMuted, fontSize: 12)),
          const Divider(color: cBorder, height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("মোট: ৳ ${_fmtTk((inv['total'] as num).toDouble())}",
                  style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12)),
              Text(
                isPaid ? "✓ পরিশোধ" : "বাকি: ৳ ${_fmtTk(due)}",
                style: GoogleFonts.hindSiliguri(
                    color: isPaid ? cGreen : cAccent2,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  String _fmtTk(double amount) => amount
      .toStringAsFixed(0)
      .replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}

// Dismissible reminder banner — user (X) চাপলে সেই দিনের জন্য বন্ধ থাকে, পরদিন আবার দেখাবে
class _ReminderBanner extends StatefulWidget {
  final Color cAccent2;
  const _ReminderBanner({required this.cAccent2});

  @override
  State<_ReminderBanner> createState() => _ReminderBannerState();
}

class _ReminderBannerState extends State<_ReminderBanner> {
  bool _dismissedToday = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _checkDismissed();
  }

  Future<void> _checkDismissed() async {
    final dismissed = await DatabaseService.instance.isReminderDismissedToday();
    if (mounted) {
      setState(() {
        _dismissedToday = dismissed;
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = DatabaseService.instance.currentUserProfile;
    if (!_checked || user == null || _dismissedToday || !DatabaseService.instance.shouldShowReminder(user)) {
      return const SizedBox.shrink();
    }

    final timeText = DatabaseService.instance.timeRemainingText(user);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.cAccent2.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.cAccent2.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: widget.cAccent2, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "আপনার মেয়াদ আর $timeText পর শেষ হবে। Renew করতে যোগাযোগ করুন।",
              style: GoogleFonts.hindSiliguri(
                  color: widget.cAccent2, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await DatabaseService.instance.dismissReminderForToday();
              if (mounted) setState(() => _dismissedToday = true);
            },
            child: Icon(Icons.close_rounded, color: widget.cAccent2.withOpacity(0.7), size: 18),
          ),
        ],
      ),
    );
  }
}