import 'dart:async';
import 'package:flutter/material.dart';

import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';


class WashingStatus extends StatefulWidget {
  const WashingStatus({super.key});

  @override
  State<WashingStatus> createState() => _WashingStatusState();
}

class _WashingStatusState extends State<WashingStatus>
    with SingleTickerProviderStateMixin {
  // ── Timer state ──────────────────────────────────────────────────────
  int remainingMinutes = 0;
  int remainingSeconds = 0;
  Timer? _timer;
  late AnimationController _rotationController;

  // ── API state ────────────────────────────────────────────────────────
  WashHistoryModel? _activeWash;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _loadActiveWash();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rotationController.dispose();
    super.dispose();
  }

  // Load latest wash from history and compute remaining time
  Future<void> _loadActiveWash() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getWashHistory();

    if (!mounted) return;

    if (result.success) {
      final list = result.data?['washHistories'] ??
          result.data?['data'] ??
          result.data?['history'] ??
          [];

      final histories = (list as List)
          .map((e) => WashHistoryModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Most recent wash = last in list or sort by washStartTime
      if (histories.isNotEmpty) {
        histories.sort((a, b) => b.washStartTime.compareTo(a.washStartTime));
        final latest = histories.first;

        // Compute remaining time from washEndTime
        final now = DateTime.now();
        final remaining = latest.washEndTime.difference(now);

        setState(() {
          _activeWash = latest;
          _isLoading = false;

          if (remaining.isNegative) {
            remainingMinutes = 0;
            remainingSeconds = 0;
          } else {
            remainingMinutes = remaining.inMinutes;
            remainingSeconds = remaining.inSeconds % 60;
          }
        });

        // Start countdown only if wash is still active
        if (!remaining.isNegative) {
          _startTimer();
        }
      } else {
        setState(() {
          _isLoading = false;
          remainingMinutes = 0;
          remainingSeconds = 0;
        });
      }
    } else {
      setState(() {
        _error = result.errorMessage ?? 'Failed to load wash status';
        _isLoading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingSeconds > 0) {
          remainingSeconds--;
        } else if (remainingMinutes > 0) {
          remainingMinutes--;
          remainingSeconds = 59;
        } else {
          _timer?.cancel();
          _rotationController.stop();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
            )
          : Column(
              children: [
                // Top gradient section
                Expanded(
                  flex: 7,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF00BCD4),
                          Color(0xFF006064),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // App Bar
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: const [
                                Icon(
                                  Icons.arrow_back_ios,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Washing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Circular washing machine icon with ring
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 160,
                                height: 160,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 3,
                                  ),
                                ),
                              ),
                              RotationTransition(
                                turns: _rotationController,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.15),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.local_laundry_service_outlined,
                                size: 70,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Washing label
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.local_laundry_service_outlined,
                                color: Colors.white70,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Washing',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Remaining time
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              children: [
                                const TextSpan(text: 'Remaining Time:  '),
                                TextSpan(
                                  text: '$remainingMinutes ',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(text: 'mins '),
                                TextSpan(
                                  text: '$remainingSeconds ',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(text: 'sec'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Amount Paid & Package row
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Amount Paid card
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.35),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Amount Paid',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _activeWash != null
                                              ? '₹${_activeWash!.finalAmount.toStringAsFixed(0)}'
                                              : '₹',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Package card
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.35),
                                      borderRadius:
                                          BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      children: [
                                        const Text(
                                          'Package',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _activeWash?.packageName ??
                                              'Loading...',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom white section
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[100],
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Washing Device',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                            Text(
                              'Condition',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.local_laundry_service_outlined,
                                      size: 28,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Washer',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        _activeWash != null
                                            ? 'Device #${_activeWash!.deviceId}'
                                            : 'Device',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Text(
                                'Good',
                                style: TextStyle(
                                  color: Colors.cyan,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}