import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _paymentFormKey = GlobalKey<FormState>();

  // Styling Tokens (Matching Login)
  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent = Color(0xFF00D4AA);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);

  // bKash Colors
  static const Color bKashPink = Color(0xFFE2125B);

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _processPayment() {
    if (_paymentFormKey.currentState!.validate()) {
      setState(() {
        _isProcessing = true;
      });

      // Simulate payment processing delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '৳ ৫০০ পেমেন্ট সফল হয়েছে!',
                style: GoogleFonts.hindSiliguri(color: Colors.white),
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushReplacementNamed(context, '/home');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Payment Info Card
                  Container(
                    decoration: BoxDecoration(
                      color: cCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cBorder),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "অ্যাকাউন্ট অ্যাক্টিভেশন",
                              style: GoogleFonts.hindSiliguri(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: cText,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: cAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "লাইফটাইম",
                                style: GoogleFonts.hindSiliguri(
                                  color: cAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: cBorder),
                        const SizedBox(height: 16),
                        Text(
                          "Thai Calc Pro ফুল ভার্সন আনলক করতে নিচের অ্যাক্টিভেশন ফি পেমেন্ট করুন।",
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 14,
                            color: cMuted,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Price Tag
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF12151F),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "অ্যাক্টিভেশন ফি",
                                style: GoogleFonts.hindSiliguri(
                                  fontSize: 14,
                                  color: cMuted,
                                ),
                              ),
                              Text(
                                "৳ ৫০০.০০",
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: cAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // bKash Portal Mock
                        Form(
                          key: _paymentFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // bKash Logo Header in form
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: bKashPink,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "bKash Checkout",
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: bKashPink.withOpacity(0.05),
                                  border: Border.all(color: bKashPink.withOpacity(0.3)),
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                ),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      style: GoogleFonts.inter(color: cText),
                                      decoration: InputDecoration(
                                        labelText: "বিকাশ ওয়ালেট নম্বর",
                                        labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                                        hintText: "যেমন: 017XXXXXXXX",
                                        hintStyle: GoogleFonts.inter(color: cMuted.withOpacity(0.5)),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(color: bKashPink.withOpacity(0.5)),
                                        ),
                                        focusedBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: bKashPink),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.length != 11) {
                                          return "১১ ডিজিটের সঠিক মোবাইল নম্বর দিন";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _pinController,
                                      keyboardType: TextInputType.number,
                                      obscureText: true,
                                      style: GoogleFonts.inter(color: cText),
                                      decoration: InputDecoration(
                                        labelText: "বিকাশ পিন (PIN)",
                                        labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
                                        hintText: "••••",
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(color: bKashPink.withOpacity(0.5)),
                                        ),
                                        focusedBorder: const UnderlineInputBorder(
                                          borderSide: BorderSide(color: bKashPink),
                                        ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.length < 4) {
                                          return "সঠিক পিন কোড দিন";
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _isProcessing ? null : _processPayment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: bKashPink,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: bKashPink.withOpacity(0.5),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "পেমেন্ট নিশ্চিত করুন",
                                        style: GoogleFonts.hindSiliguri(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bypass Button
                  TextButton.icon(
                    onPressed: () {
                      // Bypass to Calculator directly
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    icon: const Icon(Icons.bolt, color: cAccent2),
                    label: Text(
                      "পেমেন্ট এড়িয়ে যান (Bypass to Calculator)",
                      style: GoogleFonts.hindSiliguri(
                        color: cAccent2,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: cAccent2,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
