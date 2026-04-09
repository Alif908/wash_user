// lib/services/washing_session.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wash_user/services/api_service.dart';

const bool _kTestMode = false;

class WashSessionManager extends ChangeNotifier {
  WashSessionManager._();
  static final WashSessionManager instance = WashSessionManager._();

  static const _kStartTime = 'ws_startTime';
  static const _kDuration = 'ws_durationSeconds';
  static const _kHubId = 'ws_hubId';
  static const _kHubDeviceId = 'ws_hubDeviceId';
  static const _kDeviceCode = 'ws_deviceCode';
  static const _kHubName = 'ws_hubName';
  static const _kPackageName = 'ws_packageName';
  static const _kAmountPaid = 'ws_amountPaid';
  static const _kPaymentId = 'ws_paymentId';

  static const int _statusIdle = 0;
  static const int _statusWash10 = 1001;
  static const int _statusWash20 = 1002;
  static const int _statusWash50 = 1003;
  static const int _statusCompleted = 2000;
  static const int _statusApiError = -1;

  static const int _maxErrors = 5;
  static const int _confirmThreshold = 2;
  static const int _maxSessionMinutes = 90;

  // ── Public getters ────────────────────────────────────────────────
  bool get isActive => _startTime != null;
  bool get isComplete => _isComplete;
  DateTime? get startTime => _startTime;
  int get totalSeconds => _totalSeconds;
  bool get machineStarted => _machineHasStarted;

  String? get hubId => _hubId;
  String? get hubDeviceId => _hubDeviceId;
  String? get deviceCode => _deviceCode;
  String? get hubName => _hubName;
  String? get packageName => _packageName;
  double get amountPaid => _amountPaid;
  String? get paymentId => _paymentId;

  int get remainingSeconds {
    if (_startTime == null) return 0;
    final elapsed = DateTime.now().difference(_startTime!).inSeconds;
    return (_totalSeconds - elapsed).clamp(0, _totalSeconds);
  }

  double get progress {
    if (_totalSeconds == 0) return 1.0;
    return ((_totalSeconds - remainingSeconds) / _totalSeconds).clamp(0.0, 1.0);
  }

  // ── Private state ─────────────────────────────────────────────────
  DateTime? _startTime;
  int _totalSeconds = 0;
  String? _hubId, _hubDeviceId, _deviceCode, _hubName, _packageName, _paymentId;
  double _amountPaid = 0.0;
  bool _isComplete = false;

  bool _machineHasStarted = false;
  int _consecutiveErrors = 0;
  int _completionConfirms = 0;
  int _lastKnownCode = 0;

  Timer? _uiTimer;
  Timer? _pollTimer;

  bool get mounted => _startTime != null;

  // ── Public API ────────────────────────────────────────────────────
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
    _lastKnownCode = 0;

    await _persist();

    if (_kTestMode) {
      debugPrint('🧪 [WashSession] TEST MODE — countdown only, no IoT polling');
      _startTestTimer();
    } else {
      debugPrint('⏳ [WashSession] Waiting 10 s before first poll...');
      await Future.delayed(const Duration(seconds: 10));
      _startTimers();
    }

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
    if (_hubId == null || _hubId!.isEmpty) _hubId = null;

    _hubDeviceId = prefs.getString(_kHubDeviceId);
    if (_hubDeviceId == null || _hubDeviceId!.isEmpty) _hubDeviceId = null;

    _hubName = prefs.getString(_kHubName);
    _packageName = prefs.getString(_kPackageName);
    _amountPaid = prefs.getDouble(_kAmountPaid) ?? 0.0;
    _paymentId = prefs.getString(_kPaymentId);

    _isComplete = false;
    _machineHasStarted = false;
    _consecutiveErrors = 0;
    _completionConfirms = 0;
    _lastKnownCode = 0;

    if (_kTestMode) {
      _startTestTimer();
    } else {
      _startTimers();
    }

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
    _lastKnownCode = 0;

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

  // ── TEST MODE timer ───────────────────────────────────────────────
  void _startTestTimer() {
    _stopTimers();
    debugPrint(
      '🧪 [WashSession] Test timer started — will complete in $_totalSeconds s',
    );

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remainingSeconds <= 0 && !_isComplete) {
        debugPrint('🧪 [WashSession] TEST — countdown zero → marking complete');
        _stopTimers();
        _isComplete = true;
        notifyListeners();
        return;
      }
      notifyListeners();
    });
  }

  // ── PRODUCTION timers ─────────────────────────────────────────────
  void _startTimers() {
    _stopTimers();

    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds <= 0 && !_isComplete) {
        if (_machineHasStarted) {
          debugPrint(
            '⏱️ [WashSession] Countdown zero (machine ran) → complete',
          );
          _stopTimers();
          _isComplete = true;
        } else {
          debugPrint(
            '⏱️ [WashSession] Countdown zero — machine never started, still polling',
          );
        }
      }
      notifyListeners();
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollBackend();
    });

    debugPrint('▶️ [WashSession] Production timers started');
  }

  void _stopTimers() {
    _uiTimer?.cancel();
    _uiTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ── Core polling ──────────────────────────────────────────────────
  Future<void> _pollBackend() async {
    if (!isActive || _hubId == null || _hubDeviceId == null) return;

    final elapsedMinutes = DateTime.now().difference(_startTime!).inMinutes;
    if (elapsedMinutes >= _maxSessionMinutes) {
      debugPrint('⏰ [WashSession] Session timeout — forcing completion');
      _stopTimers();
      _isComplete = true;
      notifyListeners();
      return;
    }
    if (_isComplete) return;

    // ✅ FIX: send ping AND read its action response
    final pingData = await _sendPing();

    if (pingData != null) {
      final nextState = pingData['action']?['nextState'];
      final nextStatusCode = pingData['action']?['nextStatusCode'];

      debugPrint(
        '📡 [WashSession] Ping action → nextState: $nextState  nextStatusCode: $nextStatusCode',
      );

      // Backend says WASHING → treat machine as started immediately
      if (nextState == 'WASHING' && nextStatusCode != null) {
        debugPrint('✅ [WashSession] Backend says WASHING — machine started');
        _machineHasStarted = true;
        _consecutiveErrors = 0;
        _completionConfirms = 0;
        _lastKnownCode = nextStatusCode is int
            ? nextStatusCode
            : int.tryParse(nextStatusCode.toString()) ?? _statusWash10;
        notifyListeners();
        return;
      }

      // Backend says IDLE after machine was running → completion candidate
      if (nextState == 'IDLE' && _machineHasStarted) {
        _completionConfirms++;
        debugPrint(
          '🏁 [WashSession] Ping IDLE after running — confirm #$_completionConfirms',
        );
        if (_completionConfirms >= _confirmThreshold) {
          debugPrint('✅ [WashSession] Completion confirmed via ping');
          _stopTimers();
          _isComplete = true;
          notifyListeners();
          return;
        }
      }
    }

    // Fallback: check actual iotStatusCode from device details
    final int code = await _fetchStatusCode();
    debugPrint(
      '🔄 [WashSession] iotStatusCode=$code  '
      'machineStarted=$_machineHasStarted  '
      'errors=$_consecutiveErrors  '
      'confirms=$_completionConfirms',
    );

    if (code == _statusWash10 ||
        code == _statusWash20 ||
        code == _statusWash50) {
      debugPrint('✅ [WashSession] Machine is RUNNING (code=$code)');
      _machineHasStarted = true;
      _lastKnownCode = code;
      _consecutiveErrors = 0;
      _completionConfirms = 0;
    } else if (code == _statusCompleted) {
      debugPrint(
        '🏁 [WashSession] Status=2000 — confirm #${_completionConfirms + 1}',
      );
      _machineHasStarted = true;
      _lastKnownCode = code;
      _consecutiveErrors = 0;
      _completionConfirms++;

      if (_completionConfirms >= _confirmThreshold) {
        debugPrint('✅ [WashSession] Completion confirmed — signalling UI');
        _stopTimers();
        _isComplete = true;
        notifyListeners();
        return;
      }
    } else if (code == _statusIdle) {
      if (!_machineHasStarted) {
        debugPrint('⏳ [WashSession] Machine not started yet — waiting...');
      } else {
        debugPrint('⚠️ [WashSession] Machine stopped unexpectedly');
        _consecutiveErrors++;
      }
    } else if (code == _statusApiError) {
      debugPrint(
        '❌ [WashSession] API error — consecutive: ${_consecutiveErrors + 1}',
      );
      _consecutiveErrors++;
    } else {
      debugPrint('❓ [WashSession] Unknown code=$code — ignoring');
    }

    if (_machineHasStarted && _consecutiveErrors >= _maxErrors) {
      debugPrint('❌ [WashSession] Too many errors — clearing session');
      _stopTimers();
      await clearSession();
      return;
    }

    notifyListeners();
  }

  // ── Ping — now returns the response data ──────────────────────────
  Future<Map<String, dynamic>?> _sendPing() async {
    if (_hubDeviceId == null) return null;

    final int hubDeviceIdInt = int.tryParse(_hubDeviceId!) ?? 0;
    if (hubDeviceIdInt == 0) {
      debugPrint('⚠️ [WashSession] Ping skipped — invalid hubDeviceId');
      return null;
    }

    final int pingStatusCode = _machineHasStarted
        ? _lastKnownCode
        : _statusIdle;

    debugPrint(
      '📡 [WashSession] Sending ping → '
      'hubDeviceId=$hubDeviceIdInt  '
      'currentStatusCode=$pingStatusCode',
    );

    final result = await ApiService.devicePing(
      hubDeviceId: hubDeviceIdInt,
      currentStatusCode: pingStatusCode,
    );

    if (result.success) {
      debugPrint('✅ [WashSession] Ping success → ${result.data}');
      return result.data; // ✅ return data so _pollBackend can read action
    } else {
      debugPrint(
        '⚠️ [WashSession] Ping failed (non-critical): ${result.errorMessage}',
      );
      return null;
    }
  }

  // ── Fetch iotStatusCode from device details ───────────────────────
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

      final candidates = [
        responseData?['hubDevice']?['iotStatusCode'],
        responseData?['hubDevice']?['iotStatus'],
        responseData?['hubDevice']?['status'],
        responseData?['data']?['iotStatusCode'],
        responseData?['data']?['iotStatus'],
        responseData?['iotStatusCode'],
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

      debugPrint('⚠️ [WashSession] iotStatusCode not found — treating as idle');
      return _statusIdle;
    } catch (e) {
      debugPrint('❌ [WashSession] Exception fetching status: $e');
      return _statusApiError;
    }
  }

  // ── Persist ───────────────────────────────────────────────────────
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStartTime, _startTime!.toIso8601String());
    await prefs.setInt(_kDuration, _totalSeconds);
    await prefs.setString(_kHubId, _hubId!);
    await prefs.setString(_kHubDeviceId, _hubDeviceId ?? '');
    await prefs.setString(_kDeviceCode, _deviceCode ?? '');
    await prefs.setString(_kHubName, _hubName ?? '');
    await prefs.setString(_kPackageName, _packageName ?? '');
    await prefs.setDouble(_kAmountPaid, _amountPaid);
    await prefs.setString(_kPaymentId, _paymentId ?? '');
    debugPrint('💾 [WashSession] Session persisted to SharedPreferences');
  }
}
