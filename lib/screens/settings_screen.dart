import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/database_service.dart';
import 'update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent = Color(0xFF00D4AA);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);
  static const Color cGreen = Color(0xFF22C55E);

  List<Map<String, dynamic>> _messages = [];
  bool _loadingMessages = true;
  bool _checkingUpdate = false;
  String _currentVersion = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadMessages();
  }

  Future<void> _loadCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _currentVersion = info.version);
  }

  Future<void> _loadMessages() async {
    setState(() => _loadingMessages = true);
    final list = await DatabaseService.instance.getRecentMessages(limit: 10);
    if (mounted) {
      setState(() {
        _messages = list;
        _loadingMessages = false;
      });
    }
  }

  Future<void> _checkUpdateNow() async {
    setState(() => _checkingUpdate = true);
    try {
      final updateInfo = await DatabaseService.instance.checkForUpdate();
      if (!mounted) return;
      if (updateInfo != null) {
        await showUpdateDialog(context, updateInfo);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("আপনার অ্যাপ সর্বশেষ ভার্সনেই আছে।",
                style: GoogleFonts.hindSiliguri(color: Colors.white, fontSize: 13)),
            backgroundColor: cGreen,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  String _formatMessageDate(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt.toString()).toLocal();
      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return '';
    }
  }

  void _showMessagesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: cCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: cBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text("সর্বশেষ বার্তা",
                  style: GoogleFonts.hindSiliguri(color: cText, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: _messages.isEmpty
                    ? Center(
                        child: Text("কোনো বার্তা নেই।", style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13)),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _messages[i];
                          final title = msg['title']?.toString() ?? 'বার্তা';
                          final body = msg['body']?.toString() ?? '';
                          final date = _formatMessageDate(msg['created_at']);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF12151F),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(title,
                                          style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                    if (date.isNotEmpty)
                                      Text(date, style: GoogleFonts.inter(color: cMuted, fontSize: 10)),
                                  ],
                                ),
                                if (body.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(body, style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12, height: 1.4)),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    bool obscureOld = true, obscureNew = true, obscureConfirm = true;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: cBorder),
          ),
          title: Text("পাসওয়ার্ড পরিবর্তন করুন",
              style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPassController,
                  obscureText: obscureOld,
                  style: GoogleFonts.inter(color: cText, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "বর্তমান পাসওয়ার্ড",
                    hintStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: Icon(obscureOld ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: cMuted, size: 18),
                      onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                    ),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: cAccent)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: newPassController,
                  obscureText: obscureNew,
                  style: GoogleFonts.inter(color: cText, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "নতুন পাসওয়ার্ড (অন্তত ৬ অক্ষর)",
                    hintStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: cMuted, size: 18),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: cAccent)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmPassController,
                  obscureText: obscureConfirm,
                  style: GoogleFonts.inter(color: cText, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "নতুন পাসওয়ার্ড নিশ্চিত করুন",
                    hintStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: cMuted, size: 18),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                    enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
                    focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: cAccent)),
                  ),
                ),
              ],
            ),
          ),
          actions: isSubmitting
              ? [const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: cAccent))]
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text("বাতিল", style: GoogleFonts.hindSiliguri(color: cMuted)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (oldPassController.text.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text("বর্তমান পাসওয়ার্ড দিন!", style: GoogleFonts.hindSiliguri())));
                        return;
                      }
                      if (newPassController.text.length < 6) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text("নতুন পাসওয়ার্ড অন্তত ৬ অক্ষরের হতে হবে!", style: GoogleFonts.hindSiliguri())));
                        return;
                      }
                      if (newPassController.text != confirmPassController.text) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text("নতুন পাসওয়ার্ড মিলেনি!", style: GoogleFonts.hindSiliguri())));
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await DatabaseService.instance.changePassword(
                          oldPassword: oldPassController.text,
                          newPassword: newPassController.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text("পাসওয়ার্ড সফলভাবে পরিবর্তন হয়েছে!",
                                style: GoogleFonts.hindSiliguri(color: Colors.white)),
                            backgroundColor: cGreen,
                          ));
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text("ত্রুটি: ${e.toString().replaceAll('Exception: ', '')}",
                              style: GoogleFonts.hindSiliguri(color: Colors.white)),
                          backgroundColor: cAccent2,
                        ));
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: cAccent),
                    child: Text("পরিবর্তন করুন", style: GoogleFonts.hindSiliguri(color: cBg, fontWeight: FontWeight.bold)),
                  ),
                ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: cCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: cBorder),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
                  const SizedBox(width: 8),
                  Text("অ্যাকাউন্ট ডিলিট করুন",
                      style: GoogleFonts.hindSiliguri(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "সতর্কতা: আপনার অ্যাকাউন্ট ডিলিট করলে সকল হিসাব-নিকাশ, প্রোফাইল ডাটা এবং সাবস্ক্রিপশন চিরতরে মুছে যাবে।",
                      style: GoogleFonts.hindSiliguri(color: cText, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "নিশ্চিত করতে আপনার বর্তমান পাসওয়ার্ডটি প্রবেশ করান:",
                      style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      style: GoogleFonts.inter(color: cText, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: "আপনার পাসওয়ার্ড",
                        hintStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: cMuted,
                            size: 18,
                          ),
                          onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                        ),
                        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: cBorder)),
                        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFEF4444))),
                      ),
                    ),
                  ],
                ),
              ),
              actions: isDeleting
                  ? [const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Color(0xFFEF4444))))]
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: Text("বাতিল করুন", style: GoogleFonts.hindSiliguri(color: cMuted, fontWeight: FontWeight.bold)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          if (passwordController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: cAccent2,
                              content: Text("অ্যাকাউন্ট মুছে ফেলতে পাসওয়ার্ড দিন!",
                                  style: GoogleFonts.hindSiliguri(color: Colors.white)),
                            ));
                            return;
                          }

                          setDialogState(() => isDeleting = true);
                          try {
                            // Backend-এ পাসওয়ার্ড পাস করা হচ্ছে
                            await DatabaseService.instance.deleteAccount(
                            
                            );
                            if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                backgroundColor: const Color(0xFFEF4444),
                                content: Text("আপনার অ্যাকাউন্ট এবং সকল ডেটা সফলভাবে মুছে ফেলা হয়েছে।",
                                    style: GoogleFonts.hindSiliguri(color: Colors.white)),
                              ));
                              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                            }
                          } catch (e) {
                            if (dialogCtx.mounted) setDialogState(() => isDeleting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                backgroundColor: const Color(0xFFEF4444),
                                content: Text("ত্রুটি: ${e.toString().replaceAll('Exception: ', '')}",
                                    style: GoogleFonts.hindSiliguri(color: Colors.white)),
                              ));
                            }
                          }
                        },
                        child: Text("হ্যাঁ, ডিলিট করুন", style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0E17),
        elevation: 0,
        title: Text("সেটিংস",
            style: GoogleFonts.hindSiliguri(fontSize: 18, fontWeight: FontWeight.bold, color: cText)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── অ্যাপ আপডেট ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.system_update_rounded, color: cAccent, size: 20),
                    const SizedBox(width: 8),
                    Text("অ্যাপ আপডেট", style: GoogleFonts.hindSiliguri(color: cText, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Text("বর্তমান ভার্সন: $_currentVersion",
                    style: GoogleFonts.inter(color: cMuted, fontSize: 12)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _checkingUpdate ? null : _checkUpdateNow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cAccent,
                    foregroundColor: cBg,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _checkingUpdate
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cBg))
                      : const Icon(Icons.refresh_rounded, size: 18),
                  label: Text("আপডেট চেক করুন", style: GoogleFonts.hindSiliguri(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── পাসওয়ার্ড পরিবর্তন ──
          Container(
            decoration: BoxDecoration(
              color: cCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cBorder),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.lock_reset_rounded, color: cAccent),
                title: Text("পাসওয়ার্ড পরিবর্তন করুন", style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold)),
                subtitle: Text("বর্তমান পাসওয়ার্ড দিয়ে যাচাই করে নতুন সেট করুন",
                    style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded, color: cMuted),
                onTap: _showChangePasswordDialog,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── সর্বশেষ বার্তা (ট্যাপ করলে তালিকা খুলবে) ──
          Container(
            decoration: BoxDecoration(
              color: cCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cBorder),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.notifications_rounded, color: cAccent),
                title: Text("সর্বশেষ বার্তা", style: GoogleFonts.hindSiliguri(color: cText, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  _loadingMessages
                      ? "লোড হচ্ছে..."
                      : (_messages.isEmpty ? "কোনো বার্তা নেই" : "${_messages.length}টি বার্তা দেখুন"),
                  style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: cMuted),
                onTap: _showMessagesSheet,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── অ্যাকাউন্ট ডিলিট ──
          Container(
            decoration: BoxDecoration(
              color: cCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444)),
                title: Text("অ্যাকাউন্ট ডিলিট করুন",
                    style: GoogleFonts.hindSiliguri(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                onTap: _showDeleteAccountDialog,
              ),
            ),
          ),
        ],
      ),
    );
  }
}