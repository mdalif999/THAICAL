import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SessionTrackerService with WidgetsBindingObserver {
  static final SessionTrackerService instance = SessionTrackerService._();
  SessionTrackerService._();

  Timer? _heartbeatTimer;
  String? _currentSessionId;
  DateTime? _sessionStartTime;
  bool _isTracking = false;

  SupabaseClient get _client => Supabase.instance.client;

  // ১. সেশন ট্র্যাকিং শুরু করার মেথড (যেমন: ইউজার লগইন করলে বা অ্যাপ হোমপেজে আসলে রান করবেন)
  Future<void> startSession() async {
    final user = _client.auth.currentUser;
    // ইউজার যদি লগইন করা না থাকে অথবা অলরেডি ট্র্যাকিং চলতে থাকে, তবে রিটার্ন করবে
    if (user == null || _isTracking) return;
    _isTracking = true;
    _sessionStartTime = DateTime.now().toUtc();
    try {
      final sessionUuid = const Uuid().v4();
      // ডাটাবেজে একটি নতুন সেশন রো তৈরি করুন
      final response = await _client.from('session_logs').insert({
        'user_id': user.id,
        'session_id': sessionUuid,
        'started_at': _sessionStartTime!.toIso8601String(),
        'last_active_at': _sessionStartTime!.toIso8601String(),
        'duration_seconds': 0, // শুরুতে সময় ০ সেকেন্ড
      }).select('id').single();
      _currentSessionId = response['id']?.toString();
      // প্রতি ৩০ সেকেন্ড পর পর আপডেট করার টাইমার চালু
      _startHeartbeatTimer();
      
      // অ্যাপ ব্যাকগ্রাউন্ডে গেল কিনা তা বোঝার জন্য অবসার্ভার যুক্ত
      WidgetsBinding.instance.addObserver(this);
      debugPrint('Session started: $_currentSessionId');
      
    } catch (e) {
      debugPrint('Failed to start session log: $e');
      _isTracking = false;
    }
  }

  // ২. নির্দিষ্ট সময় পর পর সেশনের ডিউরেশন ডাটাবেজে আপডেট করা
  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _updateSessionDuration();
    });
  }

  Future<void> _updateSessionDuration() async {
    if (_currentSessionId == null || _sessionStartTime == null) return;
    final now = DateTime.now().toUtc();
    // সেশন শুরুর সময় থেকে এখন পর্যন্ত কত সেকেন্ড অতিবাহিত হয়েছে
    final elapsedSeconds = now.difference(_sessionStartTime!).inSeconds;
    try {
      // insert করা রো-টিতে duration_seconds এবং last_active_at আপডেট করুন
      await _client.from('session_logs').update({
        'duration_seconds': elapsedSeconds,
        'last_active_at': now.toIso8601String(),
      }).eq('id', _currentSessionId!);
      
      debugPrint('Updated session duration: $elapsedSeconds seconds');
    } catch (e) {
      debugPrint('Failed to update session duration: $e');
    }
  }

  // ৩. সেশন শেষ করা (লগআউট করলে বা অ্যাপ ব্যাকগ্রাউন্ডে চলে গেলে)
  Future<void> endSession() async {
    if (!_isTracking) return;
    
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    
    // শেষবারের মতো সঠিক সময়টি ডাটাবেজে সেভ করুন
    await _updateSessionDuration();
    debugPrint('Session ended: $_currentSessionId');
    _currentSessionId = null;
    _sessionStartTime = null;
    _isTracking = false;
  }

  // ৪. অ্যাপ মিনিমাইজ (Paused) বা পুনরায় স্ক্রিনে আসলে (Resumed) হ্যান্ডেল করা
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // ইউজার হোম বাটন টিপে ব্যাকগ্রাউন্ডে চলে গেলে সেশন সেভ ও বন্ধ হবে
      endSession();
    } else if (state == AppLifecycleState.resumed) {
      // ইউজার আবার অ্যাপে ফিরে আসলে নতুন সেশন শুরু হবে
      startSession();
    }
  }
}
