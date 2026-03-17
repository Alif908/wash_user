// lib/views/qrscanner/payment_success_page.dart

import 'package:flutter/material.dart';

class PaymentSuccessPage extends StatefulWidget {
  final String? amountPaid;
  final String? deviceCode;
  final String? paymentId;
  final VoidCallback? onGoHome;

  const PaymentSuccessPage({
    super.key,
    this.amountPaid,
    this.deviceCode,
    this.paymentId,
    this.onGoHome,
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

  void _goHome() {
    if (widget.onGoHome != null) {
      widget.onGoHome!();
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottomPad),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Animated Card ─────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Green checkmark circle ────────────────────
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
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── Order Details Card ────────────────────────
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white10,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Header
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF222222),
                                    borderRadius: BorderRadius.vertical(
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

                                // Amount Paid
                                _DetailRow(
                                  label: 'Amount Paid',
                                  value: widget.amountPaid != null
                                      ? '₹ ${widget.amountPaid}'
                                      : '₹ —',
                                  valueColor: Colors.white,
                                  showDivider: true,
                                ),

                                // Device
                                _DetailRow(
                                  label: 'Device',
                                  value: widget.deviceCode ?? '—',
                                  valueColor: Colors.white,
                                  showDivider: true,
                                ),

                                // Payment ID
                                if (widget.paymentId != null)
                                  _DetailRow(
                                    label: 'Payment ID',
                                    value: widget.paymentId!,
                                    valueColor: Colors.white70,
                                    showDivider: true,
                                    small: true,
                                  ),

                                // Status
                                _DetailRow(
                                  label: 'Status',
                                  value: 'COMPLETED',
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

                // ── Go to Home Button ─────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _goHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'GO TO HOME',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Detail Row ────────────────────────────────────────────────────────────────
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
