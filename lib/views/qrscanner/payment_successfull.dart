// lib/views/qrscanner/payment_successfull.dart

import 'package:flutter/material.dart';
import 'package:wash_user/services/washing_session.dart';
import 'package:wash_user/views/homepage/profile/washing_status.dart';

class PaymentSuccessPage extends StatefulWidget {
  final int amountPaid;
  final String deviceCode;
  final String? paymentId;
  final int durationMinutes;
  final String packageName;
  final String hubName;
  final String? hubId;
  final String? hubDeviceId;

  const PaymentSuccessPage({
    super.key,
    required this.amountPaid,
    required this.deviceCode,
    required this.durationMinutes,
    required this.packageName,
    required this.hubName,
    this.paymentId,
    this.hubId,
    this.hubDeviceId,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _checkAnim;

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _card = Color(0xFF1A1A1A);
  static const Color _cyan = Color(0xFF00D4E8);
  static const Color _green = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _checkAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  //=================================================================================================================================
  //=====================================================================================================================================

  void _goToWashing() async {
    // ✅ Step 1: check null
    if (widget.hubId == null || widget.hubDeviceId == null) {
      print("❌ hubId or hubDeviceId is NULL");

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Step 2: start session with REAL values
    await WashSessionManager.instance.startSession(
      durationMinutes: widget.durationMinutes,
      hubId: widget.hubId!, // ✅ FIXED
      hubDeviceId: widget.hubDeviceId!, // ✅ FIXED
      deviceCode: widget.deviceCode,
      hubName: widget.hubName,
      packageName: widget.packageName,
      amountPaid: widget.amountPaid.toDouble(),
      paymentId: widget.paymentId,
    );

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => WashingStatus(
          durationMinutes: widget.durationMinutes,
          amountPaid: widget.amountPaid.toDouble(),
          packageName: widget.packageName,
          deviceCode: widget.deviceCode,
          hubName: widget.hubName,
          paymentId: widget.paymentId,
          hubId: widget.hubId,
          hubDeviceId: widget.hubDeviceId,
        ),
      ),
      (route) => route.isFirst,
    );
  }
  // ── END OF CHANGE ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToWashing();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomPad),
                      child: Column(
                        children: [
                          const Spacer(flex: 2),

                          FadeTransition(
                            opacity: _fadeAnim,
                            child: ScaleTransition(
                              scale: _scaleAnim,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  36,
                                  24,
                                  28,
                                ),
                                decoration: BoxDecoration(
                                  color: _card,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ScaleTransition(
                                      scale: _checkAnim,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: const BoxDecoration(
                                          color: _green,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                          size: 46,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    const Text(
                                      'Payment Successful!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Your wash session is starting now.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.55),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF111111),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white10,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF222222),
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                    top: Radius.circular(12),
                                                  ),
                                            ),
                                            child: const Text(
                                              'Order Details',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          _DetailRow(
                                            label: 'Amount Paid',
                                            value: '₹ ${widget.amountPaid}',
                                            valueColor: Colors.white,
                                            showDivider: true,
                                          ),
                                          _DetailRow(
                                            label: 'Package',
                                            value: widget.packageName,
                                            valueColor: Colors.white,
                                            showDivider: true,
                                          ),
                                          _DetailRow(
                                            label: 'Duration',
                                            value:
                                                '${widget.durationMinutes} min',
                                            valueColor: Colors.white,
                                            showDivider: true,
                                          ),
                                          _DetailRow(
                                            label: 'Device',
                                            value: widget.deviceCode,
                                            valueColor: Colors.white,
                                            showDivider: true,
                                          ),
                                          if (widget.paymentId != null)
                                            _DetailRow(
                                              label: 'Payment ID',
                                              value: widget.paymentId!,
                                              valueColor: Colors.white70,
                                              showDivider: true,
                                              small: true,
                                            ),
                                          _DetailRow(
                                            label: 'Status',
                                            value: 'PAID',
                                            valueColor: _green,
                                            showDivider: false,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const Spacer(flex: 2),

                          FadeTransition(
                            opacity: _fadeAnim,
                            child: SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _goToWashing,
                                icon: const Icon(
                                  Icons.local_laundry_service_outlined,
                                  color: Colors.black,
                                  size: 20,
                                ),
                                label: const Text(
                                  'TRACK MY WASH',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    color: Colors.black,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _cyan,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Detail Row — completely unchanged ────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool showDivider;
  final bool small;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.showDivider,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: small ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: small ? 11 : 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            color: Colors.white10,
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }
}
