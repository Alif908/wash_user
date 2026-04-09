// lib/services/api_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ── Base URL ───────────────────────────────────────────────────────────
  static const String baseUrl = "https://be.washist.com/api/user";

  // ── Token Storage ──────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // ── Headers ────────────────────────────────────────────────────────────
  static Map<String, String> get _jsonHeaders => {
    'Content-Type': 'application/json',
  };

  static Future<Map<String, String>> get _authHeaders async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ─────────────────────────────────────────────────────────────────────
  // 1. SEND OTP
  // POST /api/user/send-otp
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> sendOtp(String phone) async {
    try {
      developer.log('── SEND OTP ──────────────────────', name: 'ApiService');
      developer.log('URL  : $baseUrl/send-otp', name: 'ApiService');
      developer.log(
        'BODY : ${jsonEncode({'mobile': phone, 'name': 'User'})}',
        name: 'ApiService',
      );

      final response = await http
          .post(
            Uri.parse('$baseUrl/send-otp'),
            headers: _jsonHeaders,
            body: jsonEncode({'mobile': phone, 'name': 'User'}),
          )
          .timeout(const Duration(seconds: 15));

      developer.log('STATUS : ${response.statusCode}', name: 'ApiService');
      developer.log('BODY   : ${response.body}', name: 'ApiService');
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out. Check your network.');
    } catch (e) {
      developer.log('ERROR : $e', name: 'ApiService', error: e);
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 2. VERIFY OTP
  // POST /api/user/verify-otp
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> verifyOtp(String phone, String otp) async {
    try {
      developer.log('── VERIFY OTP ────────────────────', name: 'ApiService');
      developer.log('URL  : $baseUrl/verify-otp', name: 'ApiService');

      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-otp'),
            headers: _jsonHeaders,
            body: jsonEncode({'mobile': phone, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));

      developer.log('STATUS : ${response.statusCode}', name: 'ApiService');
      developer.log('BODY   : ${response.body}', name: 'ApiService');

      final result = _handleResponse(response);

      if (result.success) {
        if (result.data?['token'] != null) {
          await saveToken(result.data!['token']);
          developer.log('TOKEN : saved ✅', name: 'ApiService');
        }
        final prefs = await SharedPreferences.getInstance();
        final user = result.data?['user'];
        if (user != null) {
          await prefs.setString(
            'user_name',
            user['name']?.toString() ?? 'User',
          );
          await prefs.setString(
            'user_mobile',
            user['mobile']?.toString() ?? '',
          );
          await prefs.setString('user_id', user['id']?.toString() ?? '');
          developer.log(
            'USER  : saved ✅ ${user['mobile']}',
            name: 'ApiService',
          );
        }
      }

      return result;
    } on TimeoutException {
      return ApiResult.error('Request timed out. Check your network.');
    } catch (e) {
      developer.log('ERROR : $e', name: 'ApiService', error: e);
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 3. UPDATE LOCATION
  // POST /api/user/update-location  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> updateLocation(double lat, double lng) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/update-location'),
            headers: await _authHeaders,
            body: jsonEncode({'latitude': lat, 'longitude': lng}),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 4. GET NEAREST HUBS
  // GET /api/user/nearest-hubs  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getNearestHubs() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/nearest-hubs'), headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 5. GET DEVICES OF HUB
  // GET /api/user/hub/:hubId/devices  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getDevicesOfHub(String hubId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/hub/$hubId/devices'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 6. GET HUB DEVICE DETAILS
  // GET /api/user/hub/:hubId/devices/:hubDeviceId  [auth required]
  // Used by WashSessionManager every 10 s to read iotStatusCode
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getHubDeviceDetails(
    String hubId,
    String hubDeviceId,
  ) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/hub/$hubId/devices/$hubDeviceId'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 7. GET HUB PACKAGES
  // GET /api/user/packages  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getHubPackages() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/packages'), headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 8. CREATE ORDER
  // POST /api/user/create-order  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/create-order'),
            headers: await _authHeaders,
            body: jsonEncode(orderData),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 9. VERIFY PAYMENT
  // POST /api/user/verify-payment  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> verifyPayment(
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-payment'),
            headers: await _authHeaders,
            body: jsonEncode(paymentData),
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 10. VALIDATE COUPON
  // POST /api/coupon/verify-coupon  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> validateCoupon(
    String couponCode,
    double amount,
  ) async {
    const couponBaseUrl = "https://be.washist.com/api/coupon";
    try {
      developer.log('── VALIDATE COUPON ───────────────', name: 'ApiService');

      final response = await http
          .post(
            Uri.parse('$couponBaseUrl/verify-coupon'),
            headers: await _authHeaders,
            body: jsonEncode({'couponCode': couponCode, 'amount': amount}),
          )
          .timeout(const Duration(seconds: 15));

      developer.log('STATUS : ${response.statusCode}', name: 'ApiService');
      developer.log('BODY   : ${response.body}', name: 'ApiService');
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      developer.log('ERROR : $e', name: 'ApiService', error: e);
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 11. SUBMIT FEEDBACK
  // POST /api/user/submit-feedback  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> submitFeedback(
    Map<String, dynamic> feedbackData,
  ) async {
    try {
      developer.log('── SUBMIT FEEDBACK ───────────────', name: 'ApiService');
      developer.log('BODY : ${jsonEncode(feedbackData)}', name: 'ApiService');

      final response = await http
          .post(
            Uri.parse('$baseUrl/submit-feedback'),
            headers: await _authHeaders,
            body: jsonEncode(feedbackData),
          )
          .timeout(const Duration(seconds: 15));

      developer.log('STATUS : ${response.statusCode}', name: 'ApiService');
      developer.log('BODY   : ${response.body}', name: 'ApiService');
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 12. GET WASH HISTORY
  // GET /api/user/wash-history  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getWashHistory() async {
    try {
      developer.log('── GET WASH HISTORY ──────────────', name: 'ApiService');

      final response = await http
          .get(Uri.parse('$baseUrl/wash-history'), headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));

      developer.log('STATUS : ${response.statusCode}', name: 'ApiService');
      developer.log('BODY   : ${response.body}', name: 'ApiService');
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 13. GET WASH HISTORY BY ID
  // GET /api/user/wash-history/:washHistoryId  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getWashHistoryById(String washHistoryId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/wash-history/$washHistoryId'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 14. GET HUB OWNER CONTACT
  // GET /api/user/hub/:hubId/contact  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getHubOwnerContact(String hubId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/hub/$hubId/contact'),
            headers: await _authHeaders,
          )
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 15. GET ACTIVE WASH
  // GET /api/user/active-wash  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getActiveWash() async {
    try {
      developer.log('── GET ACTIVE WASH ───────────────', name: 'ApiService');

      final response = await http
          .get(Uri.parse('$baseUrl/active-wash'), headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));

      developer.log('STATUS : ${response.statusCode}', name: 'ApiService');
      developer.log('BODY   : ${response.body}', name: 'ApiService');

      // HTML 404 guard — route not deployed yet
      if (response.statusCode == 404) {
        final body = response.body.trim();
        if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
          developer.log(
            'WARN  : /active-wash not on server yet — returning idle',
            name: 'ApiService',
          );
          return ApiResult.success({'activeOrder': null});
        }
      }

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      developer.log('ERROR : $e', name: 'ApiService', error: e);
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 16. CREATE SERVICE TICKET
  // POST /api/user/service-ticket  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<void> createServiceTicket({
    required String deviceId,
    required String issue,
    String? bookingId,
  }) async {
    try {
      developer.log('── CREATE SERVICE TICKET ─────────', name: 'ApiService');

      final response = await http
          .post(
            Uri.parse('$baseUrl/service-ticket'),
            headers: await _authHeaders,
            body: jsonEncode({
              'deviceId': deviceId,
              'issue': issue,
              if (bookingId != null) 'bookingId': bookingId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      developer.log('STATUS : ${response.statusCode}', name: 'ApiService');
      developer.log('BODY   : ${response.body}', name: 'ApiService');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to create service ticket: ${response.statusCode}',
        );
      }
    } on TimeoutException {
      throw Exception('Request timed out.');
    } catch (e) {
      developer.log('ERROR : $e', name: 'ApiService', error: e);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 17. DEVICE PING (IoT)
  // POST /api/device/ping  [NO AUTH]
  // ✅ FIXED: uses /api/device base, NOT /api/user
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> devicePing({
    required int hubDeviceId,
    required int currentStatusCode,
  }) async {
    // ✅ Separate base URL — ping goes to /api/device, not /api/user
    const String deviceBaseUrl = "https://be.washist.com/api/device";
    try {
      developer.log('── DEVICE PING ───────────────', name: 'ApiService');
      developer.log('URL  : $deviceBaseUrl/ping', name: 'ApiService');
      developer.log(
        'BODY : hubDeviceId=$hubDeviceId  currentStatusCode=$currentStatusCode',
        name: 'ApiService',
      );

      final response = await http
          .post(
            Uri.parse('$deviceBaseUrl/ping'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'hubDeviceId': hubDeviceId,
              'currentStatusCode': currentStatusCode,
            }),
          )
          .timeout(const Duration(seconds: 10));

      developer.log('STATUS : ${response.statusCode}', name: 'ApiService');
      developer.log('BODY   : ${response.body}', name: 'ApiService');

      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Ping timed out.');
    } catch (e) {
      developer.log('ERROR : $e', name: 'ApiService', error: e);
      return ApiResult.error('Ping network error: $e');
    }
  }

  // ── Response Handler ───────────────────────────────────────────────────
  static ApiResult _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      decoded = {'message': response.body};
    }

    final Map<String, dynamic> body = decoded is Map<String, dynamic>
        ? decoded
        : {'data': decoded};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResult.success(body);
    } else if (response.statusCode == 401) {
      return ApiResult.error('Session expired. Please login again.');
    } else if (response.statusCode == 404) {
      return ApiResult.error('Resource not found.');
    } else if (response.statusCode >= 500) {
      return ApiResult.error('Server error. Please try again later.');
    } else {
      final message = body['message'] as String? ?? 'Something went wrong.';
      return ApiResult.error(message);
    }
  }
}

// ── ApiResult ──────────────────────────────────────────────────────────────
class ApiResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? errorMessage;

  const ApiResult._({required this.success, this.data, this.errorMessage});

  factory ApiResult.success(Map<String, dynamic> data) =>
      ApiResult._(success: true, data: data);

  factory ApiResult.error(String message) =>
      ApiResult._(success: false, errorMessage: message);
}
