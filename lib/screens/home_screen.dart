import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/database_service.dart';
import 'invoice_detail_screen.dart';
import 'price_list_screen.dart';
import 'update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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
  bool _normalUpdateBannerShown = false;
  String? _profilePicPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInvoices();
    _periodicUpdateCheck();
    _checkMessages();
    _loadProfilePic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _periodicUpdateCheck();
      _checkMessages();
    }
  }

  Future<void> _periodicUpdateCheck() async {
    if (!mounted) return;

    // শুধু online থাকলেই check করবে
    final isOnline = await DatabaseService.instance.hasInternet();
    if (!isOnline) return;

    // ৩ দিন পারেনি হলে check করবে না
    final shouldCheck = await DatabaseService.instance.shouldCheckForUpdate(intervalDays: 3);
    if (!shouldCheck) return;

    final updateInfo = await DatabaseService.instance.checkForUpdate();
    if (updateInfo == null || !mounted) {
      await DatabaseService.instance.saveLastUpdateCheckTime();
      return;
    }

    await DatabaseService.instance.saveLastUpdateCheckTime();

    if (updateInfo['force_update'] == true) {
      // Force update → বাধ্যতামূলক dialog, বন্ধ করা যাবে না
      if (mounted) await showUpdateDialog(context, updateInfo);
    } else {
      // Normal update → dismissable dialog, "আপডেট করুন" e directly link e jabe
      if (mounted && !_normalUpdateBannerShown) {
        _normalUpdateBannerShown = true;
        if (mounted) await showUpdateDialog(context, updateInfo);
      }
    }
  }

  // ── Message Check (Supabase messages table) ──
  Future<void> _checkMessages() async {
    if (!mounted) return;
    final isOnline = await DatabaseService.instance.hasInternet();
    if (!isOnline) return;

    final message = await DatabaseService.instance.checkForMessage();
    if (message == null || !mounted) return;

    final title = message['title']?.toString() ?? 'নতুন বার্তা';
    final body = message['body']?.toString() ?? '';
    final msgId = message['id'] as int;

    if (mounted) {
      await DatabaseService.instance.markMessageAsSeen(msgId);
      _showMessageDialog(title, body);
    }
  }

  void _showMessageDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, size: 32, color: cAccent),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.hindSiliguri(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: cText,
                ),
                textAlign: TextAlign.center,
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  body,
                  style: GoogleFonts.hindSiliguri(fontSize: 13, color: cMuted, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cAccent,
                    foregroundColor: cBg,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    "ঠিক আছে",
                    style: GoogleFonts.hindSiliguri(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  "বন্ধ করুন",
                  style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile Picture ──
  Future<void> _loadProfilePic() async {
    final path = await DatabaseService.instance.getProfilePicture();
    if (mounted && path != null) {
      final file = File(path);
      if (await file.exists()) {
        setState(() => _profilePicPath = path);
      }
    }
  }

  Future<void> _pickProfilePic() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'profile_pic.jpg';
    final savedFile = await File(picked.path).copy('${appDir.path}/$fileName');

    await DatabaseService.instance.saveProfilePicture(savedFile.path);
    if (mounted) setState(() => _profilePicPath = savedFile.path);
  }

  void _showProfilePicSheet() {
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
              decoration: BoxDecoration(color: cBorder, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text("প্রোফাইল ছবি",
                style: GoogleFonts.hindSiliguri(color: cText, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tileColor: const Color(0xFF12151F),
              leading: const Icon(Icons.photo_library_rounded, color: cAccent),
              title: Text("গ্যালারি থেকে ছবি বাছুন", style: GoogleFonts.hindSiliguri(color: cText)),
              onTap: () {
                Navigator.pop(ctx);
                _pickProfilePic();
              },
            ),
            if (_profilePicPath != null) ...[
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                tileColor: const Color(0xFF12151F),
                leading: const Icon(Icons.delete_rounded, color: cAccent2),
                title: Text("ছবি সরিয়ে ফেলুন", style: GoogleFonts.hindSiliguri(color: cAccent2)),
                onTap: () async {
                  await DatabaseService.instance.removeProfilePicture();
                  if (mounted) setState(() => _profilePicPath = null);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
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
                  GestureDetector(
                    onTap: _showProfilePicSheet,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: cAccent.withOpacity(0.15),
                      backgroundImage: _profilePicPath != null ? FileImage(File(_profilePicPath!)) : null,
                      child: _profilePicPath == null
                          ? const Icon(Icons.person, color: cAccent, size: 30)
                          : null,
                    ),
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
          leading: const Icon(Icons.price_change_rounded, color: cMuted),
          title: Text("প্রাইস লিস্ট", style: GoogleFonts.hindSiliguri(color: cText)),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PriceListScreen()));
          },
        ),
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
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("WhatsApp খুলতে পারা যায়নি। WhatsApp ইনস্টল আছে কিনা চেক করুন।",
                                    style: GoogleFonts.hindSiliguri(color: Colors.white, fontSize: 13)),
                                backgroundColor: cAccent2,
                              ),
                            );
                          }
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
                        try {
                          await launchUrl(uri);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("ফোন ডায়ালার খুলতে পারা যায়নি।",
                                    style: GoogleFonts.hindSiliguri(color: Colors.white, fontSize: 13)),
                                backgroundColor: cAccent2,
                              ),
                            );
                          }
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
                        try {
                          await launchUrl(uri);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("ফোন ডায়ালার খুলতে পারা যায়নি।",
                                    style: GoogleFonts.hindSiliguri(color: Colors.white, fontSize: 13)),
                                backgroundColor: cAccent2,
                              ),
                            );
                          }
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
        ListTile(
          leading: const Icon(Icons.exit_to_app_rounded, color: cMuted),
          title: Text("অ্যাপ বন্ধ করুন", style: GoogleFonts.hindSiliguri(color: cMuted)),
          onTap: () {
            if (Platform.isAndroid) {
              SystemNavigator.pop();
            } else {
              exit(0);
            }
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Center(
            child: Text(
              "DeshTec",
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF0F0F0).withOpacity(0.6),
                letterSpacing: 2.0,
              ),
            ),
          ),
        ),
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
                              return _buildInvoiceCard(_invoices[idx], idx);
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

  Widget _buildInvoiceCard(Map<String, dynamic> inv, int index) {
    double due = (inv['due'] as num).toDouble();
    bool isPaid = due <= 0;
    return Dismissible(
      key: Key('invoice_$index'),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cAccent2.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerLeft,
        child: const Icon(Icons.delete_rounded, color: cAccent2, size: 28),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cAccent2.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete_rounded, color: cAccent2, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: cCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: cBorder),
            ),
            title: Text("মুছে ফেলুন?",
                style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold)),
            content: Text("এই হিসাবটি মুছে ফেলতে চান?",
                style: GoogleFonts.hindSiliguri(color: cMuted)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text("না", style: GoogleFonts.hindSiliguri(color: cMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text("মুছুন", style: GoogleFonts.hindSiliguri(color: cAccent2, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await DatabaseService.instance.deleteInvoice(index);
        setState(() {
          _invoices.removeAt(index);
        });
      },
      child: GestureDetector(
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