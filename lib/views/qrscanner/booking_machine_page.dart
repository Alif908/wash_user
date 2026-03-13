// lib/views/qrscanner/booking_machine_page.dart

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  const _C._();
  static const Color bg = Color(0xFF0A0A0A);
  static const Color card = Color(0xFF1A1A1A);
  static const Color cyan = Color(0xFF00D4E8);
  static const Color green = Colors.greenAccent;
  static const Color red = Colors.redAccent;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class BookMachineScreen extends StatefulWidget {
  const BookMachineScreen({super.key, required this.device, required this.hub});

  final HubDeviceModel device;
  final HubModel hub;

  @override
  State<BookMachineScreen> createState() => _BookMachineScreenState();
}

class _BookMachineScreenState extends State<BookMachineScreen> {
  // ── Package state ─────────────────────────────────────────────────────
  List<HubPackageModel> _packages = [];
  bool _pkgLoading = true;
  String? _pkgError;
  int _selectedPkg = 0;

  // ── Coupon state ──────────────────────────────────────────────────────
  final TextEditingController _couponCtrl = TextEditingController();
  bool _couponLoading = false;
  String? _couponError;
  int _discountPct = 0;
  bool _couponApplied = false;

  // ── Order / payment state ─────────────────────────────────────────────
  bool _orderLoading = false;
  late Razorpay _razorpay;

  // ── Computed ──────────────────────────────────────────────────────────
  HubPackageModel? get _currentPkg =>
      _packages.isNotEmpty ? _packages[_selectedPkg] : null;

  double get _basePrice => _currentPkg?.price ?? 0.0;
  double get _finalPrice =>
      _discountPct > 0 ? _basePrice * (1 - _discountPct / 100) : _basePrice;
  double get _discount => _basePrice - _finalPrice;

  // ─────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initRazorpay();
    _fetchPackages();
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════╗');
    debugPrint('║     BOOK MACHINE SCREEN  →  OPENED       ║');
    debugPrint('╠══════════════════════════════════════════╣');
    debugPrint('║  Hub    → ${widget.hub.hubName}');
    debugPrint(
      '║  Device → ${widget.device.deviceCode} (id: ${widget.device.id})',
    );
    debugPrint('║  Status → ${widget.device.connectivityStatus}');
    debugPrint('╚══════════════════════════════════════════╝');
    debugPrint('');
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _razorpay.clear();
    debugPrint('   [BookMachine] Screen disposed');
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // API : FETCH PACKAGES  —  GET /api/user/packages
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _fetchPackages() async {
    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  PACKAGES  →  Fetching from API...       │');
    debugPrint('│  GET /api/user/packages                  │');
    debugPrint('└──────────────────────────────────────────┘');

    setState(() {
      _pkgLoading = true;
      _pkgError = null;
    });

    final result = await ApiService.getHubPackages();
    if (!mounted) return;

    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  PACKAGES  →  API Response               │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  success      → ${result.success}');
    debugPrint('│  errorMessage → ${result.errorMessage}');
    debugPrint('│  data keys    → ${result.data?.keys.toList()}');
    debugPrint('│  full data    → ${result.data}');
    debugPrint('└──────────────────────────────────────────┘');

    if (!result.success) {
      debugPrint('╔══════════════════════════════════════════╗');
      debugPrint('║  ❌ PACKAGES  →  API FAILED              ║');
      debugPrint('║  Error → ${result.errorMessage}');
      debugPrint('╚══════════════════════════════════════════╝');
      setState(() {
        _pkgError = result.errorMessage ?? 'Failed to load packages.';
        _pkgLoading = false;
      });
      return;
    }

    // Try every key the backend might use
    final dynamic rawPackages =
        result.data?['packages'] ??
        result.data?['data'] ??
        result.data?['hubPackages'] ??
        result.data?['items'] ??
        result.data?['results'] ??
        [];

    debugPrint('   [PACKAGES] type  → ${rawPackages.runtimeType}');
    debugPrint('   [PACKAGES] value → $rawPackages');

    if (rawPackages is! List) {
      debugPrint('╔══════════════════════════════════════════╗');
      debugPrint('║  ❌ PACKAGES  →  NOT a List!             ║');
      debugPrint('║  Got: ${rawPackages.runtimeType}         ║');
      debugPrint('╚══════════════════════════════════════════╝');
      setState(() {
        _pkgError = 'Unexpected packages format from server.';
        _pkgLoading = false;
      });
      return;
    }

    if (rawPackages.isEmpty) {
      debugPrint('   ⚠️  PACKAGES → Empty list returned from server');
      setState(() {
        _packages = [];
        _pkgLoading = false;
      });
      return;
    }

    final list = <HubPackageModel>[];
    for (int i = 0; i < rawPackages.length; i++) {
      try {
        final item = rawPackages[i];
        debugPrint('   [PACKAGE $i] raw → $item');
        final pkg = HubPackageModel.fromJson(item as Map<String, dynamic>);
        debugPrint(
          '   [PACKAGE $i] ✅ "${pkg.packageName}"  ₹${pkg.price}  status: ${pkg.statusCode}',
        );
        list.add(pkg);
      } catch (e) {
        debugPrint('   [PACKAGE $i] ❌ Parse error → $e');
      }
    }

    debugPrint('');
    debugPrint('   ✅ PACKAGES loaded: ${list.length}');
    debugPrint('');

    setState(() {
      _packages = list;
      _pkgLoading = false;
    });
  }

  // ─────────────────────────────────────────────────────────────────────
  // PULL-TO-REFRESH
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _refreshAll() async {
    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  PULL-TO-REFRESH  →  Triggered           │');
    debugPrint('└──────────────────────────────────────────┘');
    setState(() {
      _couponCtrl.clear();
      _discountPct = 0;
      _couponApplied = false;
      _couponError = null;
      _selectedPkg = 0;
    });
    await _fetchPackages();
    debugPrint('   [REFRESH] ✅ Done');
  }

  // ─────────────────────────────────────────────────────────────────────
  // COUPON
  // ─────────────────────────────────────────────────────────────────────

  void _applyCoupon() {
    final code = _couponCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    debugPrint('   [COUPON] Validating → "$code"');
    setState(() {
      _couponLoading = true;
      _couponError = null;
    });

    // Replace with real API call when backend supports coupon validation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      const demoCoupons = {'WASH10': 10, 'WASH20': 20, 'WELCOME': 15};
      final pct = demoCoupons[code];
      debugPrint(
        pct != null
            ? '   [COUPON] ✅ Valid — $pct% discount'
            : '   [COUPON] ❌ Invalid code',
      );
      setState(() {
        _couponLoading = false;
        if (pct != null) {
          _discountPct = pct;
          _couponApplied = true;
          _couponError = null;
        } else {
          _discountPct = 0;
          _couponApplied = false;
          _couponError = 'Invalid coupon code.';
        }
      });
    });
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
  // ORDER : CREATE + OPEN RAZORPAY  —  POST /api/user/create-order
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _onPayAndBook() async {
    if (_currentPkg == null) return;
    if (!widget.device.isOnline) {
      _showSnack(
        'Device is offline. Please try another device.',
        isError: true,
      );
      return;
    }

    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  ORDER  →  Creating...                   │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint(
      '│  Package    → ${_currentPkg!.packageName} (id: ${_currentPkg!.id})',
    );
    debugPrint('│  HubDevice  → ${widget.device.id}');
    debugPrint('│  Amount     → ₹${_finalPrice.toStringAsFixed(2)}');
    if (_couponApplied)
      debugPrint('│  Coupon     → ${_couponCtrl.text.trim().toUpperCase()}');
    debugPrint('└──────────────────────────────────────────┘');

    setState(() => _orderLoading = true);

    final orderData = <String, dynamic>{
      'packageId': _currentPkg!.id,
      'hubDeviceId': widget.device.id,
      if (_couponApplied && _couponCtrl.text.trim().isNotEmpty)
        'couponCode': _couponCtrl.text.trim().toUpperCase(),
    };

    final result = await ApiService.createOrder(orderData);
    if (!mounted) return;
    setState(() => _orderLoading = false);

    if (!result.success) {
      debugPrint('   [ORDER] ❌ Failed → ${result.errorMessage}');
      _showSnack(
        result.errorMessage ?? 'Order creation failed.',
        isError: true,
      );
      return;
    }

    // ── Full response dump ────────────────────────────────────────────
    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  ORDER RESPONSE  →  Full data dump       │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  Top-level keys → ${result.data?.keys.toList()}');
    debugPrint('│  Full data      → ${result.data}');
    final nestedOrder = result.data?['order'] as Map<String, dynamic>?;
    if (nestedOrder != null) {
      debugPrint('│  order keys     → ${nestedOrder.keys.toList()}');
      debugPrint('│  order data     → $nestedOrder');
    }
    debugPrint('└──────────────────────────────────────────┘');
    debugPrint('');

    // ── Extract razorpayOrderId ───────────────────────────────────────
    final String? razorpayOrderId =
        (result.data?['razorpayOrderId'] ??
                result.data?['order_id'] ??
                result.data?['orderId'] ??
                result.data?['id'] ??
                nestedOrder?['razorpayOrderId'] ??
                nestedOrder?['order_id'] ??
                nestedOrder?['id'])
            ?.toString();

    debugPrint('   [RAZORPAY] razorpayOrderId → $razorpayOrderId');

    if (razorpayOrderId == null || razorpayOrderId.isEmpty) {
      debugPrint('   [ORDER] ❌ razorpayOrderId is null');
      _showSnack('Order error: missing Razorpay order ID.', isError: true);
      return;
    }

    // ── Extract amount  (Razorpay needs int paise) ────────────────────
    final dynamic rawAmount =
        result.data?['amountPaise'] ??
        result.data?['amount_paise'] ??
        result.data?['amount'] ??
        result.data?['totalAmount'] ??
        result.data?['finalAmount'] ??
        result.data?['total'] ??
        nestedOrder?['amountPaise'] ??
        nestedOrder?['amount_paise'] ??
        nestedOrder?['amount'] ??
        nestedOrder?['totalAmount'] ??
        nestedOrder?['finalAmount'] ??
        nestedOrder?['total'];

    debugPrint(
      '   [RAZORPAY] rawAmount → $rawAmount  (${rawAmount?.runtimeType})',
    );

    if (rawAmount == null) {
      debugPrint('   [ORDER] ❌ amount is null');
      _showSnack('Order error: missing amount.', isError: true);
      return;
    }

    // >= 100  → already paise  e.g. 5000
    // <  100  → rupees × 100  e.g. 50.0 → 5000
    final double amountDouble = double.tryParse(rawAmount.toString()) ?? 0.0;
    final int amountPaise = amountDouble >= 100
        ? amountDouble.round()
        : (amountDouble * 100).round();

    debugPrint(
      '   [RAZORPAY] amountDouble=$amountDouble → amountPaise=$amountPaise',
    );

    // ── Extract Razorpay key ──────────────────────────────────────────
    final String? keyId =
        (result.data?['keyId'] ??
                result.data?['key'] ??
                result.data?['razorpayKeyId'] ??
                result.data?['razorpay_key_id'] ??
                result.data?['key_id'] ??
                nestedOrder?['keyId'] ??
                nestedOrder?['key'] ??
                nestedOrder?['key_id'])
            ?.toString();

    debugPrint('   [RAZORPAY] keyId → $keyId');

    // ── Open Razorpay checkout ────────────────────────────────────────
    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  RAZORPAY  →  Opening checkout           │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  order_id → $razorpayOrderId');
    debugPrint(
      '│  amount   → $amountPaise paise  (₹${(amountPaise / 100).toStringAsFixed(2)})',
    );
    debugPrint('│  key      → $keyId');
    debugPrint('└──────────────────────────────────────────┘');
    debugPrint('');

    try {
      _razorpay.open({
        'key': keyId ?? '',
        'amount': amountPaise,
        'order_id': razorpayOrderId,
        'name': widget.hub.hubName,
        'description': _currentPkg!.packageName,
        'prefill': {
          'contact': widget.hub.mobile ?? '',
          'email': widget.hub.email ?? '',
        },
        'retry': {'enabled': true, 'max_count': 3},
        'send_sms_hash': true,
        'remember_customer': false,
        'theme': {'color': '#00D4E8'},
      });
    } catch (e) {
      debugPrint('   [RAZORPAY] ❌ open() threw → $e');
      _showSnack('Could not open payment. $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // RAZORPAY LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    debugPrint('   [RAZORPAY] Initialized');
  }

  // POST /api/user/verify-payment
  void _onPaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  RAZORPAY  →  PAYMENT SUCCESS ✅         │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  paymentId → ${response.paymentId}');
    debugPrint('│  orderId   → ${response.orderId}');
    debugPrint('│  signature → ${response.signature}');
    debugPrint('└──────────────────────────────────────────┘');

    final result = await ApiService.verifyPayment({
      'razorpay_order_id': response.orderId,
      'razorpay_payment_id': response.paymentId,
      'razorpay_signature': response.signature,
    });

    if (!mounted) return;

    debugPrint('   [VERIFY] success → ${result.success}');
    debugPrint('   [VERIFY] data    → ${result.data}');
    debugPrint('   [VERIFY] error   → ${result.errorMessage}');

    if (result.success) {
      debugPrint('   ✅ Verification success — washing started!');
      _showSnack('Payment successful! Washing started 🚀');
      // TODO: Navigate to wash-progress screen
    } else {
      debugPrint('   ❌ Verification failed → ${result.errorMessage}');
      _showSnack(
        result.errorMessage ?? 'Payment verification failed.',
        isError: true,
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════╗');
    debugPrint('║  RAZORPAY  →  PAYMENT ERROR ❌           ║');
    debugPrint('╠══════════════════════════════════════════╣');
    debugPrint('║  code    → ${response.code}');
    debugPrint('║  message → ${response.message}');
    debugPrint('╚══════════════════════════════════════════╝');

    String msg;
    switch (response.code) {
      case Razorpay.PAYMENT_CANCELLED:
        msg = 'Payment cancelled.';
        break;
      case Razorpay.NETWORK_ERROR:
        msg = 'Network error. Check your internet and try again.';
        break;
      case Razorpay.INVALID_OPTIONS:
        msg = 'Payment config error. (INVALID_OPTIONS)';
        debugPrint('   ⚠️  INVALID_OPTIONS — check key or amount format');
        break;
      default:
        msg = response.message ?? 'Payment failed. Please try again.';
    }
    _showSnack(msg, isError: true);
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    debugPrint('   [RAZORPAY] External wallet → ${response.walletName}');
    _showSnack('External wallet: ${response.walletName}');
  }

  // ─────────────────────────────────────────────────────────────────────
  // HUB CONTACT  —  GET /api/user/hub/:hubId/contact
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _callHubOwner() async {
    debugPrint('   [CONTACT] hub id: ${widget.hub.id}');
    final result = await ApiService.getHubOwnerContact(
      widget.hub.id.toString(),
    );
    if (!mounted) return;
    if (result.success) {
      final mobile = result.data?['mobile'] ?? result.data?['contact'];
      debugPrint('   [CONTACT] ✅ $mobile');
      _showSnack(
        mobile != null ? 'Hub contact: $mobile' : 'Contact not available.',
      );
    } else {
      debugPrint('   [CONTACT] ❌ ${result.errorMessage}');
      _showSnack(
        result.errorMessage ?? 'Could not fetch contact.',
        isError: true,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // SNACKBAR
  // ─────────────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    debugPrint('   [SNACKBAR] ${isError ? "❌" : "✅"} "$msg"');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _C.red : _C.cyan,
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
          // ── Scrollable content + pull-to-refresh ──────────────────────
          RefreshIndicator(
            onRefresh: _refreshAll,
            color: _C.cyan,
            backgroundColor: _C.card,
            displacement: 50,
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

          // ── Sticky PAY button ─────────────────────────────────────────
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
                      (_orderLoading || _pkgLoading || _currentPkg == null)
                      ? null
                      : _onPayAndBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.cyan,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: _C.cyan.withOpacity(0.45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: _orderLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'PAY & BOOK WASHING',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
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
  // WIDGET : MACHINE CARD
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
          // Laundry icon box
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

          // Info column
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

                // Online / offline badge (outline only, no fill)
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
                      d.connectivityStatus,
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

          // Phone button
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
  // WIDGET : PACKAGE BUTTONS
  // Wrap layout — 3 per row, overflows to next row for 4+ packages
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildPackageButtons() {
    if (_pkgLoading) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(color: _C.cyan, strokeWidth: 2),
        ),
      );
    }

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

    if (_packages.isEmpty) {
      return const Text(
        'No packages available.',
        style: TextStyle(color: Colors.white54, fontSize: 13),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const int perRow = 3;
        const double gap = 10;
        final double chipW =
            (constraints.maxWidth - gap * (perRow - 1)) / perRow;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(_packages.length, (i) {
            final pkg = _packages[i];
            final isSelected = _selectedPkg == i;

            return GestureDetector(
              onTap: () {
                debugPrint(
                  '   [PACKAGE] Selected → "${pkg.packageName}" (₹${pkg.price})',
                );
                setState(() {
                  _selectedPkg = i;
                  _discountPct = 0;
                  _couponApplied = false;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: chipW,
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      pkg.packageName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
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
  // WIDGET : COUPON FIELD
  // ─────────────────────────────────────────────────────────────────────

  Widget _buildCouponField() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Icon(
            _couponApplied
                ? Icons.check_circle_outline
                : Icons.local_offer_outlined,
            color: _couponApplied ? Colors.green : Colors.black45,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _couponCtrl,
              enabled: !_couponApplied,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: _couponApplied
                    ? '${_couponCtrl.text}  (−$_discountPct%)'
                    : 'Enter Coupon Code',
                hintStyle: TextStyle(
                  color: _couponApplied
                      ? Colors.green.shade600
                      : Colors.black38,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                errorText: _couponError,
                errorStyle: const TextStyle(fontSize: 11, color: _C.red),
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // WIDGET : PAYMENT SUMMARY
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
