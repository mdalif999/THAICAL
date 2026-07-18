import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';

// ✅ FIX: StatelessWidget → StatefulWidget
// কারণ StatelessWidget এ FutureBuilder এর future প্রতি rebuild এ
// নতুন করে call হয় → infinite loop → বারবার logout
class DeactivatedScreen extends StatefulWidget {
  const DeactivatedScreen({super.key});

  @override
  State<DeactivatedScreen> createState() => _DeactivatedScreenState();
}

class _DeactivatedScreenState extends State<DeactivatedScreen> {
  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);

  // ✅ FIX: Future একবারই তৈরি হবে — initState এ
  late Future<Map<String, dynamic>> _checkFuture;

  @override
  void initState() {
    super.initState();
    _checkFuture = DatabaseService.instance.checkOfflineSubscription();
  }

  @override
  Widget build(BuildContext context) {
    final user = DatabaseService.instance.currentUserProfile;
    final args = ModalRoute.of(context)?.settings.arguments;
    String? overrideReason;
    String? nameFromArgs;
    String? phoneFromArgs;

    if (args is String) {
      overrideReason = args;
    } else if (args is Map) {
      overrideReason = args['reason'] as String?;
      nameFromArgs = args['name'] as String?;
      phoneFromArgs = args['phone_email'] as String?;
    }

    final userName = nameFromArgs ?? (user != null ? user['name'] : 'ইউজার');
    final userPhone = phoneFromArgs ?? (user != null ? user['phone_email'] : '');

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Center(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _checkFuture, // ✅ এখন একবারই call হবে
            builder: (context, snapshot) {
              final reason = overrideReason ??
                  (snapshot.connectionState == ConnectionState.done && snapshot.hasData
                      ? snapshot.data!['reason']?.toString() ?? ''
                      : '');

              String title = "অ্যাক্সেস বন্ধ করা হয়েছে";
              String message =
                  "আপনার অ্যাকাউন্টটি বর্তমানে নিষ্ক্রিয় অবস্থায় রয়েছে।";
              IconData icon = Icons.block_flipped;

              if (reason.isNotEmpty) {
                switch (reason) {
                  case 'blocked':
                    title = "অ্যাক্সেস বন্ধ করা হয়েছে";
                    message =
                        "আপনার অ্যাকাউন্টটি সাময়িকভাবে বন্ধ রাখা হয়েছে। অনুগ্রহ করে অ্যাডমিনের সাথে যোগাযোগ করুন।";
                    icon = Icons.block_flipped;
                    break;
                  case 'expired':
                    title = "মেয়াদ শেষ হয়েছে";
                    message =
                        "আপনার Thai Calc Pro অ্যাপের সাবস্ক্রিপশনের মেয়াদ শেষ হয়েছে। অনুগ্রহ করে রিনিউ করতে অ্যাডমিনের সাথে যোগাযোগ করুন।";
                    icon = Icons.timer_off_rounded;
                    break;
                  case 'tampered':
                    title = "ঘড়ির সময় ভুল";
                    message =
                        "নিরাপত্তা সতর্কবার্তা: আপনার ফোনের ঘড়ির সময় বা তারিখ পরিবর্তন করা হয়েছে! দয়া করে সঠিক অটোমেটিক সময় সেট করে অ্যাপটি পুনরায় চালু করুন।";
                    icon = Icons.lock_clock;
                    break;
                  case 'offline_timeout':
                    title = "ইন্টারনেট সংযোগ প্রয়োজন";
                    message =
                        "অফলাইনে ব্যবহারের ৫ দিনের সময়সীমা শেষ হয়েছে। অ্যাকাউন্ট স্ট্যাটাস যাচাই করতে দয়া করে মোবাইল ডাটা বা ওয়াই-ফাই চালু করে অ্যাপে প্রবেশ করুন।";
                    icon = Icons.wifi_off_rounded;
                    break;
                  case 'session_kicked':
                    title = "অন্য ডিভাইসে লগইন হয়েছে";
                    message =
                        "আপনার অ্যাকাউন্ট দিয়ে অন্য একটি ডিভাইস/ফোনে লগইন করা হয়েছে। নিরাপত্তার জন্য এই ডিভাইস থেকে সেশন বন্ধ করা হয়েছে। আবার এই ডিভাইসে ব্যবহার করতে চাইলে পুনরায় লগইন করুন।";
                    icon = Icons.phonelink_erase_rounded;
                    break;
                  case 'not_logged_in':
                    title = "লগইন করুন";
                    message = "অনুগ্রহ করে আবার লগইন করুন।";
                    icon = Icons.login_rounded;
                    break;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: cCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cBorder),
                        ),
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cAccent2.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 64, color: cAccent2),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              title,
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: cText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "আসসালামু আলাইকুম, $userName।\n\n$message",
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 14,
                                color: cMuted,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (userPhone != null &&
                                userPhone.toString().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                "আইডি: $userPhone",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: cAccent2.withOpacity(0.8),
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 24),
                            const Divider(color: cBorder),
                            const SizedBox(height: 24),
                            Text(
                              "সহায়তার জন্য অ্যাডমিনের সাথে যোগাযোগ করুন।",
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: cText.withOpacity(0.9),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await DatabaseService.instance.logout();
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, '/');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cCard,
                          foregroundColor: cText,
                          side: const BorderSide(color: cBorder),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 20),
                        label: Text(
                          "লগআউট করুন",
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}