import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';
import 'package:wash_user/services/washing_session.dart';
import 'package:wash_user/views/home.dart';
import 'package:wash_user/views/wash_completed_screen.dart';

class WashingStatus extends StatefulWidget {
  final int? durationMinutes;
  final double? amountPaid;
  final String? packageName;
  final String? deviceCode;
  final String? hubName;
  final String? paymentId;
  final String? hubId;
  final String? hubDeviceId;

  const WashingStatus({
    super.key,
    this.durationMinutes,
    this.amountPaid,
    this.packageName,
    this.deviceCode,
    this.hubName,
    this.paymentId,
    this.hubId,
    this.hubDeviceId,
  });

  @override
  State<WashingStatus> createState() => _WashingStatusState();
}

class _WashingStatusState extends State<WashingStatus>
    with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  bool _navigated = false;
  String _statusText = 'Washing';

  late final VoidCallback _sessionListener;

  // ✅ FIX: increased from 30 s → 120 s to give machine enough time to ping
  static const int _machineWaitTimeoutSeconds = 120;
  int _waitingSeconds = 0;
  Timer? _waitingTimer;

  int get _remainingSeconds => WashSessionManager.instance.remainingSeconds;
  int get _displayMinutes => _remainingSeconds ~/ 60;
  int get _displaySeconds => _remainingSeconds % 60;
  double get _progress => WashSessionManager.instance.progress;

  @override
  void initState() {
    super.initState();

    // ✅ FIX: waiting timer properly checks machineStarted BEFORE incrementing
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final session = WashSessionManager.instance;

      // Machine started — stop waiting timer immediately
      if (session.machineStarted) {
        debugPrint('✅ Machine started — stopping waiting timer');
        timer.cancel();
        return;
      }

      setState(() => _waitingSeconds++);
      debugPrint('⏳ Waiting for machine... $_waitingSeconds sec');

      // ✅ FIX: 120 s timeout instead of 30 s
      if (_waitingSeconds > _machineWaitTimeoutSeconds) {
        timer.cancel();
        if (mounted && !_navigated) {
          _navigated = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Machine not responding. Please contact support.'),
            ),
          );
          _goHome();
        }
      }
    });

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sessionListener = () {
      if (!mounted) return;

      final session = WashSessionManager.instance;

      // Update status text
      setState(() {
        _statusText = session.machineStarted
            ? 'Washing'
            : 'Waiting for machine...';
      });

      // ── CASE A: Wash completed ─────────────────────────────────────
      if (session.isComplete && !_navigated) {
        _navigated = true;
        _spinController.stop();

        final String snapPackage =
            session.packageName ?? widget.packageName ?? '';
        final double snapAmount = session.amountPaid;
        final String snapDevice = session.deviceCode ?? widget.deviceCode ?? '';
        final String snapHub = session.hubName ?? widget.hubName ?? '';
        final String? snapPayment = session.paymentId ?? widget.paymentId;

        debugPrint('✅ [WashingStatus] Wash complete — navigating');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => WashCompletedScreen(
              packageName: snapPackage,
              amountPaid: snapAmount,
              deviceCode: snapDevice,
              hubName: snapHub,
              paymentId: snapPayment,
            ),
          ),
        ).then((_) {
          session.clearSession();
        });

        return;
      }

      // ── CASE B: Session cleared externally ────────────────────────
      if (!session.isActive && !_navigated) {
        _navigated = true;
        debugPrint('⚠️ Session cleared → going home');
        _goHome();
        return;
      }

      setState(() {});
    };

    WashSessionManager.instance.addListener(_sessionListener);
  }

  @override
  void dispose() {
    _waitingTimer?.cancel();
    WashSessionManager.instance.removeListener(_sessionListener);
    _spinController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const Homepage()),
    );
  }

  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          backgroundColor: const Color(0xFF00BCD4),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
            onPressed: _goHome,
            tooltip: 'Go Home',
          ),
          title: Text(
            _statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF00BCD4),
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [_buildTopSection(context), _buildBottomSection()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF00BCD4), Color(0xFF006978)],
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          _buildMachineIcon(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.local_laundry_service_outlined,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                _statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildRemainingTime(),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    label: 'Amount Paid',
                    value:
                        '₹ ${(widget.amountPaid ?? WashSessionManager.instance.amountPaid).toStringAsFixed(0)}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    label: 'Package',
                    value:
                        widget.packageName ??
                        WashSessionManager.instance.packageName ??
                        '-',
                    valueLarge: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildMachineIcon() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.5,
              ),
            ),
          ),
          RotationTransition(
            turns: _spinController,
            child: Container(
              width: 136,
              height: 136,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.35),
                  width: 2.5,
                ),
              ),
            ),
          ),
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF006978).withOpacity(0.55),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1,
              ),
            ),
          ),
          const Icon(
            Icons.local_laundry_service_outlined,
            size: 52,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildRemainingTime() {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        children: [
          const TextSpan(text: 'Remaining Time:  '),
          TextSpan(
            text: '$_displayMinutes',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' min '),
          TextSpan(
            text: _displaySeconds.toString().padLeft(2, '0'),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' sec'),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String? value,
    bool valueLarge = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.70),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value ?? '-',
            style: TextStyle(
              color: Colors.white,
              fontSize: valueLarge ? 17 : 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      width: double.infinity,
      color: Colors.grey[100],
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Washing Device',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Condition',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F7FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_laundry_service_outlined,
                        size: 26,
                        color: Color(0xFF00838F),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.hubName ??
                              WashSessionManager.instance.hubName ??
                              '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.deviceCode ??
                              WashSessionManager.instance.deviceCode ??
                              '-',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Text(
                  'Good',
                  style: TextStyle(
                    color: Color(0xFF00BCD4),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00BCD4).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF00838F),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Please do not remove your clothes until the timer completes.',
                    style: TextStyle(
                      color: Colors.teal[800],
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
