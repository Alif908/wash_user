// lib/services/wash_session_manager.dart
//
// ─────────────────────────────────────────────────────────────────────────────
// HOW THE STATUS CODES WORK
//
//   0          → Machine is IDLE (not running yet)
//   1001       → WASH_10 running
//   1002       → WASH_20 running
//   1003       → WASH_50 running
//   2000       → Machine COMPLETED
//   -1         → API / network error (internal sentinel)
//
// POLLING FLOW (runs every 10 seconds after session starts):
//
//   Step 1 → Wait 10 s before first poll (machine needs time to boot up)
//   Step 2 → Poll every 10 s
//   Step 3 → If code is 1001/1002/1003: machine is running → reset error counters
//   Step 4 → If code is 2000: increment confirm counter.
//             Navigate to WashCompleted ONLY after 2 consecutive 2000 responses
//   Step 5 → If code is 0 and machine has NOT started yet: wait patiently
//   Step 6 → If code is 0 AFTER machine was running: increment error counter.
//             End session only after 5 failures.
//   Step 7 → Countdown timer reaching zero only marks complete IF machine
//             has already started (i.e., we received at least one 1xxx code).
//             If machine never started, timer expiry is ignored — we keep
//             polling until the machine actually starts and completes.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wash_user/services/api_service.dart';

class WashSessionManager extends ChangeNotifier {
  // ── Singleton ──────────────────────────────────────────────────────────────
  WashSessionManager._();
  static final WashSessionManager instance = WashSessionManager._();

  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const _kStartTime = 'ws_startTime';
  static const _kDuration = 'ws_durationSeconds';
  static const _kHubId = 'ws_hubId';
  static const _kHubDeviceId = 'ws_hubDeviceId';
  static const _kDeviceCode = 'ws_deviceCode';
  static const _kHubName = 'ws_hubName';
  static const _kPackageName = 'ws_packageName';
  static const _kAmountPaid = 'ws_amountPaid';
  static const _kPaymentId = 'ws_paymentId';

  // ── Status code constants ──────────────────────────────────────────────────
  static const int _statusIdle = 0;
  static const int _statusWash10 = 1001;
  static const int _statusWash20 = 1002;
  static const int _statusWash50 = 1003;
  static const int _statusCompleted = 2000;
  static const int _statusApiError = -1;

  // ── Polling thresholds ─────────────────────────────────────────────────────
  static const int _maxErrors = 5;
  static const int _confirmThreshold = 2;

  // ── Public getters ─────────────────────────────────────────────────────────
  bool get isActive => _startTime != null;
  bool get isComplete => _isComplete;
  DateTime? get startTime => _startTime;
  int get totalSeconds => _totalSeconds;
  String? get hubId => _hubId;
  String? get hubDeviceId => _hubDeviceId;
  String? get deviceCode => _deviceCode;
  String? get hubName => _hubName;
  String? get packageName => _packageName;
  double get amountPaid => _amountPaid;
  String? get paymentId => _paymentId;

  /// Remaining seconds computed live from wall-clock.
  int get remainingSeconds {
    if (_startTime == null) return 0;
    final elapsed = DateTime.now().difference(_startTime!).inSeconds;
    return (_totalSeconds - elapsed).clamp(0, _totalSeconds);
  }

  /// 0.0 → 1.0 progress.
  double get progress {
    if (_totalSeconds == 0) return 1.0;
    return ((_totalSeconds - remainingSeconds) / _totalSeconds).clamp(0.0, 1.0);
  }

  // ── Private state ──────────────────────────────────────────────────────────
  DateTime? _startTime;
  int _totalSeconds = 0;
  String? _hubId, _hubDeviceId, _deviceCode, _hubName, _packageName, _paymentId;
  double _amountPaid = 0.0;
  bool _isComplete = false;

  /// True once we receive at least one 1001/1002/1003 response.
  bool _machineHasStarted = false;
  int _consecutiveErrors = 0;
  int _completionConfirms = 0;

  Timer? _uiTimer;
  Timer? _pollTimer;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> startSession({
    required int durationMinutes,
    required String hubId,
    required String hubDeviceId,
    required String deviceCode,
    required String hubName,
    required String packageName,
    required double amountPaid,
    String? paymentId,
  }) async {
    if (isActive) {
      debugPrint(
        '⚠️ [WashSession] startSession called but already active — ignored',
      );
      return;
    }

    _startTime = DateTime.now();
    _totalSeconds = durationMinutes * 60;
    _hubId = hubId;
    _hubDeviceId = hubDeviceId;
    _deviceCode = deviceCode;
    _hubName = hubName;
    _packageName = packageName;
    _amountPaid = amountPaid;
    _paymentId = paymentId;
    _isComplete = false;
    _machineHasStarted = false;
    _consecutiveErrors = 0;
    _completionConfirms = 0;

    await _persist();

    debugPrint('⏳ [WashSession] Waiting 10 s before first poll...');
    await Future.delayed(const Duration(seconds: 10));

    _startTimers();
    notifyListeners();
  }

  Future<void> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final startIso = prefs.getString(_kStartTime);
    if (startIso == null) return;

    final start = DateTime.tryParse(startIso);
    final duration = prefs.getInt(_kDuration) ?? 0;
    if (start == null || duration == 0) return;

    if (DateTime.now().difference(start).inSeconds >= duration) {
      debugPrint(
        'ℹ️ [WashSession] Restored session already expired — clearing',
      );
      await clearSession();
      return;
    }

    _startTime = start;
    _totalSeconds = duration;
    _hubId = prefs.getString(_kHubId);
    _hubDeviceId = prefs.getString(_kHubDeviceId);
    _deviceCode = prefs.getString(_kDeviceCode);
    _hubName = prefs.getString(_kHubName);
    _packageName = prefs.getString(_kPackageName);
    _amountPaid = prefs.getDouble(_kAmountPaid) ?? 0.0;
    _paymentId = prefs.getString(_kPaymentId);
    _isComplete = false;
    _machineHasStarted = false;
    _consecutiveErrors = 0;
    _completionConfirms = 0;

    _startTimers();
    notifyListeners();
    debugPrint('✅ [WashSession] Session restored from prefs');
  }

  Future<void> clearSession() async {
    _stopTimers();

    _startTime = null;
    _totalSeconds = 0;
    _isComplete = false;
    _machineHasStarted = false;
    _consecutiveErrors = 0;
    _completionConfirms = 0;

    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _kStartTime,
      _kDuration,
      _kHubId,
      _kHubDeviceId,
      _kDeviceCode,
      _kHubName,
      _kPackageName,
      _kAmountPaid,
      _kPaymentId,
    ]) {
      await prefs.remove(key);
    }

    notifyListeners();
    debugPrint('🗑️ [WashSession] Session cleared');
  }

  // ── Timers ─────────────────────────────────────────────────────────────────

  void _startTimers() {
    _stopTimers();

    // UI timer: notifies every second so the countdown widget redraws.
    // ⚠️  FIX: Countdown reaching zero does NOT auto-complete the session
    //     if the machine never started. We only mark complete from the timer
    //     if _machineHasStarted is true (i.e., we saw at least one 1xxx code).
    //     If the machine never started, we keep the UI running and rely solely
    //     on the poll timer to detect completion via status 2000.
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds <= 0 && !_isComplete) {
        if (_machineHasStarted) {
          // Machine ran and the paid duration has elapsed — safe to complete.
          debugPrint(
            '⏱️ [WashSession] Countdown reached zero (machine ran) — marking complete',
          );
          _stopTimers();
          _isComplete = true;
        } else {
          // Machine never sent a running code yet.
          // The countdown may have expired but we haven't confirmed a wash.
          // Keep showing the UI; poll timer will handle real completion.
          debugPrint(
            '⏱️ [WashSession] Countdown at zero but machine never started — waiting for IoT',
          );
        }
      }
      notifyListeners();
    });

    // Poll timer: checks IoT status every 10 seconds.
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollBackend();
    });

    debugPrint('▶️ [WashSession] Timers started');
  }

  void _stopTimers() {
    _uiTimer?.cancel();
    _uiTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Core polling logic ─────────────────────────────────────────────────────

  Future<void> _pollBackend() async {
    if (!isActive || _hubId == null || _hubDeviceId == null) return;

    if (_isComplete) {
      debugPrint('ℹ️ [WashSession] Poll skipped — session already complete');
      return;
    }

    final int code = await _fetchStatusCode();
    debugPrint(
      '🔄 [WashSession] iotStatusCode=$code  '
      'machineStarted=$_machineHasStarted  '
      'errors=$_consecutiveErrors  '
      'confirms=$_completionConfirms',
    );

    // ── CASE 1: Machine is WASHING (1001 / 1002 / 1003) ──────────────────────
    if (code == _statusWash10 ||
        code == _statusWash20 ||
        code == _statusWash50) {
      debugPrint('✅ [WashSession] Machine is RUNNING (code=$code)');
      _machineHasStarted = true;
      _consecutiveErrors = 0;
      _completionConfirms = 0;

      // ── CASE 2: Machine COMPLETED (2000) ─────────────────────────────────────
    } else if (code == _statusCompleted) {
      debugPrint(
        '🏁 [WashSession] Status=2000 — confirm #${_completionConfirms + 1}',
      );
      _machineHasStarted = true; // 2000 also counts as "machine ran"
      _consecutiveErrors = 0;
      _completionConfirms++;

      if (_completionConfirms >= _confirmThreshold) {
        debugPrint('✅ [WashSession] Completion confirmed — signalling UI');
        _stopTimers();
        _isComplete = true;
        notifyListeners();
        return;
      }

      // ── CASE 3: IDLE (0) ──────────────────────────────────────────────────────
    } else if (code == _statusIdle) {
      if (!_machineHasStarted) {
        // Expected during startup — be patient, don't count as error.
        debugPrint('⏳ [WashSession] Machine not started yet — waiting...');
      } else {
        // Machine was running but now reports idle — possible glitch.
        debugPrint(
          '⚠️ [WashSession] Machine stopped unexpectedly (was running)',
        );
        _consecutiveErrors++;
      }

      // ── CASE 4: API / network error (-1) ─────────────────────────────────────
    } else if (code == _statusApiError) {
      debugPrint(
        '❌ [WashSession] API error — consecutive: ${_consecutiveErrors + 1}',
      );
      _consecutiveErrors++;

      // ── CASE 5: Unknown code ──────────────────────────────────────────────────
    } else {
      debugPrint('❓ [WashSession] Unknown status code=$code — ignoring');
    }

    // ── Error threshold (only applies after machine has started) ─────────────
    if (_machineHasStarted && _consecutiveErrors >= _maxErrors) {
      debugPrint(
        '❌ [WashSession] Too many errors after machine started — clearing session',
      );
      _stopTimers();
      await clearSession();
      return;
    }

    notifyListeners();
  }

  // ── Fetch status code from API ─────────────────────────────────────────────
  //
  //  ⚠️  IMPORTANT: This method tries multiple JSON paths because different
  //  backend versions wrap the response differently. We log every candidate
  //  so you can see exactly what the backend is returning.
  //
  //  Expected response shapes (any of these are handled):
  //    { "hubDevice": { "iotStatusCode": 1001 } }          ← original
  //    { "data": { "iotStatusCode": 1001 } }               ← alternate
  //    { "iotStatusCode": 1001 }                           ← flat
  //    { "hubDevice": { "iotStatus": 1001 } }              ← older key name
  //    { "hubDevice": { "status": 1001 } }                 ← legacy key name
  // ──────────────────────────────────────────────────────────────────────────

  Future<int> _fetchStatusCode() async {
    try {
      final result = await ApiService.getHubDeviceDetails(
        _hubId!,
        _hubDeviceId!,
      );

      if (!result.success) {
        debugPrint(
          '⚠️ [WashSession] API returned failure: ${result.errorMessage}',
        );
        return _statusApiError;
      }

      final responseData = result.data;
      debugPrint('🔍 [WashSession] Raw API response: $responseData');

      // Try all known JSON paths in priority order.
      final candidates = [
        responseData?['hubDevice']?['iotStatusCode'], // ← primary path
        responseData?['hubDevice']?['iotStatus'], // ← alternate key
        responseData?['hubDevice']?['status'], // ← legacy key
        responseData?['data']?['iotStatusCode'], // ← alternate wrapper
        responseData?['data']?['iotStatus'],
        responseData?['iotStatusCode'], // ← flat response
        responseData?['iotStatus'],
        responseData?['status'],
      ];

      debugPrint('🔍 [WashSession] Candidate values: $candidates');

      for (final raw in candidates) {
        if (raw == null) continue;

        final parsed = raw is int ? raw : int.tryParse(raw.toString());
        if (parsed != null) {
          debugPrint('✅ [WashSession] Resolved iotStatusCode = $parsed');
          return parsed;
        }
      }

      // All paths returned null — treat as idle (machine may still be booting).
      debugPrint(
        '⚠️ [WashSession] iotStatusCode not found in any path — treating as idle',
      );
      return _statusIdle;
    } catch (e) {
      debugPrint('❌ [WashSession] Exception fetching status: $e');
      return _statusApiError;
    }
  }

  // ── Persist to SharedPreferences ──────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStartTime, _startTime!.toIso8601String());
    await prefs.setInt(_kDuration, _totalSeconds);
    await prefs.setString(_kHubId, _hubId ?? '');
    await prefs.setString(_kHubDeviceId, _hubDeviceId ?? '');
    await prefs.setString(_kDeviceCode, _deviceCode ?? '');
    await prefs.setString(_kHubName, _hubName ?? '');
    await prefs.setString(_kPackageName, _packageName ?? '');
    await prefs.setDouble(_kAmountPaid, _amountPaid);
    await prefs.setString(_kPaymentId, _paymentId ?? '');
    debugPrint('💾 [WashSession] Session persisted to SharedPreferences');
  }
}
