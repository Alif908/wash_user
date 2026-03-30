// lib/views/washing/wash_completed_screen.dart
//
// Auto-navigated to from WashingStatus when the countdown hits zero.
// Back button is disabled — user must go to Home or Bookings.

import 'package:flutter/material.dart';
import 'package:wash_user/views/home.dart';

class WashCompletedScreen extends StatefulWidget {
  final String packageName;
  final double amountPaid;
  final String deviceCode;
  final String hubName;
  final String? paymentId;

  const WashCompletedScreen({
    super.key,
    required this.packageName,
    required this.amountPaid,
    required this.deviceCode,
    required this.hubName,
    this.paymentId,
  });

  @override
  State<WashCompletedScreen> createState() => _WashCompletedScreenState();
}

class _WashCompletedScreenState extends State<WashCompletedScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _checkAnim;

  static const Color _bg = Color(0xFF0A1628);
  static const Color _card = Color(0xFF112240);
  static const Color _cyan = Color(0xFF00BCD4);
  static const Color _green = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
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
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Homepage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
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

                // ── Animated card ─────────────────────────────────────────
                FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _cyan.withOpacity(0.18),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Green check
                          ScaleTransition(
                            scale: _checkAnim,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: _green.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: _green, width: 2.5),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: _green,
                                size: 50,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            'Wash Complete! 🎉',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your laundry is ready to collect.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Detail rows
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                              ),
                            ),
                            child: Column(
                              children: [
                                _row('Hub', widget.hubName),
                                _divider(),
                                _row('Device', widget.deviceCode),
                                _divider(),
                                _row('Package', widget.packageName),
                                _divider(),
                                _row(
                                  'Amount Paid',
                                  '₹ ${widget.amountPaid.toStringAsFixed(0)}',
                                  valueColor: _cyan,
                                ),
                                _divider(),
                                _row('Status', 'Completed', valueColor: _green),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Go Home button ────────────────────────────────────────
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

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(
    height: 1,
    color: Colors.white10,
    indent: 16,
    endIndent: 16,
  );
}
