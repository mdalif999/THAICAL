import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_clock/system_clock.dart';
import '../models/thai_color_set.dart';
import '../models/glass_brand.dart';
import '../models/hardware_price.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DatabaseService {
  static const String supabaseUrl = 'https://zudcctqnachqaqewkzhp.supabase.co';

  static const String supabaseKey = 'sb_publishable_EBJt_mnXXfyIJv4GsM8GwA_-w33rVhI';

  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  // Trial length in days (change here only, used everywhere)
  static const int trialDays = 30;

  // Reminder banner shows when this many days (or fewer) remain
  static const int reminderDaysBefore = 5;

  // ── Device Session ID (একটা ডিভাইস চেনার জন্য) ──
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_session_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_session_id', deviceId);
    }
    return deviceId;
  }

  bool get isFallbackMode {
    return supabaseUrl.contains('placeholder') || supabaseKey == 'placeholder_key';
  }

  Map<String, dynamic>? _currentUserProfile;
  Map<String, dynamic>? get currentUserProfile => _currentUserProfile;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();

    // ── Clock tampering check (wall-clock rollback) ──
    final lastKnownStr = prefs.getString('last_known_time');
    if (lastKnownStr != null) {
      final lastKnown = DateTime.tryParse(lastKnownStr);
      if (lastKnown != null && now.isBefore(lastKnown)) {
        print("ALERT: Device clock rolled back! Blocking access.");
        await prefs.setBool('is_clock_tampered', true);
      }
    }
    await prefs.setString('last_known_time', now.toIso8601String());

    // ── Clock tampering check (boot-time / elapsed-realtime based) ──
    // elapsedRealtime বাড়তে থাকে device boot হওয়ার পর থেকে,
    // user এটা wall-clock এর মতো পাল্টাতে পারে না।
    await _checkBootTimeTampering(prefs);

    // Load cached profile if exists
    final cachedEmail = prefs.getString('cached_phone_email');
    if (cachedEmail != null) {
      _currentUserProfile = {
        'id': prefs.getString('cached_uid') ?? 'cached-user',
        'name': prefs.getString('cached_name') ?? 'cached-user',
        'phone_email': cachedEmail,
        'is_active': prefs.getBool('is_active') ?? true,
        'is_paid': prefs.getBool('is_paid') ?? false,
        'subscription_expires_at': prefs.getString('subscription_expires_at'),
        'trial_ends_at': prefs.getString('trial_ends_at'),
      };
    }

    if (isFallbackMode) {
      print('DatabaseService: Running in Mock Fallback Mode.');
      return;
    }
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseKey,
      );
      print('DatabaseService: Supabase Initialized.');
    } catch (e) {
      print('DatabaseService: Init Error: $e. Fallback to mock.');
    }
  }

  // Boot-time based tampering check.
  // Compares how much wall-clock time passed vs how much elapsed-realtime
  // passed since the last sync. Large mismatch => user changed the date/time.
  Future<void> _checkBootTimeTampering(SharedPreferences prefs) async {
    try {
      final syncWallStr = prefs.getString('sync_wall_time');
      final syncElapsedMs = prefs.getInt('sync_elapsed_ms');

      final nowWall = DateTime.now().toUtc();
      final nowElapsedMs = SystemClock.elapsedRealtime().inMilliseconds;

      if (syncWallStr != null && syncElapsedMs != null) {
        final syncWall = DateTime.parse(syncWallStr);
        final wallDiffSec = nowWall.difference(syncWall).inSeconds;
        final elapsedDiffSec = (nowElapsedMs - syncElapsedMs) ~/ 1000;

        // 5 minute tolerance for normal clock drift / NTP adjustments
        if ((wallDiffSec - elapsedDiffSec).abs() > 300) {
          print("ALERT: Boot-time mismatch detected, possible clock tampering.");
          await prefs.setBool('is_clock_tampered', true);
        }
      }

      // Always refresh the reference point for next check
      await prefs.setString('sync_wall_time', nowWall.toIso8601String());
      await prefs.setInt('sync_elapsed_ms', nowElapsedMs);
    } catch (e) {
      // system_clock unavailable (e.g. some platforms) — skip silently
      print('Boot-time check skipped: $e');
    }
  }

  SupabaseClient get _client => Supabase.instance.client;

  Future<bool> _hasInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return true; // চেক করতে না পারলে, সন্দেহের সুযোগ না দিয়ে চেষ্টা করতে দাও
    }
  }

  String _formatEmail(String emailOrPhone) {
    final trimmed = emailOrPhone.trim();
    if (trimmed.contains('@')) {
      return trimmed;
    }
    final cleanPhone = trimmed.replaceAll(RegExp(r'\D'), '');
    return '$cleanPhone@thaicalc.com';
  }

  // ── Effective access/paid calculation (single source of truth) ──
  // is_active = master switch. Paid subscription OR trial (whichever valid) grants access.
  bool hasAccess(Map<String, dynamic> profile) {
    if (profile['is_active'] != true) return false;

    final now = DateTime.now().toUtc();

    final paidExpiry = profile['subscription_expires_at'] != null
        ? DateTime.tryParse(profile['subscription_expires_at'].toString())?.toUtc()
        : null;
    final isPaidValid = profile['is_paid'] == true &&
        paidExpiry != null &&
        now.isBefore(paidExpiry);

    final trialExpiry = profile['trial_ends_at'] != null
        ? DateTime.tryParse(profile['trial_ends_at'].toString())?.toUtc()
        : null;
    final isTrialValid = trialExpiry != null && now.isBefore(trialExpiry);

    return isPaidValid || isTrialValid;
  }

  // দিন হিসেবে কত দিন বাকি আছে (পুরনো callers এর জন্য রাখা হয়েছে)
  // নতুন UI তে timeRemaining()/timeRemainingText() ব্যবহার করুন।
  int? daysRemaining(Map<String, dynamic> profile) {
    final remaining = timeRemaining(profile);
    return remaining?.inDays;
  }

  // Exact Duration বাকি আছে (paid subscription বা trial, যেটা active)। null মানে কিছু track করার নাই।
  Duration? timeRemaining(Map<String, dynamic> profile) {
    final now = DateTime.now().toUtc();

    final paidExpiry = profile['subscription_expires_at'] != null
        ? DateTime.tryParse(profile['subscription_expires_at'].toString())?.toUtc()
        : null;
    if (profile['is_paid'] == true && paidExpiry != null && now.isBefore(paidExpiry)) {
      return paidExpiry.difference(now);
    }

    final trialExpiry = profile['trial_ends_at'] != null
        ? DateTime.tryParse(profile['trial_ends_at'].toString())?.toUtc()
        : null;
    if (trialExpiry != null && now.isBefore(trialExpiry)) {
      return trialExpiry.difference(now);
    }

    return null;
  }

  // মানুষের পড়ার মতো টেক্সট — বেশি সময় বাকি থাকলে দিন, কম থাকলে ঘণ্টা/মিনিট দেখায়
  String? timeRemainingText(Map<String, dynamic> profile) {
    final remaining = timeRemaining(profile);
    if (remaining == null) return null;

    if (remaining.inDays >= 1) {
      return "${remaining.inDays} দিন";
    } else if (remaining.inHours >= 1) {
      return "${remaining.inHours} ঘণ্টা";
    } else if (remaining.inMinutes >= 1) {
      return "${remaining.inMinutes} মিনিট";
    } else {
      return "কিছুক্ষণের মধ্যে";
    }
  }

  bool shouldShowReminder(Map<String, dynamic> profile) {
    final remaining = timeRemaining(profile);
    if (remaining == null) return false;
    return remaining.inSeconds >= 0 && remaining.inDays <= reminderDaysBefore;
  }

  // ── Reminder banner dismiss (per calendar day) ──
  // User (X) চেপে বন্ধ করলে সেই দিনের জন্য আর দেখাবে না; পরদিন আবার দেখাবে।
  Future<void> dismissReminderForToday() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toUtc().toIso8601String().split('T').first;
    await prefs.setString('reminder_dismissed_date', todayKey);
  }

  Future<bool> isReminderDismissedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissedDate = prefs.getString('reminder_dismissed_date');
    if (dismissedDate == null) return false;
    final todayKey = DateTime.now().toUtc().toIso8601String().split('T').first;
    return dismissedDate == todayKey;
  }

  // ── Authentication ──
  Future<Map<String, dynamic>?> login(String emailOrPhone, String password) async {
    if (isFallbackMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      final profile = {
        'id': 'mock-user-uuid',
        'name': 'আলিফ হ(ডেমো)',
        'phone_email': emailOrPhone,
        'is_active': true,
        'is_paid': true,
        'subscription_expires_at': DateTime.now().toUtc().add(const Duration(days: 30)).toIso8601String(),
        'trial_ends_at': null,
      };
      _currentUserProfile = profile;
      await saveProfileLocally(profile);
      return profile;
    }

    try {
      final email = _formatEmail(emailOrPhone);
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final profileData = await _client
            .from('profiles')
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (profileData != null) {
          // এই ডিভাইসকে active session হিসেবে সেট করা (আগের ডিভাইস auto logout হয়ে যাবে)
          final deviceId = await _getOrCreateDeviceId();
          await _client
              .from('profiles')
              .update({'active_session_id': deviceId})
              .eq('id', response.user!.id);
          profileData['active_session_id'] = deviceId;

          // Expire হয়ে থাকলে DB তে is_paid সত্যিকারভাবে false করে দেওয়া
          await _syncExpiredPaidStatus(profileData);

          _currentUserProfile = profileData;
          await saveProfileLocally(profileData);
          return profileData;
        }
      }
    } catch (e) {
      print('Auth Error: $e');
      rethrow;
    }
    return null;
  }

  Future<Map<String, dynamic>?> signUp({
    required String name,
    required String emailOrPhone,
    required String password,
  }) async {
    final trialEndsAt = DateTime.now().toUtc().add(const Duration(days: trialDays)).toIso8601String();

    if (isFallbackMode) {
      await Future.delayed(const Duration(milliseconds: 600));
      final profile = {
        'id': 'mock-user-uuid',
        'name': name,
        'phone_email': emailOrPhone,
        'is_active': true,
        'is_paid': false,
        'subscription_expires_at': null,
        'trial_ends_at': trialEndsAt,
      };
      _currentUserProfile = profile;
      await saveProfileLocally(profile);
      return profile;
    }

    try {
      final email = _formatEmail(emailOrPhone);
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        final profileMap = {
          'id': authResponse.user!.id,
          'name': name,
          'phone_email': emailOrPhone,
          'is_active': true,
          'is_paid': false,
          'subscription_expires_at': null,
          'trial_ends_at': trialEndsAt,
        };

        await _client.from('profiles').insert(profileMap);
        _currentUserProfile = profileMap;
        await saveProfileLocally(profileMap);
        return profileMap;
      }
    } catch (e) {
      print('SignUp Error: $e');
      rethrow;
    }
    return null;
  }

  Future<void> logout() async {
    _currentUserProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear local cache on logout
    if (!isFallbackMode) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }

  // ── Local Storage Management (Offline Subscription Caching) ──
  Future<void> saveProfileLocally(Map<String, dynamic> profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_uid', profile['id']?.toString() ?? '');
    await prefs.setString('cached_name', profile['name']?.toString() ?? '');
    await prefs.setString('cached_phone_email', profile['phone_email']?.toString() ?? '');
    await prefs.setBool('is_active', profile['is_active'] == true);
    await prefs.setBool('is_paid', profile['is_paid'] == true);

    if (profile['subscription_expires_at'] != null) {
      await prefs.setString('subscription_expires_at', profile['subscription_expires_at'].toString());
    } else {
      await prefs.remove('subscription_expires_at');
    }

    if (profile['trial_ends_at'] != null) {
      await prefs.setString('trial_ends_at', profile['trial_ends_at'].toString());
    } else {
      await prefs.remove('trial_ends_at');
    }

    await prefs.setString('last_online_check', DateTime.now().toUtc().toIso8601String());
    await prefs.setString('last_known_time', DateTime.now().toUtc().toIso8601String());
    await prefs.setBool('is_clock_tampered', false); // Reset tampered flag on a fresh online sync
  }

  // Offline Verification Check logic
  // Returns a map with 'status' (bool) and 'reason' (string)
  Future<Map<String, dynamic>> checkOfflineSubscription() async {
    final prefs = await SharedPreferences.getInstance();

    if (prefs.getBool('is_clock_tampered') == true) {
      return {'status': false, 'reason': 'tampered'};
    }

    final now = DateTime.now().toUtc();

    // 1. Wall-clock rollback check
    final lastKnownStr = prefs.getString('last_known_time');
    if (lastKnownStr != null) {
      final lastKnown = DateTime.tryParse(lastKnownStr);
      if (lastKnown != null && now.isBefore(lastKnown)) {
        await prefs.setBool('is_clock_tampered', true);
        return {'status': false, 'reason': 'tampered'};
      }
    }
    await prefs.setString('last_known_time', now.toIso8601String());

    // 1b. Boot-time based check (catches date changes that stay "ahead")
    await _checkBootTimeTampering(prefs);
    if (prefs.getBool('is_clock_tampered') == true) {
      return {'status': false, 'reason': 'tampered'};
    }

    // 2. is_active gate
    final isActive = prefs.getBool('is_active') ?? true;
    if (!isActive) {
      return {'status': false, 'reason': 'blocked'};
    }

    // 3. Effective access (paid OR trial)
    final profile = {
      'is_active': isActive,
      'is_paid': prefs.getBool('is_paid') ?? false,
      'subscription_expires_at': prefs.getString('subscription_expires_at'),
      'trial_ends_at': prefs.getString('trial_ends_at'),
    };

    if (!hasAccess(profile)) {
      // Local cache sync so UI/logic downstream reflects reality
      if (prefs.getBool('is_paid') == true) {
        await prefs.setBool('is_paid', false);
      }
      return {'status': false, 'reason': 'expired'};
    }

    // 4. 3 Days Offline Refresh Check
    final lastCheckStr = prefs.getString('last_online_check');
    if (lastCheckStr != null) {
      final lastCheck = DateTime.tryParse(lastCheckStr);
      if (lastCheck != null) {
        final daysDiff = now.difference(lastCheck).inDays;
        if (daysDiff >= 5) {
          return {'status': false, 'reason': 'offline_timeout'};
        }
      }
    }

    return {'status': true, 'reason': 'active'};
  }

  // Expire হয়ে গেলে DB তে is_paid = false লিখে দেয় (source of truth clean রাখতে)
  Future<void> _syncExpiredPaidStatus(Map<String, dynamic> profileData) async {
    if (profileData['is_paid'] != true) return;
    final expiry = profileData['subscription_expires_at'] != null
        ? DateTime.tryParse(profileData['subscription_expires_at'].toString())?.toUtc()
        : null;
    final expired = expiry == null || DateTime.now().toUtc().isAfter(expiry);
    if (expired) {
      try {
        await _client
            .from('profiles')
            .update({'is_paid': false})
            .eq('id', profileData['id']);
        profileData['is_paid'] = false;
      } catch (e) {
        print('Failed to sync expired is_paid to DB: $e');
      }
    }
  }

  // Online checks to refresh cache if user has internet connection
  Future<Map<String, dynamic>> checkOnlineStatus() async {
    if (isFallbackMode) {
      return {'is_active': true, 'is_paid': true};
    }
    try {
      final userId = _client.auth.currentUser?.id;
if (userId == null) {
  // ✅ FIX: currentUser null মানে logout না
  // Supabase session expire বা initialize এ clear হতে পারে
  // এক্ষেত্রে cached local data দিয়ে চালিয়ে যাব
  final prefs = await SharedPreferences.getInstance();
  final cachedProfile = {
    'is_active': prefs.getBool('is_active') ?? true,
    'is_paid': prefs.getBool('is_paid') ?? false,
    'subscription_expires_at': prefs.getString('subscription_expires_at'),
    'trial_ends_at': prefs.getString('trial_ends_at'),
  };
  return {
    ...cachedProfile,
    'has_access': hasAccess(cachedProfile),
    'days_remaining': daysRemaining(cachedProfile),
  };
}

      final profileData = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileData != null) {
        // অন্য ডিভাইস থেকে লগইন হয়েছে কিনা চেক করা
        final myDeviceId = await _getOrCreateDeviceId();
        final serverSessionId = profileData['active_session_id']?.toString();
        if (serverSessionId != null && serverSessionId != myDeviceId) {
          return {
            'is_active': false,
            'reason': 'session_kicked',
          };
        }

        // Expire হয়ে থাকলে DB তে is_paid সত্যি করে false করে দেওয়া
        await _syncExpiredPaidStatus(profileData);

        _currentUserProfile = profileData;
        await saveProfileLocally(profileData);
        return {
          'is_active': profileData['is_active'] == true,
          'is_paid': hasAccess(profileData) && profileData['is_paid'] == true,
          'subscription_expires_at': profileData['subscription_expires_at'],
          'trial_ends_at': profileData['trial_ends_at'],
          'has_access': hasAccess(profileData),
          'days_remaining': daysRemaining(profileData),
        };
      }
    } catch (e) {
      print('Online check failed (likely offline): $e');
    }
    // Return last cached state if online query failed
    final prefs = await SharedPreferences.getInstance();
    final cachedProfile = {
      'is_active': prefs.getBool('is_active') ?? true,
      'is_paid': prefs.getBool('is_paid') ?? false,
      'subscription_expires_at': prefs.getString('subscription_expires_at'),
      'trial_ends_at': prefs.getString('trial_ends_at'),
    };
    return {
      ...cachedProfile,
      'has_access': hasAccess(cachedProfile),
      'days_remaining': daysRemaining(cachedProfile),
    };
  }

  // ── Database Fetching (Thai Color Sets) ──
  Future<List<ThaiColorSet>> getThaiColorSets() async {
    final prefs = await SharedPreferences.getInstance();
    if (isFallbackMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockThaiColorSets;
    }
    if (!await _hasInternet()) {
      print('No internet detected. Loading thai_color_sets from local cache directly.');
      final cached = prefs.getString('cached_thai_color_sets');
      if (cached != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cached);
          return decoded.map((json) => ThaiColorSet.fromJson(json)).toList();
        } catch (_) {}
      }
      return _mockThaiColorSets;
    }

    try {
      final List<dynamic> data = await _client
          .from('thai_color_sets')
          .select()
          .order('brand', ascending: true)
          .timeout(const Duration(seconds: 4));

      await prefs.setString('cached_thai_color_sets', jsonEncode(data));
      return data.map((json) => ThaiColorSet.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching thai_color_sets from Supabase: $e. Loading from local cache.');
      final cached = prefs.getString('cached_thai_color_sets');
      if (cached != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cached);
          return decoded.map((json) => ThaiColorSet.fromJson(json)).toList();
        } catch (_) {}
      }
      return _mockThaiColorSets;
    }
  }

  // ── Database Fetching (Glass Brands) ──
  Future<List<GlassBrand>> getGlassBrands() async {
    final prefs = await SharedPreferences.getInstance();
    if (isFallbackMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockGlassBrands;
    }
    if (!await _hasInternet()) {
      print('No internet detected. Loading GlassBrand from local cache directly.');
      final cached = prefs.getString('cached_glass_brands');
      if (cached != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cached);
          return decoded.map((json) => GlassBrand.fromJson(json)).toList();
        } catch (_) {}
      }
      return _mockGlassBrands;
    }

    try {
      final List<dynamic> data = await _client
          .from('glass_brands')
          .select()
          .order('brand_name', ascending: true)
          .timeout(const Duration(seconds: 4));

      await prefs.setString('cached_glass_brands', jsonEncode(data));
      return data.map((json) => GlassBrand.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching glass_brands from Supabase: $e. Loading from local cache.');
      final cached = prefs.getString('cached_glass_brands');
      if (cached != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cached);
          return decoded.map((json) => GlassBrand.fromJson(json)).toList();
        } catch (_) {}
      }
      return _mockGlassBrands;
    }
  }

  // ── Database Fetching (Hardware Prices) ──
  Future<List<HardwarePrice>> getHardwarePrices() async {
    final prefs = await SharedPreferences.getInstance();
    if (isFallbackMode) {
      await Future.delayed(const Duration(milliseconds: 300));
      return _mockHardwarePrices;
    }
    if (!await _hasInternet()) {
      print('No internet detected. Loading thai_color_sets from local cache directly.');
      final cached = prefs.getString('cached_hardware_prices');
      if (cached != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cached);
          return decoded.map((json) => HardwarePrice.fromJson(json)).toList();
        } catch (_) {}
      }
      return _mockHardwarePrices;
    }

    try {
      final List<dynamic> data = await _client
          .from('hardware_prices')
          .select()
          .timeout(const Duration(seconds: 4));

      await prefs.setString('cached_hardware_prices', jsonEncode(data));
      return data.map((json) => HardwarePrice.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching hardware_prices from Supabase: $e. Loading from local cache.');
      final cached = prefs.getString('cached_hardware_prices');
      if (cached != null) {
        try {
          final List<dynamic> decoded = jsonDecode(cached);
          return decoded.map((json) => HardwarePrice.fromJson(json)).toList();
        } catch (_) {}
      }
      return _mockHardwarePrices;
    }
  }

  // ── Invoice / Bill Storage (Local & Cloud Sync) ──
  Future<void> saveInvoice(Map<String, dynamic> invoice) async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getString('saved_invoices');
    List<dynamic> invoices = [];
    if (listStr != null) {
      try {
        invoices = jsonDecode(listStr) as List<dynamic>;
      } catch (_) {}
    }
    invoices.insert(0, invoice);
    await prefs.setString('saved_invoices', jsonEncode(invoices));

    if (!isFallbackMode) {
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId != null) {
          final dbInvoice = Map<String, dynamic>.from(invoice);
          dbInvoice['user_id'] = userId;
          await _client.from('invoices').insert(dbInvoice);
          print('Supabase: Saved invoice successfully.');
        }
      } catch (e) {
        print('Supabase: Invoice sync failed (offline or schema mismatch): $e');
      }
    }
  }

  Future<List<Map<String, dynamic>>> getSavedInvoices() async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getString('saved_invoices');
    if (listStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(listStr);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      print('Error decoding saved invoices: $e');
      return [];
    }
  }

  // ── App Update Check ──
  // app_config table (Supabase) দেখে বলে দেয় নতুন version আছে কিনা, আর force করতে হবে কিনা।
  // Internet না থাকলে null return করে (silently skip)।
  Future<Map<String, dynamic>?> checkForUpdate() async {
    if (isFallbackMode) return null;
    if (!await _hasInternet()) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // যেমন "1.0.0"

      final config = await _client
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      if (config == null) return null;

      final latestVersion = config['latest_version']?.toString();
      if (latestVersion == null) return null;

      final updateAvailable = _isNewerVersion(latestVersion, currentVersion);
      if (!updateAvailable) return null;

      return {
        'update_available': true,
        'latest_version': latestVersion,
        'current_version': currentVersion,
        'download_url': config['apk_download_url']?.toString() ?? '',
        'force_update': config['force_update'] == true,
        'release_notes': config['release_notes']?.toString(),
      };
    } catch (e) {
      print('Update check failed (likely offline or table missing): $e');
      return null;
    }
  }

  // Simple semantic version compare: "1.2.0" vs "1.10.0" ইত্যাদি ঠিকভাবে handle করে
  bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final currentParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final maxLen = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

    for (int i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  // ── Fallback local mock configurations ──
  final List<ThaiColorSet> _mockThaiColorSets = [
    ThaiColorSet(
      id: 1,
      brand: 'EDM 3"',
      color: 'Silver',
      thick: 1.2,
      specLength: "21'-0\"",
      priceOs: 2936,
      priceOt: 4089,
      priceOhb: 3494,
      priceSl: 3457,
      priceIl: 2586,
      priceSt: 2632,
      priceSb: 3758,
    ),
    ThaiColorSet(
      id: 2,
      brand: 'EDM 4"',
      color: 'Bronze',
      thick: 1.2,
      specLength: "21'-0\"",
      priceOs: 3562,
      priceOt: 4805,
      priceOhb: 4225,
      priceSl: 3457,
      priceIl: 3045,
      priceSt: 2632,
      priceSb: 3758,
    ),
    ThaiColorSet(
      id: 3,
      brand: 'EDW Silver 3"',
      color: 'Black/SS',
      thick: 1.2,
      specLength: "21'-0\"",
      priceOs: 2438,
      priceOt: 3894,
      priceOhb: 3292,
      priceSl: 3022,
      priceIl: 1085,
      priceSt: 2478,
      priceSb: 3533,
    ),
    ThaiColorSet(
      id: 4,
      brand: 'EDC 3"',
      color: 'Silver',
      thick: 1.5,
      specLength: "21'-0\"",
      priceOs: 2510,
      priceOt: 3970,
      priceOhb: 3391,
      priceSl: 3115,
      priceIl: 2959,
      priceSt: 2559,
      priceSb: 3646,
    ),
  ];

  final List<GlassBrand> _mockGlassBrands = [
    GlassBrand(id: 1, brandName: 'PHP Clear 5mm', pricePerSft: 160),
    GlassBrand(id: 2, brandName: 'Nasir Blue 5mm', pricePerSft: 180),
    GlassBrand(id: 3, brandName: 'PHP Mercury 5mm', pricePerSft: 220),
    GlassBrand(id: 4, brandName: 'Frosted Glass 5mm', pricePerSft: 170),
  ];

  final List<HardwarePrice> _mockHardwarePrices = [
    HardwarePrice(id: 1, itemKey: 'sliding_lock', itemName: '🔒 D/L ডোর লক (পিস)', price: 220),
    HardwarePrice(id: 2, itemKey: 'sliding_wheel', itemName: '⚙️ S/W চাকা / হুইল (পিস)', price: 120),
    HardwarePrice(id: 3, itemKey: 'screw_pack', itemName: '🪛 স্ক্রু প্যাক (Per window)', price: 45),
    HardwarePrice(id: 4, itemKey: 'rubber_pad', itemName: '🟤 R/P রাবার প্যাড প্যাক', price: 10),
  ];
}