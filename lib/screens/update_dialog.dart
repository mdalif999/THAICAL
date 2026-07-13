import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// App এর যেকোনো Scaffold এর উপরে দেখানোর জন্য।
// force = true হলে ইউজার dialog বন্ধ করতে পারবে না — শুধু Update বাটন কাজ করবে।
Future<void> showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo) {
  const cBg = Color(0xFF0F1117);
  const cCard = Color(0xFF1A1D27);
  const cBorder = Color(0xFF2A2D3A);
  const cAccent = Color(0xFF00D4AA);
  const cAccent2 = Color(0xFFFF6B35);
  const cText = Color(0xFFE8EAF0);
  const cMuted = Color(0xFF6B7280);

  final bool force = updateInfo['force_update'] == true;
  final String latestVersion = updateInfo['latest_version']?.toString() ?? '';
  final String? notes = updateInfo['release_notes']?.toString();
  final String downloadUrl = updateInfo['download_url']?.toString() ?? '';

  return showDialog(
    context: context,
    barrierDismissible: !force,
    // Android back বাটন দিয়েও force update বন্ধ করা যাবে না
    barrierColor: Colors.black.withOpacity(0.8),
    builder: (dialogContext) {
      return PopScope(
        canPop: !force,
        child: Dialog(
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
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: (force ? cAccent2 : cAccent).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    size: 40,
                    color: force ? cAccent2 : cAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  force ? "আপডেট করা বাধ্যতামূলক" : "নতুন আপডেট পাওয়া গেছে",
                  style: GoogleFonts.hindSiliguri(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: cText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  force
                      ? "অ্যাপটি ব্যবহার চালিয়ে যেতে অবশ্যই নতুন ভার্সন ($latestVersion) ইনস্টল করতে হবে।"
                      : "নতুন ভার্সন ($latestVersion) পাওয়া গেছে। আপডেট করলে নতুন ফিচার ও সমাধান পাবেন।",
                  style: GoogleFonts.hindSiliguri(fontSize: 13, color: cMuted, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes,
                      style: GoogleFonts.hindSiliguri(fontSize: 12, color: cText.withOpacity(0.85)),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (downloadUrl.isNotEmpty) {
                        final uri = Uri.parse(downloadUrl);
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cAccent,
                      foregroundColor: cBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text(
                      "আপডেট করুন",
                      style: GoogleFonts.hindSiliguri(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (!force) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      "পরে করবো",
                      style: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}