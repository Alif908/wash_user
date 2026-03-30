// lib/screens/laundry_machine_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';
import 'package:wash_user/views/qrscanner/booking_machine_page.dart';

class LaundryMachineScreen extends StatefulWidget {
  final HubModel hub;
  final HubDeviceModel device;

  const LaundryMachineScreen({
    super.key,
    required this.hub,
    required this.device,
  });

  @override
  State<LaundryMachineScreen> createState() => _LaundryMachineScreenState();
}

class _LaundryMachineScreenState extends State<LaundryMachineScreen> {
  static const Color _cyan = Color(0xFF00C8F0);
  static const Color _cardBg = Color(0xFF1C1C1E);

  bool _loadingDevice = true;
  HubDeviceModel? _deviceDetails;

  @override
  void initState() {
    super.initState();
    _loadDeviceDetails();
  }

  Future<void> _loadDeviceDetails() async {
    setState(() => _loadingDevice = true);
    final result = await ApiService.getHubDeviceDetails(
      widget.hub.id.toString(),
      widget.device.id.toString(),
    );
    if (!mounted) return;
    setState(() {
      _loadingDevice = false;
      if (result.success && result.data != null) {
        final raw =
            result.data!['hubDevice'] ??
            result.data!['device'] ??
            result.data!['data'] ??
            result.data!;
        _deviceDetails = raw is Map<String, dynamic>
            ? HubDeviceModel.fromJson(raw)
            : widget.device;
      } else {
        _deviceDetails = widget.device;
      }
    });
  }

  // ── Navigate to BookMachineScreen on button tap ────────────────────
  // FIXED: isOnline is now iotStatusCode == 0 (IDLE only)
  void _goToBooking() {
    final device = _deviceDetails ?? widget.device;
    if (!device.isOnline) {
      _snack('Machine is not available', error: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookMachineScreen(device: device, hub: widget.hub),
      ),
    );
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : _cyan,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Status dot color based on iotStatusCode ────────────────────────
  // 0 (IDLE)     → green
  // 2000 (DONE)  → amber
  // 1001/1002/1003 (BUSY) → red
  Color _statusDotColor(HubDeviceModel device) {
    switch (device.iotStatusCode) {
      case 0:
        return const Color(0xFF00FF7F);
      case 2000:
        return Colors.amber;
      default:
        return Colors.red;
    }
  }

  Color _statusGlowColor(HubDeviceModel device) {
    switch (device.iotStatusCode) {
      case 0:
        return Colors.greenAccent.withOpacity(0.6);
      case 2000:
        return Colors.amber.withOpacity(0.5);
      default:
        return Colors.red.withOpacity(0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = _deviceDetails ?? widget.device;
    final screenW = MediaQuery.of(context).size.width;
    final hPad = screenW < 360 ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: RefreshIndicator(
          color: _cyan,
          backgroundColor: _cardBg,
          onRefresh: _loadDeviceDetails,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildFeaturesRow(screenW),
                const SizedBox(height: 28),
                _buildMachineCard(device, screenW),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBookButton(device),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            widget.hub.hubName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.star_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 4),
            Text(
              '4.5',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Feature row ────────────────────────────────────────────────────
  Widget _buildFeaturesRow(double screenW) {
    final thumbSize = screenW < 360 ? 76.0 : 88.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: thumbSize,
          height: thumbSize,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/washing_machine.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_laundry_service,
                color: Colors.white38,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _FeatureChip(
                icon: Icons.local_laundry_service_outlined,
                label: 'High-speed laundry cleaner',
              ),
              SizedBox(height: 10),
              _FeatureChip(
                icon: Icons.wifi_rounded,
                label: 'Internet Connected',
              ),
              SizedBox(height: 10),
              _FeatureChip(
                icon: Icons.water_drop_outlined,
                label: 'Detergent Compatible',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Gradient machine card ──────────────────────────────────────────
  Widget _buildMachineCard(HubDeviceModel device, double screenW) {
    final iconBoxSize = screenW < 360 ? 56.0 : 64.0;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF29D8F5), Color(0xFF007B94)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // FIXED: dot color driven by iotStatusCode, not connectivityStatus
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: _statusDotColor(device),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: _statusGlowColor(device), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // FIXED: label driven by iotStatusLabel (iotStatusCode switch)
              Text(
                device.iotStatusLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_loadingDevice) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: 74,
                  decoration: BoxDecoration(
                    color: _cyan,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.local_laundry_service_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.deviceName ?? 'Machine ${device.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Condition : ${device.condition ?? 'Good'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Device ID : ${device.deviceCode}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: device.deviceCode),
                              );
                              _snack('Device ID copied!');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: _cyan.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _cyan.withOpacity(0.4),
                                ),
                              ),
                              child: const Icon(
                                Icons.copy_rounded,
                                color: _cyan,
                                size: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom Book Machine button ─────────────────────────────────────
  // FIXED: enabled only when iotStatusCode == 0 (IDLE), via device.isOnline
  Widget _buildBookButton(HubDeviceModel device) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: device.isOnline ? _goToBooking : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            disabledBackgroundColor: Colors.grey.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Ink(
            decoration: BoxDecoration(
              gradient: device.isOnline
                  ? const LinearGradient(
                      colors: [Color(0xFF00E0FF), Color(0xFF00ADCF)],
                    )
                  : null,
              color: device.isOnline ? null : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Container(
              alignment: Alignment.center,
              // FIXED: button label uses iotStatusLabel for non-idle states
              child: Text(
                device.isOnline ? 'Book Machine' : device.iotStatusLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Feature chip ───────────────────────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600, width: 1.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
