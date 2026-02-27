import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  static const Color _scaffoldBg = Color(0xFF0A0A0A);
  static const Color _cyan = Color(0xFF00CFFF);
  static const Color _cardBg = Color(0xFF1C1C1E);

  late final MobileScannerController _controller;
  bool _torchOn = false;
  bool _scanned = false;

  // API state
  bool _isLoadingDevice = false;
  HubDeviceModel? _scannedDevice;
  HubModel? _scannedHub;
  String? _apiError;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(torchEnabled: false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Called every time a barcode is detected
  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _scanned = true);
    _controller.stop();
    _handleScannedValue(barcode!.rawValue!);
  }

  // Parse scanned QR → fetch device from API
  // Expected QR format: "hubId:hubDeviceId"  e.g. "3:12"
  Future<void> _handleScannedValue(String value) async {
    setState(() {
      _isLoadingDevice = true;
      _apiError = null;
      _scannedDevice = null;
      _scannedHub = null;
    });

    try {
      final parts = value.split(':');
      if (parts.length == 2) {
        final hubId = parts[0].trim();
        final hubDeviceId = parts[1].trim();

        final result = await ApiService.getHubDeviceDetails(hubId, hubDeviceId);

        if (result.success) {
          final deviceJson =
              result.data?['hubDevice'] ?? result.data?['device'];
          final hubJson = result.data?['hub'];

          setState(() {
            _scannedDevice = deviceJson != null
                ? HubDeviceModel.fromJson(deviceJson)
                : null;
            _scannedHub = hubJson != null ? HubModel.fromJson(hubJson) : null;
            _isLoadingDevice = false;
          });
        } else {
          setState(() {
            _apiError = result.errorMessage ?? 'Device not found';
            _isLoadingDevice = false;
          });
        }
      } else {
        // Not hub:device format — show raw value
        setState(() => _isLoadingDevice = false);
      }
    } catch (e) {
      setState(() {
        _apiError = 'Error: $e';
        _isLoadingDevice = false;
      });
    }

    _showResultDialog(value);
  }

  // Show scanned result and let user scan again
  void _showResultDialog(String value) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'QR Code Scanned!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: _isLoadingDevice
            ? const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator(color: _cyan)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Device ID:',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _scannedDevice?.deviceCode ?? value,
                    style: const TextStyle(
                      color: _cyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_scannedHub != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Hub: ${_scannedHub!.hubName}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_scannedDevice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Status: ${_scannedDevice!.connectivityStatus.toUpperCase()}',
                      style: TextStyle(
                        color: _scannedDevice!.isOnline
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if (_apiError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _apiError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _scanned = false;
                _scannedDevice = null;
                _scannedHub = null;
                _apiError = null;
              });
              _controller.start();
            },
            child: const Text('Scan Again', style: TextStyle(color: _cyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Continue',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Toggle flashlight
  void _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  // Manual Device ID entry dialog
  void _showEnterDeviceIdDialog() {
    final TextEditingController textCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Enter Device ID',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. hubId:hubDeviceId',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _cyan),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _cyan, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final id = textCtrl.text.trim();
              Navigator.pop(ctx);
              if (id.isNotEmpty) {
                setState(() => _scanned = true);
                _controller.stop();
                _handleScannedValue(id);
              }
            },
            child: const Text('Submit', style: TextStyle(color: _cyan)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Back button ──────────────────────────────────────────
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),

            // ── Torch toggle ─────────────────────────────────────────
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  _torchOn ? Icons.flash_on : Icons.flash_off,
                  color: _torchOn ? _cyan : Colors.white,
                ),
                onPressed: _toggleTorch,
              ),
            ),

            // ── Main layout ──────────────────────────────────────────
            Column(
              children: [
                const SizedBox(height: 80),

                const Text(
                  'Scan Charger Code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  'Scan the QR code on the charger',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),

                const SizedBox(height: 40),

                // ── Scanner box ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _controller,
                            onDetect: _onDetect,
                          ),
                          CustomPaint(painter: _ScannerOverlayPainter()),
                          if (_scanned)
                            Container(
                              color: Colors.black54,
                              child: const Center(
                                child: Icon(
                                  Icons.check_circle,
                                  color: _cyan,
                                  size: 72,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ── Bottom card ───────────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Not able to scan?',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Enter Device ID',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _showEnterDeviceIdDialog,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _cyan, width: 2),
                          ),
                          child: const Center(
                            child: Text(
                              'ID',
                              style: TextStyle(
                                color: _cyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints cyan corner brackets inside the scanner preview
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00CFFF)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 30.0;
    const r = 12.0;
    final w = size.width;
    final h = size.height;

    canvas.drawPath(
      Path()
        ..moveTo(0, len + r)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len + r, 0),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(w - len - r, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, len + r),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(0, h - len - r)
        ..lineTo(0, h - r)
        ..arcToPoint(
          Offset(r, h),
          radius: const Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(len + r, h),
      paint,
    );

    canvas.drawPath(
      Path()
        ..moveTo(w - len - r, h)
        ..lineTo(w - r, h)
        ..arcToPoint(
          Offset(w, h - r),
          radius: const Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(w, h - len - r),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
