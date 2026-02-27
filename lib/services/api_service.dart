// lib/services/api_service.dart
// Covers all routes from userRoutes.js

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // ── Base URL ─────────────────────────────────────────────────────────
  // Your PC WiFi IP: 192.168.1.8  |  Port: 5000
  // Phone & PC must be on the SAME WiFi network
  static const String baseUrl = "http://192.168.1.3:5000/api/user";

  // ── Token Storage ─────────────────────────────────────────────────────
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

  // ── Headers ───────────────────────────────────────────────────────────
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
  // Body: { "phone": "+91XXXXXXXXXX" }
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
  // Body: { "phone": "+91XXXXXXXXXX", "otp": "1234" }
  // Response: { "token": "...", "user": { ... } }
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> verifyOtp(String phone, String otp) async {
    try {
      developer.log('── VERIFY OTP ────────────────────', name: 'ApiService');
      developer.log('URL  : $baseUrl/verify-otp', name: 'ApiService');
      developer.log(
        'BODY : ${jsonEncode({'mobile': phone, 'otp': otp})}',
        name: 'ApiService',
      );

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

      // Auto-save token + user data on success
      if (result.success) {
        if (result.data?['token'] != null) {
          await saveToken(result.data!['token']);
          developer.log('TOKEN : saved ✅', name: 'ApiService');
        }
        // Save user info for profile page
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
  // Body: { "latitude": 10.22, "longitude": 76.19 }
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
  // GET /api/user/hub/:hubId/devices/:hubdeviceId  [auth required]
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
  // Body: { "packageId": "...", "hubDeviceId": "..." }
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
  // Body: { "razorpay_order_id": "...", "razorpay_payment_id": "...", "razorpay_signature": "..." }
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
  // 10. SUBMIT FEEDBACK
  // POST /api/user/submit-feedback  [auth required]
  // Body: { "rating": 5, "comment": "Great service!" }
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> submitFeedback(
    Map<String, dynamic> feedbackData,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/submit-feedback'),
            headers: await _authHeaders,
            body: jsonEncode(feedbackData),
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
  // 11. GET WASH HISTORY
  // GET /api/user/wash-history  [auth required]
  // ─────────────────────────────────────────────────────────────────────
  static Future<ApiResult> getWashHistory() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/wash-history'), headers: await _authHeaders)
          .timeout(const Duration(seconds: 15));
      return _handleResponse(response);
    } on TimeoutException {
      return ApiResult.error('Request timed out.');
    } catch (e) {
      return ApiResult.error('Network error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // 12. GET WASH HISTORY BY ID
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
  // 13. GET HUB OWNER CONTACT
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

  // ── Response Handler ──────────────────────────────────────────────────
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

// ── ApiResult ─────────────────────────────────────────────────────────────
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
