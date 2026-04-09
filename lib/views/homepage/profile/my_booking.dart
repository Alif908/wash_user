// lib/views/homepage/profile/my_booking.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  List<WashHistoryModel> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ApiService.getWashHistory();
    if (!mounted) return;

    if (result.success) {
      // ── FIX: log raw keys so you can see exactly what backend returns ──
      debugPrint('[MyBookings] raw response keys: ${result.data?.keys}');
      debugPrint('[MyBookings] raw response: ${result.data}');

      // ── FIX: try every possible wrapper key including Sequelize 'rows' ──
      final dynamic rawList =
          result.data?['washHistories'] ??
          result.data?['washes'] ??
          result.data?['rows'] ?? // Sequelize findAndCountAll uses 'rows'
          result.data?['data'] ??
          result.data?['history'] ??
          [];

      final List<WashHistoryModel> parsed = [];
      for (int i = 0; i < (rawList as List).length; i++) {
        try {
          parsed.add(
            WashHistoryModel.fromJson(rawList[i] as Map<String, dynamic>),
          );
        } catch (e) {
          debugPrint('[MyBookings] parse error at index $i: $e');
        }
      }

      parsed.sort((a, b) => b.washStartTime.compareTo(a.washStartTime));

      setState(() {
        _bookings = parsed;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result.errorMessage ?? 'Failed to load bookings';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'My Bookings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "Previous Bookings" tab ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Previous Bookings',
                  style: TextStyle(
                    color: Color(0xFF29B6F6),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: double.infinity,
                  color: const Color(0xFF29B6F6),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Content ──────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF29B6F6)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBookings,
                    color: const Color(0xFF29B6F6),
                    child: _error != null
                        ? CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _error!,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      TextButton(
                                        onPressed: _loadBookings,
                                        child: const Text(
                                          'Retry',
                                          style: TextStyle(
                                            color: Color(0xFF29B6F6),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _bookings.isEmpty
                        ? CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              SliverFillRemaining(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_laundry_service_outlined,
                                        color: Colors.white24,
                                        size: 64,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No Bookings Found',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: _bookings.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 16),
                            itemBuilder: (context, index) =>
                                _BookingCard(booking: _bookings[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING CARD
// ─────────────────────────────────────────────────────────────────────────────
class _BookingCard extends StatefulWidget {
  final WashHistoryModel booking;
  const _BookingCard({required this.booking});

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  int _starRating = 0;

  static const Color _cyan = Color(0xFF29B6F6);
  static const Color _cardBg = Color(0xFF1A1A1A);
  static const Color _rowBg = Color(0xFF222222);
  static const Color _labelClr = Color(0xFF9E9E9E);
  static const Color _valueClr = Colors.white;
  static const Color _discClr = Color(0xFF29B6F6);

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final bool isCompleted = b.isCompleted;

    final double basePrice = b.amount;
    final double discountAmt = basePrice - b.finalAmount;
    final bool hasDiscount = discountAmt > 0;
    final String machineName = b.deviceName ?? b.deviceCode ?? '—';
    final String deviceId = b.deviceCode ?? '—';

    final String bookingTime = _formatTime(b.washStartTime);
    final String bookingDate = _formatDateShort(b.washStartTime);

    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: Hub name + View More ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.hubName ?? 'Hub',
                      style: const TextStyle(
                        color: _valueClr,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      b.razorpayOrderId.isNotEmpty ? b.razorpayOrderId : '—',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Text(
                        'View More',
                        style: TextStyle(
                          color: _cyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right, color: _cyan, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Package badge ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_laundry_service_outlined,
                    color: Colors.white60,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    b.packageName.isNotEmpty ? b.packageName : '—',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Detail rows ──────────────────────────────────────────────
          _detailRow('Device ID', deviceId),
          _detailRow('Machine', machineName),
          _detailRow('Power', '1000 W'),
          _detailRow('Price', '₹ ${basePrice.toStringAsFixed(2)}'),
          _detailRow('Platform Fee', '₹ 0'),
          if (hasDiscount)
            _detailRow(
              'Flat Discount',
              '-₹ ${discountAmt.toStringAsFixed(2)}',
              labelColor: _cyan,
              valueColor: _discClr,
              isBold: true,
            ),
          _detailRow('Amount Paid', '₹ ${b.finalAmount.toStringAsFixed(0)}'),

          const SizedBox(height: 12),

          // ── Booking ID / Date / Time row ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: _rowBg,
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Row(
                children: [
                  _infoCol('Booking ID', '${b.orderId}'),
                  _vertDivider(),
                  _infoCol('Booking Date', bookingDate),
                  _vertDivider(),
                  _infoCol('Booking Time', bookingTime),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── Star rating + Add a review ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setState(() => _starRating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          i < _starRating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: i < _starRating
                              ? Colors.amber
                              : Colors.white38,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
                GestureDetector(
                  onTap: () => _showReviewDialog(context, b),
                  child: const Text(
                    'Add a review',
                    style: TextStyle(
                      color: _cyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Need Help + Locate buttons ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showHelpDialog(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Need Help?',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openLocation(b),
                    icon: const Icon(
                      Icons.near_me,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Locate',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _cyan,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  // ── Detail row widget ────────────────────────────────────────────────────
  Widget _detailRow(
    String label,
    String value, {
    Color? labelColor,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: labelColor ?? _labelClr,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const Text(
            '  :  ',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? _valueClr,
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Booking info column (ID / Date / Time) ───────────────────────────────
  Widget _infoCol(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: Colors.white12,
  );

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatDateShort(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour = d.hour > 12 ? d.hour - 12 : (d.hour == 0 ? 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour >= 12 ? 'pm' : 'am';
    return '$hour:$minute $period';
  }

  // ── Action handlers ──────────────────────────────────────────────────────

  void _openLocation(WashHistoryModel b) async {
  final address = b.hubName ?? 'laundry';
  final query = Uri.encodeComponent(address);
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$query',
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open Google Maps'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Need Help?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Please contact our support team for any issues with your booking.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF29B6F6)),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewDialog(BuildContext context, WashHistoryModel b) {
    final ctrl = TextEditingController();

    // ── FIX: local dialog rating so stars update inside the dialog ────
    // dialogRating is owned by StatefulBuilder — separate from _starRating
    // on the card. Both stay in sync on tap.
    int dialogRating = _starRating;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        // ── FIX: StatefulBuilder gives us setDialogState so the
        //         star row inside the dialog actually rebuilds on tap ──
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add a Review',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stars inside dialog — now reactive
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() => dialogRating = i + 1); // dialog
                      setState(() => _starRating = i + 1); // card
                    },
                    child: Icon(
                      i < dialogRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: i < dialogRating ? Colors.amber : Colors.white38,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Write your review...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Close dialog first so the user isn't waiting with it open
                Navigator.pop(context);

                // ── FIX: actually call the feedback API ───────────────
                final res = await ApiService.submitFeedback({
                  'orderId': b.orderId,
                  'hubId': b.hubId,
                  'deviceId': b.deviceId,
                  'rating': dialogRating,
                  'comment': ctrl.text.trim(),
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      res.success
                          ? 'Review submitted!'
                          : res.errorMessage ?? 'Failed to submit review',
                    ),
                    backgroundColor: res.success
                        ? const Color(0xFF29B6F6)
                        : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF29B6F6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Submit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
