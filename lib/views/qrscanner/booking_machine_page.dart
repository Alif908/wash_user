// lib/views/qrscanner/booking_machine_page.dart

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';
import 'package:wash_user/views/home.dart';

import 'package:wash_user/views/qrscanner/payment_failed_page.dart';
import 'package:wash_user/views/qrscanner/payment_successfull.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  const _C._();
  static const Color bg = Color(0xFF0A0A0A);
  static const Color card = Color(0xFF1A1A1A);
  static const Color cyan = Color(0xFF00D4E8);
  static const Color green = Colors.greenAccent;
  static const Color red = Colors.redAccent;
}

const List<String> _kTimeLabels = ['5 min', '10 min', '20 min'];
const String _kRazorpayLiveKey = 'rzp_live_4UquzHIwrVUBE6';
const int _kPaymentTimeout = 600;

// ─────────────────────────────────────────────────────────────────────────────
class BookMachineScreen extends StatefulWidget {
  const BookMachineScreen({super.key, required this.device, required this.hub});
  final HubDeviceModel device;
  final HubModel hub;

  @override
  State<BookMachineScreen> createState() => _BookMachineScreenState();
}

class _BookMachineScreenState extends State<BookMachineScreen> {
  // ── Packages ──────────────────────────────────────────────────────────
  List<HubPackageModel> _packages = [];
  bool _pkgLoading = true;
  String? _pkgError;
  int _selectedPkg = 0;

  // ── Coupon ────────────────────────────────────────────────────────────
  final TextEditingController _couponCtrl = TextEditingController();
  bool _couponLoading = false;
  String? _couponError;
  int _discountPct = 0;
  bool _couponApplied = false;

  // ── Payment ───────────────────────────────────────────────────────────
  bool _isProcessing = false;
  String? _pendingOrderId;
  Map<String, dynamic>? _sessionData;
  late Razorpay _razorpay;

  // ── User info ─────────────────────────────────────────────────────────
  String _userMobile = '';
  String _userName = 'User';

  // ── Computed ──────────────────────────────────────────────────────────
  HubPackageModel? get _currentPkg =>
      _packages.isNotEmpty ? _packages[_selectedPkg] : null;

  double get _basePrice => _currentPkg?.price ?? 0.0;
  double get _finalPrice =>
      _discountPct > 0 ? _basePrice * (1 - _discountPct / 100) : _basePrice;
  double get _discount => _basePrice - _finalPrice;

  int get _selectedDurationMinutes {
    const durations = [5, 10, 20];
    if (_selectedPkg >= 0 && _selectedPkg < durations.length) {
      return durations[_selectedPkg];
    }
    return 5;
  }

  // ─────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _fetchPackages();
    _loadUserData();

    debugPrint('╔══════════════════════════════════════════════════╗');
    debugPrint('║        BOOK MACHINE SCREEN — OPENED              ║');
    debugPrint('║  Hub      → ${widget.hub.hubName}');
    debugPrint('║  Hub ID   → ${widget.hub.id}');
    debugPrint('║  Device   → ${widget.device.deviceCode}');
    debugPrint('║  Dev ID   → ${widget.device.id}');
    // FIXED: log iotStatusCode instead of raw connectivityStatus
    debugPrint(
      '║  IoT Status → ${widget.device.iotStatusCode} (${widget.device.iotStatusLabel})',
    );
    debugPrint('║  isOnline   → ${widget.device.isOnline}');
    debugPrint('╚══════════════════════════════════════════════════╝');
  }

  @override
  void dispose() {
    debugPrint('   [LIFECYCLE] BookMachineScreen disposed');
    _couponCtrl.dispose();
    try {
      _razorpay.clear();
    } catch (_) {}
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // USER DATA
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _loadUserData() async {
    debugPrint('   [USER] Loading from SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    final mobile = prefs.getString('user_mobile') ?? '';
    final name = prefs.getString('user_name') ?? 'User';
    debugPrint('   [USER] mobile = $mobile');
    debugPrint('   [USER] name   = $name');
    setState(() {
      _userMobile = mobile;
      _userName = name;
    });
    debugPrint('   [USER] Loaded ✅');
  }

  // ─────────────────────────────────────────────────────────────────────
  // RAZORPAY INIT
  // ─────────────────────────────────────────────────────────────────────

  void _initRazorpay() {
    debugPrint('   [RAZORPAY] Initializing...');
    try {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
      debugPrint('   [RAZORPAY] Initialized ✅');
    } catch (e) {
      debugPrint('   [RAZORPAY] ❌ Init error → $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorDialog(
          'Initialization Error',
          'Payment gateway initialization failed. Please restart the app.',
        );
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // RAZORPAY — SUCCESS
  // ─────────────────────────────────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════╗');
    debugPrint('║           PAYMENT SUCCESS CALLBACK               ║');
    debugPrint('╚══════════════════════════════════════════════════╝');
    debugPrint('   paymentId   → ${response.paymentId}');
    debugPrint('   orderId     → ${response.orderId}');
    debugPrint('   signature   → ${response.signature}');
    debugPrint('   _sessionData at callback → $_sessionData');

    if (_isProcessing) {
      debugPrint('   ⚠️ Already processing — ignoring duplicate callback');
      return;
    }
    setState(() => _isProcessing = true);
    debugPrint('   [STATE] _isProcessing = true');

    if (_sessionData == null) {
      debugPrint('   ❌ _sessionData is NULL — cannot verify payment!');
      if (mounted) {
        _showErrorDialog(
          'Booking Failed',
          'Session data missing. Please try booking again.',
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    try {
      final payload = {
        'razorpay_order_id': response.orderId,
        'razorpay_payment_id': response.paymentId,
        'razorpay_signature': response.signature,
        'sessionData': _sessionData,
      };

      debugPrint('');
      debugPrint('   ── Calling verifyPayment ──────────────────────');
      debugPrint('   Payload → $payload');

      final result = await ApiService.verifyPayment(payload);

      debugPrint('   [VERIFY] success      → ${result.success}');
      debugPrint('   [VERIFY] data         → ${result.data}');
      debugPrint('   [VERIFY] errorMessage → ${result.errorMessage}');

      if (!mounted) {
        debugPrint('   ⚠️ Widget unmounted after verifyPayment — aborting');
        return;
      }

      if (result.success) {
        debugPrint(
          '   ✅ Verification passed — navigating to PaymentSuccessPage',
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentSuccessPage(
              amountPaid: _finalPrice.round(),
              deviceCode: widget.device.deviceCode,
              paymentId: response.paymentId,
              durationMinutes: _selectedDurationMinutes,
              packageName: _currentPkg?.packageName ?? '—',
              hubName: widget.hub.hubName,
              hubId: widget.hub.id.toString(),
              hubDeviceId: widget.device.id.toString(), // ← ADD
            ),
          ),
          (route) => false,
        );
      } else {
        final errorMsg = result.errorMessage ?? 'Unknown error';
        debugPrint('   ❌ Verification failed → $errorMsg');

        if (_isActiveOrderError(errorMsg)) {
          _showActiveOrderConflictDialog(
            paymentId: response.paymentId ?? '',
            amountPaid: _finalPrice.round(),
          );
        } else {
          _showPaymentSuccessButBookingFailedDialog(
            errorMsg: errorMsg,
            paymentId: response.paymentId ?? '',
          );
        }
      }
    } catch (e, stack) {
      debugPrint('   ❌ Exception in _handlePaymentSuccess → $e');
      debugPrint('   Stack → $stack');
      if (mounted) {
        _showPaymentSuccessButBookingFailedDialog(
          errorMsg: e.toString().replaceFirst('Exception: ', ''),
          paymentId: response.paymentId ?? '',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        debugPrint('   [STATE] _isProcessing = false (finally)');
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Check if the error is the "active order" conflict
  // ─────────────────────────────────────────────────────────────────────
  bool _isActiveOrderError(String errorMsg) {
    final lower = errorMsg.toLowerCase();
    return lower.contains('active') ||
        lower.contains('active paid order') ||
        lower.contains('already has an active') ||
        lower.contains('pending order') ||
        lower.contains('existing order');
  }

  // ─────────────────────────────────────────────────────────────────────
  // Dialog shown when device has an active order conflict.
  // ─────────────────────────────────────────────────────────────────────
  void _showActiveOrderConflictDialog({
    required String paymentId,
    required int amountPaid,
  }) {
    debugPrint('   [DIALOG] Showing active order conflict dialog');
    debugPrint('   [DIALOG] paymentId=$paymentId  amountPaid=₹$amountPaid');
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 26,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Device Busy',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This machine already has an active wash session in progress.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your payment details:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₹$amountPaid charged',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (paymentId.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'ID: $paymentId',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '• Your payment will be refunded automatically within 5–7 business days.\n'
              '• Or try a different machine nearby.\n'
              '• Contact support with your Payment ID if not refunded.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('   [DIALOG] User chose: Try Another Machine');
              Navigator.of(context)
                ..pop()
                ..pop();
            },
            child: const Text(
              'Try Another',
              style: TextStyle(color: _C.cyan, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('   [DIALOG] User chose: Go Home');
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const Homepage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.cyan,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Go Home',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Generic dialog for "payment charged but booking failed"
  // ─────────────────────────────────────────────────────────────────────
  void _showPaymentSuccessButBookingFailedDialog({
    required String errorMsg,
    required String paymentId,
  }) {
    debugPrint('   [DIALOG] Showing payment-success-but-booking-failed dialog');
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Booking Failed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              errorMsg,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '⚠️ Your payment was received but the booking could not be confirmed. '
              'Please save your Payment ID and contact support. '
              'A refund will be issued within 5–7 business days.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            if (paymentId.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment ID',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      paymentId,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: _C.cyan, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Check if device has active order BEFORE creating order
  // FIXED: also checks iotStatusCode != 0 as an extra pre-flight guard
  // ─────────────────────────────────────────────────────────────────────
  Future<bool> _checkDeviceAvailability() async {
    debugPrint('   [CHECK] Checking device availability before payment...');
    try {
      final result = await ApiService.getHubDeviceDetails(
        widget.hub.id.toString(),
        widget.device.id.toString(),
      );

      debugPrint('   [CHECK] result.success → ${result.success}');
      debugPrint('   [CHECK] result.data    → ${result.data}');

      if (!result.success) {
        debugPrint('   [CHECK] ⚠️ Check failed — allowing payment to proceed');
        return true;
      }

      final data = result.data ?? {};

      // Re-parse the fresh device to get latest iotStatusCode
      final rawDevice =
          data['hubDevice'] ?? data['device'] ?? data['data'] ?? data;
      if (rawDevice is Map<String, dynamic>) {
        final freshDevice = HubDeviceModel.fromJson(rawDevice);
        debugPrint(
          '   [CHECK] fresh iotStatusCode → ${freshDevice.iotStatusCode} (${freshDevice.iotStatusLabel})',
        );
        // FIXED: block if iotStatusCode is anything other than 0 (IDLE)
        if (!freshDevice.isOnline) {
          debugPrint(
            '   [CHECK] ❌ Device not IDLE (iotStatusCode=${freshDevice.iotStatusCode}) — blocking payment',
          );
          return false;
        }
      }

      final hasActiveOrder =
          data['hasActiveOrder'] == true ||
          data['isOccupied'] == true ||
          data['status'] == 'occupied' ||
          data['activeOrderId'] != null;

      debugPrint('   [CHECK] hasActiveOrder → $hasActiveOrder');
      return !hasActiveOrder;
    } catch (e) {
      debugPrint('   [CHECK] ⚠️ Exception → $e — allowing payment to proceed');
      return true;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // RAZORPAY — ERROR
  // ─────────────────────────────────────────────────────────────────────

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════╗');
    debugPrint('║           PAYMENT ERROR CALLBACK                 ║');
    debugPrint('╚══════════════════════════════════════════════════╝');
    debugPrint('   code    → ${response.code}');
    debugPrint('   message → ${response.message}');

    if (!mounted || _isProcessing) {
      debugPrint('   ⚠️ Not mounted or already processing — skipping');
      return;
    }
    setState(() => _isProcessing = false);

    if (response.code == 0 ||
        response.message?.toLowerCase().contains('cancel') == true ||
        response.message?.toLowerCase().contains('user cancelled') == true ||
        response.code == Razorpay.PAYMENT_CANCELLED) {
      debugPrint('   ℹ️ Payment cancelled by user — showing snack');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment cancelled'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String msg = 'Payment failed. Please try again.';
    if (response.code == Razorpay.NETWORK_ERROR) {
      msg = 'Network error. Check your internet and try again.';
    } else if (response.code == Razorpay.INVALID_OPTIONS) {
      msg = 'Payment configuration error. Please contact support.';
    } else if (response.message != null && response.message!.isNotEmpty) {
      msg = response.message!;
    }

    debugPrint('   ❌ Real failure — navigating to PaymentFailedPage');
    debugPrint('   Reason → $msg');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentFailedPage(
          reason: msg,
          onRetry: () => Navigator.pop(context),
          onGoHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('   [RAZORPAY] External wallet → ${response.walletName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External wallet: ${response.walletName}')),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // MAIN PAYMENT FLOW
  // FIXED: isOnline check now reflects iotStatusCode == 0
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _processPayment() async {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════╗');
    debugPrint('║            PROCESS PAYMENT — START               ║');
    debugPrint('╚══════════════════════════════════════════════════╝');

    if (_isProcessing) {
      debugPrint('   ⚠️ Already in progress — ignoring tap');
      return;
    }
    if (_currentPkg == null) {
      debugPrint('   ⚠️ No package selected — aborting');
      return;
    }

    debugPrint(
      '   Package   → ${_currentPkg!.packageName} (id: ${_currentPkg!.id})',
    );
    debugPrint('   BasePrice → ₹$_basePrice');
    debugPrint('   Discount  → $_discountPct%  (₹$_discount)');
    debugPrint('   Final     → ₹$_finalPrice');
    debugPrint(
      '   Coupon    → applied=$_couponApplied  code=${_couponCtrl.text}',
    );
    // FIXED: log iotStatusCode and label
    debugPrint(
      '   IoT Status → ${widget.device.iotStatusCode} (${widget.device.iotStatusLabel})',
    );
    debugPrint('   isOnline   → ${widget.device.isOnline}');

    // FIXED: guard uses isOnline which is now iotStatusCode == 0
    if (!widget.device.isOnline) {
      debugPrint('   ❌ Device not IDLE — showing error');
      _showErrorDialog(
        'Machine Unavailable',
        'Machine is currently ${widget.device.iotStatusLabel}. Please try another machine.',
      );
      return;
    }

    setState(() => _isProcessing = true);
    debugPrint('   [STATE] _isProcessing = true');

    final isAvailable = await _checkDeviceAvailability();
    if (!isAvailable) {
      debugPrint('   ❌ Device not available — blocking payment');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog(
          'Machine Busy',
          'This machine is currently ${widget.device.iotStatusLabel}. '
              'Please try a different machine or wait for the current session to complete.',
        );
      }
      return;
    }

    BuildContext? dialogCtx;

    try {
      debugPrint('   Showing loading dialog...');
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            dialogCtx = ctx;
            return WillPopScope(
              onWillPop: () async => false,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: _C.card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(_C.cyan),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Creating payment order...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }

      final String? appliedCoupon =
          (_couponApplied && _couponCtrl.text.trim().isNotEmpty)
          ? _couponCtrl.text.trim().toUpperCase()
          : null;

      final orderData = <String, dynamic>{
        'packageId': _currentPkg!.id,
        'hubDeviceId': widget.device.id,
        if (appliedCoupon != null) 'couponCode': appliedCoupon,
      };

      debugPrint('');
      debugPrint('   ── Calling createOrder ────────────────────────');
      debugPrint('   Request body → $orderData');

      final result = await ApiService.createOrder(orderData);

      debugPrint('   [ORDER] success      → ${result.success}');
      debugPrint('   [ORDER] data         → ${result.data}');
      debugPrint('   [ORDER] errorMessage → ${result.errorMessage}');

      if (!result.success) {
        final errMsg = result.errorMessage ?? 'Failed to create payment order';
        if (_isActiveOrderError(errMsg)) {
          if (dialogCtx != null && mounted) Navigator.pop(dialogCtx!);
          if (mounted) {
            setState(() => _isProcessing = false);
            _showErrorDialog(
              'Machine Busy',
              'This machine already has an active wash session. '
                  'Please try a different machine.',
            );
          }
          return;
        }
        throw Exception(errMsg);
      }

      final data = result.data!;
      final nestedOrder = data['order'] as Map<String, dynamic>?;
      final sessionData = data['sessionData'] as Map<String, dynamic>?;

      if (sessionData != null && appliedCoupon != null) {
        _sessionData = Map<String, dynamic>.from(sessionData)
          ..['couponCode'] = appliedCoupon;
      } else {
        _sessionData = sessionData;
      }
      debugPrint('');
      debugPrint('   ── sessionData ────────────────────────────────');
      debugPrint('   raw sessionData      → $sessionData');
      debugPrint('   appliedCoupon        → $appliedCoupon');
      debugPrint('   _sessionData (final) → $_sessionData');

      final String? razorpayOrderId =
          (data['razorpayOrderId'] ??
                  data['order_id'] ??
                  data['orderId'] ??
                  data['id'] ??
                  nestedOrder?['razorpayOrderId'] ??
                  nestedOrder?['order_id'] ??
                  nestedOrder?['id'] ??
                  sessionData?['razorpayOrderId'])
              ?.toString();

      debugPrint('   razorpayOrderId → $razorpayOrderId');

      if (razorpayOrderId == null || razorpayOrderId.isEmpty) {
        throw Exception('Missing Razorpay order ID in response');
      }

      _pendingOrderId = razorpayOrderId;

      final dynamic rawAmount =
          data['amountPaise'] ??
          data['amount_paise'] ??
          data['amount'] ??
          data['totalAmount'] ??
          data['finalAmount'] ??
          nestedOrder?['amount'] ??
          sessionData?['amount'];

      debugPrint('   rawAmount → $rawAmount (${rawAmount.runtimeType})');

      if (rawAmount == null) {
        throw Exception('Missing amount in order response');
      }

      final double amountDouble = double.tryParse(rawAmount.toString()) ?? 0.0;
      final double chargeAmount = _finalPrice > 0 ? _finalPrice : amountDouble;
      final int amountPaise = (chargeAmount * 100).round();

      debugPrint('   amountDouble  → $amountDouble  (backend full price)');
      debugPrint('   _finalPrice   → $_finalPrice  (after coupon discount)');
      debugPrint('   chargeAmount  → $chargeAmount  (what Razorpay charges)');
      debugPrint('   amountPaise   → $amountPaise  (₹${amountPaise / 100})');

      if (amountPaise < 100) {
        throw Exception('Amount must be at least ₹1');
      }

      final String keyId =
          (data['keyId'] ??
                  data['key'] ??
                  data['razorpayKeyId'] ??
                  data['key_id'] ??
                  nestedOrder?['keyId'] ??
                  nestedOrder?['key'] ??
                  nestedOrder?['key_id'])
              ?.toString() ??
          _kRazorpayLiveKey;

      debugPrint('   keyId → $keyId');

      if (dialogCtx != null && mounted) {
        Navigator.pop(dialogCtx!);
        dialogCtx = null;
        debugPrint('   Loading dialog dismissed ✅');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() => _isProcessing = false);
        debugPrint('   [STATE] _isProcessing = false — opening Razorpay');
        _openRazorpayCheckout(
          keyId: keyId,
          orderId: razorpayOrderId,
          amountPaise: amountPaise,
        );
      }
    } catch (e, stack) {
      debugPrint('');
      debugPrint('   ❌ _processPayment EXCEPTION → $e');
      debugPrint('   Stack → $stack');

      if (dialogCtx != null && mounted) {
        Navigator.pop(dialogCtx!);
        debugPrint('   Loading dialog dismissed (error path)');
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog(
          'Payment Failed',
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // OPEN RAZORPAY CHECKOUT
  // ─────────────────────────────────────────────────────────────────────

  void _openRazorpayCheckout({
    required String keyId,
    required String orderId,
    required int amountPaise,
  }) {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════╗');
    debugPrint('║         OPENING RAZORPAY CHECKOUT                ║');
    debugPrint('╚══════════════════════════════════════════════════╝');
    debugPrint('   key         → $keyId');
    debugPrint('   order_id    → $orderId');
    debugPrint('   amountPaise → $amountPaise  (₹${amountPaise / 100})');
    debugPrint('   userName    → $_userName');
    debugPrint('   userMobile  → $_userMobile');

    try {
      final String rawMobile = _userMobile.isNotEmpty
          ? _userMobile
          : (widget.hub.mobile ?? '');
      final String contact = rawMobile.startsWith('+')
          ? rawMobile
          : rawMobile.isNotEmpty
          ? '+91$rawMobile'
          : '';

      final String email = 'user@wash.app';

      final options = {
        'key': keyId,
        'amount': amountPaise,
        'currency': 'INR',
        'order_id': orderId,
        'name': widget.hub.hubName,
        'description': _currentPkg?.packageName ?? 'Wash',
        'prefill': {'name': _userName, 'contact': contact, 'email': email},
        'theme': {'color': '#00D4E8'},
        'timeout': _kPaymentTimeout,
        'retry': {'enabled': true, 'max_count': 1},
      };

      debugPrint('   Full options → $options');
      _razorpay.open(options);
      debugPrint('   Razorpay.open() called ✅');
    } catch (e, stack) {
      debugPrint('   ❌ CRITICAL ERROR opening Razorpay → $e');
      debugPrint('   Stack → $stack');
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog(
          'Payment Gateway Error',
          'Could not open payment gateway. Please try again.',
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // ERROR DIALOG
  // ─────────────────────────────────────────────────────────────────────

  void _showErrorDialog(String title, String message) {
    debugPrint('   [DIALOG] $title → $message');
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('   [DIALOG] OK pressed');
              Navigator.pop(context);
            },
            child: const Text(
              'OK',
              style: TextStyle(color: _C.cyan, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // PACKAGES
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _fetchPackages() async {
    debugPrint('');
    debugPrint('   ── fetchPackages ──────────────────────────────');
    setState(() {
      _pkgLoading = true;
      _pkgError = null;
    });

    final result = await ApiService.getHubPackages();
    debugPrint('   [PACKAGES] success      → ${result.success}');
    debugPrint('   [PACKAGES] data         → ${result.data}');
    debugPrint('   [PACKAGES] errorMessage → ${result.errorMessage}');

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _pkgError = result.errorMessage ?? 'Failed to load packages.';
        _pkgLoading = false;
      });
      debugPrint('   [PACKAGES] ❌ $_pkgError');
      return;
    }

    final dynamic raw =
        result.data?['packages'] ??
        result.data?['data'] ??
        result.data?['hubPackages'] ??
        result.data?['items'] ??
        result.data?['results'] ??
        [];

    debugPrint('   [PACKAGES] raw type → ${raw.runtimeType}');
    debugPrint('   [PACKAGES] raw      → $raw');

    if (raw is! List) {
      setState(() {
        _pkgError = 'Unexpected package format from server.';
        _pkgLoading = false;
      });
      debugPrint('   [PACKAGES] ❌ Not a List');
      return;
    }

    final list = <HubPackageModel>[];
    for (int i = 0; i < raw.length; i++) {
      try {
        final pkg = HubPackageModel.fromJson(raw[i] as Map<String, dynamic>);
        debugPrint(
          '   [PKG $i] id=${pkg.id} | name=${pkg.packageName} | price=₹${pkg.price}',
        );
        list.add(pkg);
      } catch (e) {
        debugPrint('   [PKG $i] ❌ Parse error → $e');
      }
    }

    setState(() {
      _packages = list.take(3).toList();
      _pkgLoading = false;
    });
    debugPrint('   [PACKAGES] ✅ ${_packages.length} packages loaded');
  }

  Future<void> _refreshAll() async {
    debugPrint('   [REFRESH] Pull-to-refresh triggered');
    setState(() {
      _couponCtrl.clear();
      _discountPct = 0;
      _couponApplied = false;
      _couponError = null;
      _selectedPkg = 0;
    });
    await _fetchPackages();
  }

  // ─────────────────────────────────────────────────────────────────────
  // COUPON
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _applyCoupon() async {
    final code = _couponCtrl.text.trim().toUpperCase();

    debugPrint('');
    debugPrint('╔══════════════════════════════════════════════════╗');
    debugPrint('║              APPLY COUPON                        ║');
    debugPrint('╚══════════════════════════════════════════════════╝');
    debugPrint('   code entered → "$code"');

    if (code.isEmpty) {
      debugPrint('   ⚠️ Empty code — ignored');
      return;
    }

    setState(() {
      _couponLoading = true;
      _couponError = null;
    });

    try {
      debugPrint('   Calling ApiService.validateCoupon("$code")...');
      final result = await ApiService.validateCoupon(code, _basePrice);

      debugPrint('   [COUPON] success      → ${result.success}');
      debugPrint('   [COUPON] data         → ${result.data}');
      debugPrint('   [COUPON] errorMessage → ${result.errorMessage}');

      if (!mounted) return;

      if (result.success) {
        final dynamic rawPct =
            result.data?['discountPercentage'] ??
            result.data?['discount'] ??
            result.data?['discountPct'] ??
            result.data?['discount_percentage'] ??
            result.data?['coupon']?['discountPercentage'] ??
            result.data?['coupon']?['discount'];

        debugPrint('   [COUPON] rawPct → $rawPct (${rawPct?.runtimeType})');

        final int pct = rawPct != null
            ? (double.tryParse(rawPct.toString()) ?? 0.0).toInt()
            : 0;

        debugPrint('   [COUPON] parsed pct → $pct%');

        if (pct <= 0) {
          debugPrint('   [COUPON] ⚠️ Success but pct=0 — treating as invalid');
          setState(() {
            _couponLoading = false;
            _discountPct = 0;
            _couponApplied = false;
            _couponError = 'Coupon has no discount value.';
          });
          return;
        }

        setState(() {
          _couponLoading = false;
          _discountPct = pct;
          _couponApplied = true;
          _couponError = null;
        });
        debugPrint('   [COUPON] ✅ Applied $pct% discount');
      } else {
        final msg = result.errorMessage ?? 'Invalid coupon code.';
        debugPrint('   [COUPON] ❌ $msg');
        setState(() {
          _couponLoading = false;
          _discountPct = 0;
          _couponApplied = false;
          _couponError = msg;
        });
      }
    } catch (e, stack) {
      debugPrint('   [COUPON] ❌ Exception → $e');
      debugPrint('   Stack → $stack');
      if (mounted) {
        setState(() {
          _couponLoading = false;
          _discountPct = 0;
          _couponApplied = false;
          _couponError = 'Failed to validate coupon. Try again.';
        });
      }
    }
  }

  void _removeCoupon() {
    debugPrint('   [COUPON] Removed');
    setState(() {
      _couponCtrl.clear();
      _discountPct = 0;
      _couponApplied = false;
      _couponError = null;
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // HUB CONTACT
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _callHubOwner() async {
    debugPrint('   [CONTACT] hubId=${widget.hub.id}');
    final result = await ApiService.getHubOwnerContact(
      widget.hub.id.toString(),
    );
    debugPrint('   [CONTACT] success → ${result.success}');
    debugPrint('   [CONTACT] data    → ${result.data}');
    if (!mounted) return;
    final mobile = result.success
        ? (result.data?['mobile'] ?? result.data?['contact'])
        : null;
    debugPrint('   [CONTACT] mobile resolved → $mobile');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mobile != null
              ? 'Hub contact: $mobile'
              : (result.errorMessage ?? 'Not available'),
        ),
        backgroundColor: result.success ? _C.cyan : _C.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Book Machine',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            color: _C.cyan,
            backgroundColor: _C.card,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: 110 + bottomPad),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildMachineCard(),
                    const SizedBox(height: 28),
                    const Text(
                      'Select Washing Time',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildPackageButtons(),
                    const SizedBox(height: 28),
                    _buildCouponField(),
                    const SizedBox(height: 24),
                    if (!_pkgLoading && _currentPkg != null)
                      _buildPaymentSummary(),
                  ],
                ),
              ),
            ),
          ),

          // ── Sticky PAY button ─────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: _C.bg,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottomPad),
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      (_isProcessing || _pkgLoading || _currentPkg == null)
                      ? null
                      : _processPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.cyan,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: _C.cyan.withOpacity(0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Pay ₹${_finalPrice.toStringAsFixed(0)} & Book',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // MACHINE CARD
  // FIXED: badge uses iotStatusLabel, color uses isOnline
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildMachineCard() {
    final d = widget.device;
    final h = widget.hub;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_laundry_service,
              color: Colors.black,
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.hubName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                // FIXED: badge label from iotStatusLabel, color from isOnline
                IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: d.isOnline ? _C.green : _C.red,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      d.iotStatusLabel,
                      style: TextStyle(
                        color: d.isOnline ? _C.green : _C.red,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _infoRow('Device', d.deviceName ?? d.deviceCode, bold: false),
                _infoRow('Device ID', d.deviceCode, bold: true),
                _infoRow(
                  'Condition',
                  d.condition ?? (d.isActive ? 'Good' : 'Inactive'),
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _callHubOwner,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                border: Border.all(color: _C.cyan, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.phone_outlined, color: _C.cyan, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {required bool bold}) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          height: 1.5,
        ),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: value,
            style: TextStyle(
              color: bold ? Colors.white : Colors.white70,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // PACKAGE BUTTONS
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildPackageButtons() {
    if (_pkgLoading)
      return const SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(color: _C.cyan, strokeWidth: 2),
        ),
      );
    if (_pkgError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _pkgError!,
              style: const TextStyle(color: _C.red, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _fetchPackages,
            child: const Text('Retry', style: TextStyle(color: _C.cyan)),
          ),
        ],
      );
    }
    if (_packages.isEmpty)
      return const Text(
        'No packages available.',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      );

    return LayoutBuilder(
      builder: (context, constraints) {
        const int perRow = 3;
        const double gap = 10;
        final double chipW =
            (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Row(
          children: List.generate(3, (i) {
            final bool hasPackage = i < _packages.length;
            final bool isSelected = hasPackage && _selectedPkg == i;
            return GestureDetector(
              onTap: hasPackage
                  ? () {
                      debugPrint(
                        '   [PKG] Selected index=$i → ${_packages[i].packageName}',
                      );
                      setState(() {
                        _selectedPkg = i;
                        _discountPct = 0;
                        _couponApplied = false;
                      });
                    }
                  : null,
              child: Container(
                width: chipW,
                height: 50,
                margin: EdgeInsets.only(right: i < 2 ? gap : 0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : hasPackage
                      ? Colors.transparent
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: hasPackage ? Colors.white : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _kTimeLabels[i],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.black
                          : hasPackage
                          ? Colors.white
                          : Colors.white30,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // COUPON FIELD
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildCouponField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 54,
          decoration: BoxDecoration(
            color: _couponApplied ? Colors.green.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: _couponApplied
                ? Border.all(color: Colors.green.shade300, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                _couponApplied
                    ? Icons.check_circle
                    : Icons.local_offer_outlined,
                color: _couponApplied ? Colors.green : Colors.black45,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _couponApplied
                    ? Text(
                        '${_couponCtrl.text}  −$_discountPct%',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : TextField(
                        controller: _couponCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Enter Coupon Code',
                          hintStyle: TextStyle(
                            color: Colors.black38,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
              ),
              if (_couponLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black38,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: _couponApplied ? _removeCoupon : _applyCoupon,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      _couponApplied ? 'Remove' : 'Apply Coupon',
                      style: TextStyle(
                        color: _couponApplied
                            ? Colors.red.shade400
                            : Colors.black38,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_couponError != null && !_couponApplied)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Text(
              _couponError!,
              style: const TextStyle(fontSize: 11, color: _C.red),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // PAYMENT SUMMARY
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildPaymentSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Summary',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _summaryRow(
                'Estimated Cost',
                '₹${_basePrice.toStringAsFixed(2)}',
              ),
              if (_discountPct > 0) ...[
                const SizedBox(height: 10),
                _summaryRow(
                  'Coupon Discount (−$_discountPct%)',
                  '−₹${_discount.toStringAsFixed(2)}',
                  valueColor: Colors.greenAccent,
                ),
              ],
              const SizedBox(height: 10),
              _summaryRow('Platform Fee', 'N/A'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white24, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Payable Amount',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '₹${_finalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(color: valueColor ?? Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}
