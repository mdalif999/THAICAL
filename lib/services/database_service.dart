import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  static final String supabaseKey = dotenv.env['SUPABASE_KEY'] ?? '';

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

  final ValueNotifier<Map<String, dynamic>?> currentUserProfileNotifier = ValueNotifier<Map<String, dynamic>?>(null);
  Map<String, dynamic>? get currentUserProfile => currentUserProfileNotifier.value;

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
      currentUserProfileNotifier.value = {
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

    // ✅ Supabase-এ আগে থেকেই একটা persisted/auto-restored session থাকলে
    // সেটা এই ডিভাইসেরই কিনা যাচাই করা — নাহলে জোর করে সাইন-আউট
    final existingUser = _client.auth.currentUser;
    if (existingUser != null) {
      try {
        final deviceId = await _getOrCreateDeviceId();
        final profileData = await _client
            .from('profiles')
            .select()
            .eq('id', existingUser.id)
            .maybeSingle();

        final serverSessionId = profileData?['active_session_id']?.toString();

        if (profileData == null ||
            profileData['is_active'] == false ||
            (serverSessionId != null && serverSessionId.isNotEmpty && serverSessionId != deviceId)) {
          print('Auto-restore REJECTED: session mismatch or inactive. Forcing sign out.');
          await _client.auth.signOut();
          currentUserProfileNotifier.value = null;
          await _clearAuthDataOnly();
        } else {
          print('Auto-restore ACCEPTED: session matches this device.');
          currentUserProfileNotifier.value = profileData;
          await saveProfileLocally(profileData);
        }
      } catch (e) {
        print('Auto-restore check failed: $e');
      }
    }

    if (currentUserProfile != null) {
      startSessionMonitoring();
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

  Future<bool> hasInternet() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return true;
    }
  }

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
  // is_active = master switch. Trial (free user) OR Paid subscription grants access.
  bool hasAccess(Map<String, dynamic> profile) {
    if (profile['is_active'] != true) return false;

    final now = DateTime.now().toUtc();

    // 1. Trial check (free user)
    final trialExpiry = profile['trial_ends_at'] != null
        ? DateTime.tryParse(profile['trial_ends_at'].toString())?.toUtc()
        : null;
    final isTrialValid = trialExpiry != null && now.isBefore(trialExpiry);
    if (isTrialValid) return true;

    // 2. Paid subscription check
    final paidExpiry = profile['subscription_expires_at'] != null
        ? DateTime.tryParse(profile['subscription_expires_at'].toString())?.toUtc()
        : null;
    final isPaidValid = profile['is_paid'] == true &&
        (paidExpiry == null || now.isBefore(paidExpiry));
    final hasValidExpiry = paidExpiry != null && now.isBefore(paidExpiry);

    return isPaidValid || hasValidExpiry;
  }

  // দিন হিসেবে কত দিন বাকি আছে (পুরনো callers এর জন্য রাখা হয়েছে)
  // নতুন UI তে timeRemaining()/timeRemainingText() ব্যবহার করুন।
  int? daysRemaining(Map<String, dynamic> profile) {
    final remaining = timeRemaining(profile);
    return remaining?.inDays;
  }

  // Exact Duration বাকি আছে (trial first, then paid subscription)। null মানে কিছু track করার নাই।
  Duration? timeRemaining(Map<String, dynamic> profile) {
    final now = DateTime.now().toUtc();

    // 1. Trial check (free user)
    final trialExpiry = profile['trial_ends_at'] != null
        ? DateTime.tryParse(profile['trial_ends_at'].toString())?.toUtc()
        : null;
    if (trialExpiry != null && now.isBefore(trialExpiry)) {
      return trialExpiry.difference(now);
    }

    // 2. Paid subscription check
    final paidExpiry = profile['subscription_expires_at'] != null
        ? DateTime.tryParse(profile['subscription_expires_at'].toString())?.toUtc()
        : null;
    if (profile['is_paid'] == true) {
      if (paidExpiry == null) {
        return const Duration(days: 36500); // 100 years for lifetime paid
      }
      if (now.isBefore(paidExpiry)) {
        return paidExpiry.difference(now);
      }
    }

    // subscription_expires_at সেট থাকলেও remaining time দেখাও (is_paid true না হলেও)
    if (paidExpiry != null && now.isBefore(paidExpiry)) {
      return paidExpiry.difference(now);
    }

    return null;
  }

  // মানুষের পড়ার মতো টেক্সট — বেশি সময় বাকি থাকলে দিন, কম থাকলে ঘণ্টা/মিনিট দেখায়
  String? timeRemainingText(Map<String, dynamic> profile) {
    final remaining = timeRemaining(profile);
    if (remaining == null) return null;

    if (remaining.inDays > 18250) {
      return "আনলিমিটেড";
    }

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
    if (remaining.inDays > 18250) return false;
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
      currentUserProfileNotifier.value = profile;
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
          if (profileData['is_active'] == false) {
            await _client.auth.signOut();
            throw Exception('deactivated');
          }

          final deviceId = await _getOrCreateDeviceId();

          // Expire হয়ে থাকলে DB তে is_paid সত্যিকারভাবে false করে দেওয়া
          await _syncExpiredPaidStatus(profileData);

          // ── Subscription expire check (set_active_session এর আগেই) ──
          if (!hasAccess(profileData)) {
            await _client.auth.signOut();
            throw Exception('expired');
          }

          // ── Session Lock: check if another device is already active ──
          final existingSession = profileData['active_session_id']?.toString();
          if (existingSession != null && existingSession != deviceId) {
            print('Session Lock: REJECTED - another device active ($existingSession)');
            await _client.auth.signOut();
            throw Exception('device_active_elsewhere');
          }

          // ── Set active session ──
          final sessionGranted = await _client
              .rpc('set_active_session', params: {
                'p_user_id': response.user!.id,
                'p_device_id': deviceId,
              });

          print('Session Lock: rpc result=$sessionGranted, myDeviceId=$deviceId');

          if (sessionGranted != true) {
            print('Session Lock: REJECTED - another device active');
            await _client.auth.signOut();
            throw Exception('device_active_elsewhere');
          }

          print('Session Lock: GRANTED - active_session_id set to $deviceId');
          profileData['active_session_id'] = deviceId;

          currentUserProfileNotifier.value = profileData;
          await saveProfileLocally(profileData);
          startSessionMonitoring();
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
      currentUserProfileNotifier.value = profile;
      await saveProfileLocally(profile);
      startSessionMonitoring();
      return profile;
    }

    try {
      final email = _formatEmail(emailOrPhone);
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user != null) {
        final deviceId = await _getOrCreateDeviceId();
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
        // Prothom device ke active session set (RPC diye atomic)
        try {
          await _client.rpc('set_active_session', params: {
            'p_user_id': authResponse.user!.id,
            'p_device_id': deviceId,
          });
          print('SignUp: active_session_id set to $deviceId');
        } catch (e) {
          print('SignUp: FAILED to set active_session_id! Error: $e');
        }
        profileMap['active_session_id'] = deviceId;

        currentUserProfileNotifier.value = profileMap;
        await saveProfileLocally(profileMap);
        startSessionMonitoring();
        return profileMap;
      }
    } catch (e) {
      print('SignUp Error: $e');
      rethrow;
    }
    return null;
  }

  Timer? _sessionTimer;
  RealtimeChannel? _sessionChannel;

  void startSessionMonitoring() {
    // ✅ আগে থেকে কোনো channel থাকলে সেটা আগে unsubscribe করো
    _sessionChannel?.unsubscribe();
    _sessionChannel = null;

    final userId = isFallbackMode ? 'mock-user-uuid' : _client.auth.currentUser?.id;
    if (userId == null || currentUserProfile == null) return;
    if (isFallbackMode) return;

    // ── Realtime: profile row বদলালেই সাথে সাথে ধরা পড়বে ──
    _sessionChannel = _client
        .channel('session-watch-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) async {
            final newProfile = payload.newRecord;
            currentUserProfileNotifier.value = newProfile;
            await saveProfileLocally(newProfile);

            final isActive = newProfile['is_active'] == true;
            final access = hasAccess(newProfile);

            if (!isActive || !access) {
              final reason = !isActive ? 'blocked' : 'expired';
              await _handleForceLogout(reason);
            }
          },
        )
        .subscribe();

    // ── Backup: প্রতি ৫ মিনিটে শুধু offline/clock-tampering check (হালকা, লোকাল) ──
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      final offlineCheck = await checkOfflineSubscription();
      if (!offlineCheck['status']) {
        timer.cancel();
        final reason = offlineCheck['reason']?.toString() ?? 'blocked';
        await _handleForceLogout(reason);
      }
    });
  }

  Future<void> _handleForceLogout(String reason) async {
    final name = currentUserProfile?['name']?.toString();
    final phoneEmail = currentUserProfile?['phone_email']?.toString();

    await logout();

    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/deactivated',
      (route) => false,
      arguments: {
        'reason': reason,
        'name': name,
        'phone_email': phoneEmail,
      },
    );
  }

  void stopSessionMonitoring() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _sessionChannel?.unsubscribe();
    _sessionChannel = null;
  }

  Future<void> logout() async {
    stopSessionMonitoring();
    if (!isFallbackMode) {
      try {
        final userId = _client.auth.currentUser?.id;
        if (userId != null) {
          await _client.from('profiles').update({
            'active_session_id': null,
          }).eq('id', userId);
          print('Logout: active_session_id cleared for $userId');
        }
      } catch (e) {
        print('Logout: FAILED to clear active_session_id. Error: $e');
      }
    }
    currentUserProfileNotifier.value = null;
    await _clearAuthDataOnly();
    if (!isFallbackMode) {
      try {
        await _client.auth.signOut();
      } catch (_) {}
    }
  }

  // ── শুধু Auth-Related Keys মুছবে (invoices, cache, pic রাখবে) ──
  Future<void> _clearAuthDataOnly() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_uid');
    await prefs.remove('cached_name');
    await prefs.remove('cached_phone_email');
    await prefs.remove('is_active');
    await prefs.remove('is_paid');
    await prefs.remove('subscription_expires_at');
    await prefs.remove('trial_ends_at');
    await prefs.remove('last_online_check');
    await prefs.remove('last_known_time');
    await prefs.remove('is_clock_tampered');
    await prefs.remove('sync_wall_time');
    await prefs.remove('sync_elapsed_ms');
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
    if (expiry == null) return; // If expiry is null, it's unlimited. Do not auto-expire!
    
    final expired = DateTime.now().toUtc().isAfter(expiry);
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
        // Expire হয়ে থাকলে DB তে is_paid সত্যি করে false করে দেওয়া
        await _syncExpiredPaidStatus(profileData);

        currentUserProfileNotifier.value = profileData;
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

  Future<void> deleteInvoice(int index) async {
  final prefs = await SharedPreferences.getInstance();
  final listStr = prefs.getString('saved_invoices');
  if (listStr == null) return;
  try {
    final List<dynamic> invoices = jsonDecode(listStr) as List<dynamic>;
    if (index < 0 || index >= invoices.length) return;
    invoices.removeAt(index);
    await prefs.setString('saved_invoices', jsonEncode(invoices));
  } catch (e) {
    print('Error deleting invoice: $e');
  }
}

  // ── App Update Check ──
  // app_config table (Supabase) দেখে বলে দেয় নতুন version আছে কিনা, আর force করতে হবে কিনা।
  // Internet না থাকলে null return করে (silently skip)।
  Future<Map<String, dynamic>?> checkForUpdate() async {
    print('UPDATE CHECK: Starting...');
    print('UPDATE CHECK: isFallbackMode = $isFallbackMode');
    if (isFallbackMode) {
      print('UPDATE CHECK: Skipped - fallback mode');
      return null;
    }
    final hasNet = await _hasInternet();
    print('UPDATE CHECK: hasInternet = $hasNet');
    if (!hasNet) {
      print('UPDATE CHECK: Skipped - no internet');
      return null;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      print('UPDATE CHECK: currentVersion = $currentVersion');

      final config = await _client
          .from('app_config')
          .select()
          .eq('id', 1)
          .maybeSingle()
          .timeout(const Duration(seconds: 4));

      print('UPDATE CHECK: config from DB = $config');

      if (config == null) {
        print('UPDATE CHECK: config is NULL - row id=1 not found');
        return null;
      }

      final latestVersion = config['latest_version']?.toString();
      print('UPDATE CHECK: latestVersion = $latestVersion');
      if (latestVersion == null) return null;

      final updateAvailable = _isNewerVersion(latestVersion, currentVersion);
      print('UPDATE CHECK: updateAvailable = $updateAvailable ($latestVersion vs $currentVersion)');
      if (!updateAvailable) return null;

      final result = {
        'update_available': true,
        'latest_version': latestVersion,
        'current_version': currentVersion,
        'download_url': config['apk_download_url']?.toString() ?? '',
        'force_update': config['force_update'] == true,
        'release_notes': config['release_notes']?.toString(),
      };
      print('UPDATE CHECK: returning update info = $result');
      return result;
    } catch (e) {
      print('UPDATE CHECK FAILED: $e');
      return null;
    }
  }

  // ── Periodic Update Check helpers ──
  static const String _lastUpdateCheckKey = 'last_update_check_timestamp';

  Future<void> saveLastUpdateCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastUpdateCheckKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> shouldCheckForUpdate({int intervalDays = 3}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(_lastUpdateCheckKey);
    if (lastCheck == null) return true;
    final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
    return DateTime.now().difference(lastCheckTime).inDays >= intervalDays;
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

  // ── Profile Picture ──
  static const String _profilePicKey = 'profile_picture_path';

  Future<void> saveProfilePicture(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilePicKey, filePath);
  }

  Future<String?> getProfilePicture() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profilePicKey);
  }

  Future<void> removeProfilePicture() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profilePicKey);
  }

  // ── Message Check (Supabase `messages` table) ──
  // দিনে একবার check করে, নতুন message থাকলে return করে।
  static const String _lastMessageCheckKey = 'last_message_check_timestamp';
  static const String _lastSeenMessageIdKey = 'last_seen_message_id';

  Future<Map<String, dynamic>?> checkForMessage() async {
    if (isFallbackMode) return null;
    final hasNet = await hasInternet();
    if (!hasNet) return null;

    try {
      final lastSeenId = await _getLastSeenMessageId();

      final message = await _client
          .from('messages')
          .select()
          .gt('id', lastSeenId)
          .order('id', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (message == null) return null;

      // এই message ইতিমধ্যে দেখা হয়েছে কিনা check
      if (message['id'] == lastSeenId) return null;

      return message;
    } catch (e) {
      return null;
    }
  }

  Future<void> markMessageAsSeen(int messageId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeenMessageIdKey, messageId);
  }

  Future<int> _getLastSeenMessageId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSeenMessageIdKey) ?? 0;
  }

  // ── Fallback local mock configurations ──
  final List<ThaiColorSet> _mockThaiColorSets = [
    ThaiColorSet(
      id: 1,
      brand: 'EDM',
      color: 'Silver',
      profileSize: '3"',
      specLength: "21'-0\"",
      priceOs: 2936,
      priceOt: 4089,
      priceOhb: 3494,
      priceSl: 3457,
      priceIl: 2586,
      priceSt: 2632,
      priceSb: 3758,
      priceNs: null,
      priceNb: null,
    ),
    ThaiColorSet(
      id: 2,
      brand: 'EDM',
      color: 'Bronze',
      profileSize: '4"',
      specLength: "21'-0\"",
      priceOs: 3562,
      priceOt: 4805,
      priceOhb: 4225,
      priceSl: 3457,
      priceIl: 3045,
      priceSt: 2632,
      priceSb: 3758,
      priceNs: 2500,
      priceNb: 2200,
    ),
    ThaiColorSet(
      id: 3,
      brand: 'EDW Silver',
      color: 'Black/SS',
      profileSize: '3"',
      specLength: "21'-0\"",
      priceOs: 2438,
      priceOt: 3894,
      priceOhb: 3292,
      priceSl: 3022,
      priceIl: 1085,
      priceSt: 2478,
      priceSb: 3533,
      priceNs: null,
      priceNb: null,
    ),
    ThaiColorSet(
      id: 4,
      brand: 'EDC',
      color: 'Silver',
      profileSize: '3"',
      specLength: "21'-0\"",
      priceOs: 2510,
      priceOt: 3970,
      priceOhb: 3391,
      priceSl: 3115,
      priceIl: 2959,
      priceSt: 2559,
      priceSb: 3646,
      priceNs: null,
      priceNb: null,
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