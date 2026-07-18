import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/database_service.dart';
import 'update_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _signUpFormKey = GlobalKey<FormState>();

  // Form inputs
  final _phoneEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _signUpPhoneEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureSignUpPassword = true;

  // Styling Tokens
  static const Color cBg = Color(0xFF0F1117);
  static const Color cCard = Color(0xFF1A1D27);
  static const Color cBorder = Color(0xFF2A2D3A);
  static const Color cAccent = Color(0xFF00D4AA);
  static const Color cAccent2 = Color(0xFFFF6B35);
  static const Color cText = Color(0xFFE8EAF0);
  static const Color cMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoLoginAndLicensing());
  }

  Future<void> _checkAutoLoginAndLicensing() async {
  // ✅ cached user না থাকলে কিছু check করব না
  // Login screen এ থাকুক, user নিজে login করবে
  final profile = DatabaseService.instance.currentUserProfile;
  if (profile == null) return;

  final updateInfo = await DatabaseService.instance.checkForUpdate();
  if (updateInfo != null && mounted) {
    await showUpdateDialog(context, updateInfo);
    if (updateInfo['force_update'] == true) return;
  }

  final check = await DatabaseService.instance.checkOfflineSubscription();
  if (!check['status']) {
    if (mounted) Navigator.pushReplacementNamed(context, '/deactivated');
    return;
  }

  final onlineState = await DatabaseService.instance.checkOnlineStatus();
  if (!mounted) return;

  if (onlineState['is_active'] == false) {
    Navigator.pushReplacementNamed(
      context,
      '/deactivated',
      arguments: onlineState['reason']?.toString(),
    );
    return;
  }

  final freshProfile = DatabaseService.instance.currentUserProfile;
  if (freshProfile != null && DatabaseService.instance.hasAccess(freshProfile)) {
    Navigator.pushReplacementNamed(context, '/home');
  } else {
    Navigator.pushReplacementNamed(context, '/deactivated');
  }
}

  @override
  void dispose() {
    _tabController.dispose();
    _phoneEmailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _signUpPhoneEmailController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final profile = await DatabaseService.instance.login(
        _phoneEmailController.text,
        _passwordController.text,
      );
      
      if (profile != null) {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } else {
        _showError("লগইন ব্যর্থ হয়েছে! অনুগ্রহ করে আবার চেষ্টা করুন।");
      }
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('deactivated') && mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/deactivated',
          arguments: 'blocked',
        );
      } else if (errStr.contains('device_active_elsewhere')) {
        _showError("আপনার অ্যাকাউন্ট এখন অন্য একটি ডিভাইসে লগইন করা আছে। ঐ ডিভাইস থেকে লগআউট করে আবার চেষ্টা করুন।");
      } else {
        _showError("লগইন ব্যর্থ হয়েছে: ${errStr.replaceAll('Exception: ', '')}");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final profile = await DatabaseService.instance.signUp(
        name: _nameController.text,
        emailOrPhone: _signUpPhoneEmailController.text,
        password: _signUpPasswordController.text,
      );
      
      if (profile != null) {
  if (mounted) Navigator.pushReplacementNamed(context, '/home');
} else {
  _showError("রেজিস্ট্রেশন ব্যর্থ হয়েছে!");
}
    } catch (e) {
      _showError("রেজিস্ট্রেশন ব্যর্থ হয়েছে: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.hindSiliguri(color: Colors.white)),
        backgroundColor: cAccent2,
      ),
    );
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
                  // Logo / Branding Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.calculate_rounded,
                            size: 48,
                            color: cAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Thai Calc Pro",
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: cText,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "থাই অ্যালুমিনিয়াম ও গ্লাস হিসাবের সহজ সমাধান",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.hindSiliguri(
                            fontSize: 14,
                            color: cMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login / Sign Up Card
                  Container(
                    decoration: BoxDecoration(
                      color: cCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Custom TabBar
                        TabBar(
                          controller: _tabController,
                          indicatorColor: cAccent,
                          labelColor: cAccent,
                          unselectedLabelColor: cMuted,
                          labelStyle: GoogleFonts.hindSiliguri(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          unselectedLabelStyle: GoogleFonts.hindSiliguri(
                            fontSize: 16,
                          ),
                          tabs: const [
                            Tab(text: "লগইন"),
                            Tab(text: "রেজিস্ট্রেশন"),
                          ],
                        ),
                        const Divider(height: 1, color: cBorder),

                        // TabBarView Content (Constrained height for forms)
                        SizedBox(
                          height: 310,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Login Tab
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Form(
                                  key: _loginFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildTextField(
                                        controller: _phoneEmailController,
                                        label: "মোবাইল নম্বর অথবা ইমেইল",
                                        hint: "০১৭xxxxxxxx / user@email.com",
                                        icon: Icons.phone_android,
                                        validator: (val) {
                                          if (val == null || val.isEmpty) {
                                            return "মোবাইল বা ইমেইল লিখুন";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      _buildTextField(
                                        controller: _passwordController,
                                        label: "পাসওয়ার্ড",
                                        hint: "••••••••",
                                        icon: Icons.lock_outline,
                                        obscureText: _obscurePassword,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: cMuted,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(
                                              () => _obscurePassword = !_obscurePassword),
                                        ),
                                        validator: (val) {
                                          if (val == null || val.length < 6) {
                                            return "পাসওয়ার্ড অন্তত ৬ অক্ষরের হতে হবে";
                                          }
                                          return null;
                                        },
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: _isLoading ? null : _submitLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: cAccent,
                                          foregroundColor: cBg,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: cBg,
                                                ),
                                              )
                                            : Text(
                                                "লগইন করুন",
                                                style: GoogleFonts.hindSiliguri(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Registration Tab
                              Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Form(
                                  key: _signUpFormKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildTextField(
                                        controller: _nameController,
                                        label: "আপনার নাম",
                                        hint: "যেমন: মোঃ আলিফ হোসেন",
                                        icon: Icons.person_outline,
                                        validator: (val) {
                                          if (val == null || val.isEmpty) {
                                            return "আপনার নাম লিখুন";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField(
                                        controller: _signUpPhoneEmailController,
                                        label: "মোবাইল নম্বর অথবা ইমেইল",
                                        hint: "০১৭xxxxxxxx / user@email.com",
                                        icon: Icons.phone_android,
                                        validator: (val) {
                                          if (val == null || val.isEmpty) {
                                            return "মোবাইল বা ইমেইল লিখুন";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      _buildTextField(
                                        controller: _signUpPasswordController,
                                        label: "পাসওয়ার্ড",
                                        hint: "••••••••",
                                        icon: Icons.lock_outline,
                                        obscureText: _obscureSignUpPassword,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureSignUpPassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: cMuted,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() =>
                                              _obscureSignUpPassword = !_obscureSignUpPassword),
                                        ),
                                        validator: (val) {
                                          if (val == null || val.length < 6) {
                                            return "পাসওয়ার্ড অন্তত ৬ অক্ষরের হতে হবে";
                                          }
                                          return null;
                                        },
                                      ),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: _isLoading ? null : _submitSignUp,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: cAccent,
                                          foregroundColor: cBg,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: cBg,
                                                ),
                                              )
                                            : Text(
                                                "রেজিস্ট্রেশন করুন",
                                                style: GoogleFonts.hindSiliguri(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: GoogleFonts.inter(color: cText, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.hindSiliguri(color: cMuted, fontSize: 13),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: cMuted.withOpacity(0.5), fontSize: 13),
        prefixIcon: Icon(icon, color: cMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF12151F),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cAccent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cAccent2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: cAccent2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
