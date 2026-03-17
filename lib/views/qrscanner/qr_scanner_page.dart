// lib/screens/qr_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';
import 'package:wash_user/views/qrscanner/booking_machine_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme constants
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  const _C._();
  static const Color bg = Color(0xFF0A0A0A);
  static const Color cyan = Color(0xFF00CFFF);
  static const Color card = Color(0xFF1C1C1E);
  static const Color red = Colors.redAccent;
  static const Color green = Colors.greenAccent;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan state
// ─────────────────────────────────────────────────────────────────────────────
enum _ScanStatus { idle, loading, success, error }

class _ScanState {
  const _ScanState({
    this.status = _ScanStatus.idle,
    this.rawValue,
    this.device,
    this.hub,
    this.errorMessage,
  });

  final _ScanStatus status;
  final String? rawValue;
  final HubDeviceModel? device;
  final HubModel? hub;
  final String? errorMessage;

  bool get isLoading => status == _ScanStatus.loading;

  _ScanState copyWith({
    _ScanStatus? status,
    String? rawValue,
    HubDeviceModel? device,
    HubModel? hub,
    String? errorMessage,
  }) => _ScanState(
    status: status ?? this.status,
    rawValue: rawValue ?? this.rawValue,
    device: device ?? this.device,
    hub: hub ?? this.hub,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  static const _ScanState initial = _ScanState();
}

// ─────────────────────────────────────────────────────────────────────────────
// QrScannerPage
// ─────────────────────────────────────────────────────────────────────────────
class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  late final MobileScannerController _controller;
  bool _torchOn = false;
  bool _scanned = false;
  _ScanState _state = _ScanState.initial;

  // ─────────────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(torchEnabled: false);
    debugPrint('');
    debugPrint('╔══════════════════════════════════════════╗');
    debugPrint('║      QR SCANNER PAGE  →  OPENED         ║');
    debugPrint('╚══════════════════════════════════════════╝');
    debugPrint('   Camera controller created, torch = OFF');
    debugPrint('   Waiting for user to scan a QR code...');
    debugPrint('');
  }

  @override
  void dispose() {
    _controller.dispose();
    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  QR SCANNER PAGE  →  CLOSED / DISPOSED   │');
    debugPrint('│  Camera controller released               │');
    debugPrint('└──────────────────────────────────────────┘');
    debugPrint('');
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────
  // STEP 1 : CAMERA DETECTS A QR CODE
  // ─────────────────────────────────────────────────────────────────────

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) {
      debugPrint('   [CAMERA] Extra frame ignored — already scanned');
      return;
    }

    final raw = capture.barcodes.firstOrNull?.rawValue;

    if (raw == null || raw.isEmpty) {
      debugPrint(
        '   [CAMERA] Frame received but barcode value is EMPTY — skipping',
      );
      return;
    }

    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  STEP 1 : QR CODE DETECTED BY CAMERA     │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  Raw value → "$raw"');
    debugPrint('│  Camera stopped. Processing now...       │');
    debugPrint('└──────────────────────────────────────────┘');
    debugPrint('');

    setState(() => _scanned = true);
    _controller.stop();
    _processValue(raw);
  }

  // ─────────────────────────────────────────────────────────────────────
  // STEP 2-7 : PARSE QR  →  CALL API  →  NAVIGATE
  // Expected QR format:  "hubId|hubDeviceId"   e.g. "1|1"
  // ─────────────────────────────────────────────────────────────────────

  Future<void> _processValue(String value) async {
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  STEP 2 : PARSING QR VALUE               │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  Raw value → "$value"');
    debugPrint('│  Splitting by "|" character...           │');
    debugPrint('└──────────────────────────────────────────┘');

    _setState(_ScanState(status: _ScanStatus.loading, rawValue: value));

    // ── Validate format ───────────────────────────────────────────────
    final parts = value.split('|');

    if (parts.length != 2) {
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════╗');
      debugPrint('║  ❌  INVALID QR FORMAT                   ║');
      debugPrint('╠══════════════════════════════════════════╣');
      debugPrint('║  Expected  → "hubId|hubDeviceId"         ║');
      debugPrint('║  Got       → "$value"');
      debugPrint('║  Parts found: ${parts.length} (need exactly 2)');
      debugPrint('║  → Showing error snackbar & resetting    ║');
      debugPrint('╚══════════════════════════════════════════╝');
      debugPrint('');
      _showSnack('Invalid QR format. Got: "$value"');
      _resetScanner();
      return;
    }

    final hubId = parts[0].trim();
    final hubDeviceId = parts[1].trim();

    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  STEP 3 : QR PARSED SUCCESSFULLY ✅      │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  Hub ID        → "$hubId"');
    debugPrint('│  Hub Device ID → "$hubDeviceId"');
    debugPrint('└──────────────────────────────────────────┘');
    debugPrint('');

    // ── Call API ──────────────────────────────────────────────────────
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  STEP 4 : CALLING API                    │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  Endpoint → GET /api/user/hub/$hubId/devices/$hubDeviceId');
    debugPrint('│  Waiting for server response...          │');
    debugPrint('└──────────────────────────────────────────┘');

    // Always call getHubDeviceDetails — never getDevicesOfHub
    final result = await ApiService.getHubDeviceDetails(hubId, hubDeviceId);

    if (!mounted) {
      debugPrint('   [WARNING] Widget disposed before API returned — aborting');
      return;
    }

    // ── Handle API response ───────────────────────────────────────────
    if (result.success) {
      debugPrint('');
      debugPrint('┌──────────────────────────────────────────┐');
      debugPrint('│  STEP 5 : API RESPONSE  →  SUCCESS ✅    │');
      debugPrint('├──────────────────────────────────────────┤');
      debugPrint('│  Full response data:');
      debugPrint('│  ${result.data}');
      debugPrint('└──────────────────────────────────────────┘');
      debugPrint('');

      // ── Extract device & hub JSON ──────────────────────────────────
      //
      // The backend can return two different shapes:
      //
      // SHAPE A — getHubDeviceDetails returns a single hubDevice object:
      // {
      //   "success": true,
      //   "hubDevice": {
      //     "id": 1, "deviceCode": "DEV001", ...,
      //     "hub":    { "id": 1, "hubName": "...", "address": "..." },
      //     "device": { "id": 1, "deviceId": "...", "deviceName": "..." }
      //   }
      // }
      //
      // SHAPE B — backend mistakenly returns devices array (hub-level response):
      // {
      //   "success": true,
      //   "hub":     { "id": 1, "hubName": "...", "address": "..." },
      //   "devices": [
      //     { "id": 1, "deviceCode": "DEV001", ..., "Device": { ... } }
      //   ]
      // }

      Map<String, dynamic>? hubDeviceJson;
      Map<String, dynamic>? hubJson;

      // ── Try SHAPE A first ─────────────────────────────────────────
      if (result.data?['hubDevice'] != null) {
        debugPrint('   [SHAPE] Detected SHAPE A → hubDevice object present');

        hubDeviceJson = result.data!['hubDevice'] as Map<String, dynamic>?;

        // Hub is nested inside hubDevice in shape A
        hubJson =
            (hubDeviceJson?['hub'] ??
                    result.data?['hub'] ??
                    result.data?['Hub'])
                as Map<String, dynamic>?;
      }
      // ── Fallback: SHAPE B — devices array ────────────────────────
      else if (result.data?['devices'] != null) {
        debugPrint('   [SHAPE] Detected SHAPE B → devices array present');
        debugPrint(
          '   [SHAPE] Searching for hubDeviceId="$hubDeviceId" in list...',
        );

        hubJson = result.data?['hub'] as Map<String, dynamic>?;

        final devicesList = result.data?['devices'] as List<dynamic>?;

        debugPrint(
          '   [SHAPE] devices list IDs → ${devicesList?.map((d) => d['id'].toString()).toList()}',
        );

        // Match by hub device row id
        hubDeviceJson =
            devicesList?.firstWhere(
                  (d) => d['id'].toString() == hubDeviceId,
                  orElse: () => null,
                )
                as Map<String, dynamic>?;

        // Fallback: match by deviceCode in case QR encodes that instead
        if (hubDeviceJson == null) {
          debugPrint(
            '   [SHAPE] id match failed — trying deviceCode match for "$hubDeviceId"',
          );
          hubDeviceJson =
              devicesList?.firstWhere(
                    (d) =>
                        d['deviceCode']?.toString().toLowerCase() ==
                        hubDeviceId.toLowerCase(),
                    orElse: () => null,
                  )
                  as Map<String, dynamic>?;
        }

        // Shape B uses capital "Device" key for the nested device info.
        // Normalise to lowercase "device" so HubDeviceModel.fromJson works.
        if (hubDeviceJson != null && hubDeviceJson['Device'] != null) {
          hubDeviceJson = Map<String, dynamic>.from(hubDeviceJson);
          hubDeviceJson['device'] = hubDeviceJson['Device'];
        }
      }

      debugPrint('┌──────────────────────────────────────────┐');
      debugPrint('│  STEP 6 : EXTRACTING DEVICE & HUB DATA  │');
      debugPrint('├──────────────────────────────────────────┤');
      debugPrint('│  hubDevice JSON → $hubDeviceJson');
      debugPrint('│  Hub JSON       → $hubJson');
      debugPrint('└──────────────────────────────────────────┘');
      debugPrint('');

      // ── Parse into models ──────────────────────────────────────────
      final device = hubDeviceJson != null
          ? HubDeviceModel.fromJson(hubDeviceJson)
          : null;
      final hub = hubJson != null ? HubModel.fromJson(hubJson) : null;

      if (device != null && hub != null) {
        debugPrint('┌──────────────────────────────────────────┐');
        debugPrint('│  STEP 7 : MODELS PARSED SUCCESSFULLY ✅  │');
        debugPrint('├──────────────────────────────────────────┤');
        debugPrint('│  Device Code   → ${device.deviceCode}');
        debugPrint('│  Device ID     → ${device.id}');
        debugPrint('│  Device Status → ${device.connectivityStatus}');
        debugPrint('│  Hub Name      → ${hub.hubName}');
        debugPrint('│  Hub ID        → ${hub.id}');
        debugPrint('├──────────────────────────────────────────┤');
        debugPrint('│  → Navigating to BookMachineScreen...    │');
        debugPrint('└──────────────────────────────────────────┘');
        debugPrint('');
        _goToBookMachine(device: device, hub: hub);
      } else {
        debugPrint('');
        debugPrint('╔══════════════════════════════════════════╗');
        debugPrint('║  ❌  PARSE FAILED — DATA INCOMPLETE      ║');
        debugPrint('╠══════════════════════════════════════════╣');
        debugPrint('║  device model → $device');
        debugPrint('║  hub model    → $hub');
        debugPrint('║  One or both are null after parsing.     ║');
        debugPrint('║  → Showing error & resetting scanner     ║');
        debugPrint('╚══════════════════════════════════════════╝');
        debugPrint('');
        _showSnack('Device or hub data missing. Try again.');
        _resetScanner();
      }
    } else {
      debugPrint('');
      debugPrint('╔══════════════════════════════════════════╗');
      debugPrint('║  ❌  API RESPONSE  →  FAILED             ║');
      debugPrint('╠══════════════════════════════════════════╣');
      debugPrint('║  Error → ${result.errorMessage}');
      debugPrint('║  → Showing error snackbar & resetting    ║');
      debugPrint('╚══════════════════════════════════════════╝');
      debugPrint('');
      _showSnack(result.errorMessage ?? 'Device not found.');
      _resetScanner();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────────────────────────────────

  void _goToBookMachine({
    required HubDeviceModel device,
    required HubModel hub,
  }) {
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  NAVIGATION → BookMachineScreen          │');
    debugPrint('│  Replacing current route...              │');
    debugPrint('└──────────────────────────────────────────┘');
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => BookMachineScreen(device: device, hub: hub),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────

  void _setState(_ScanState next) {
    if (!mounted) return;
    setState(() => _state = next);
  }

  void _resetScanner() {
    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  RESET  →  Scanner ready to scan again   │');
    debugPrint('│  _scanned = false, state = idle          │');
    debugPrint('│  Camera restarted                        │');
    debugPrint('└──────────────────────────────────────────┘');
    debugPrint('');
    setState(() {
      _scanned = false;
      _state = _ScanState.initial;
    });
    _controller.start();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    debugPrint('   [SNACKBAR] Showing → "$msg"');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _C.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleTorch() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
    debugPrint('   [TORCH] Torch is now ${_torchOn ? "ON 🔦" : "OFF"}');
  }

  // ─────────────────────────────────────────────────────────────────────
  // MANUAL ENTRY DIALOG
  // ─────────────────────────────────────────────────────────────────────

  void _showManualEntryDialog() {
    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  MANUAL ENTRY DIALOG  →  OPENED          │');
    debugPrint('│  User will type Hub ID and Device ID     │');
    debugPrint('└──────────────────────────────────────────┘');
    debugPrint('');

    final hubCtrl = TextEditingController();
    final deviceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E2A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Flexible(
                        child: Text(
                          'Enter Charger Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          debugPrint(
                            '   [MANUAL ENTRY] Dialog closed by user (X button)',
                          );
                          Navigator.pop(ctx);
                        },
                        child: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  const Text(
                    'Hub ID',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: hubCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: _C.cyan,
                    decoration: _fieldDecoration('Enter Hub ID'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onFieldSubmitted: (_) => FocusScope.of(ctx).nextFocus(),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hub Device ID',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: deviceCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: _C.cyan,
                    decoration: _fieldDecoration('Enter Hub Device ID'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onFieldSubmitted: (_) =>
                        _submitManual(ctx, formKey, hubCtrl, deviceCtrl),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () =>
                            _submitManual(ctx, formKey, hubCtrl, deviceCtrl),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2979FF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
    filled: true,
    fillColor: const Color(0xFF2A2A38),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white12, width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white12, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _C.cyan, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _C.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _C.red, width: 1.5),
    ),
    errorStyle: const TextStyle(color: _C.red, fontSize: 11),
  );

  void _submitManual(
    BuildContext ctx,
    GlobalKey<FormState> formKey,
    TextEditingController hubCtrl,
    TextEditingController deviceCtrl,
  ) {
    debugPrint('   [MANUAL ENTRY] Continue button pressed');

    if (!formKey.currentState!.validate()) {
      debugPrint(
        '   [MANUAL ENTRY] ❌ Validation failed — one or both fields are empty',
      );
      return;
    }

    final hubId = hubCtrl.text.trim();
    final hubDeviceId = deviceCtrl.text.trim();
    final combined = '$hubId|$hubDeviceId';

    debugPrint('');
    debugPrint('┌──────────────────────────────────────────┐');
    debugPrint('│  MANUAL ENTRY  →  SUBMITTED ✅           │');
    debugPrint('├──────────────────────────────────────────┤');
    debugPrint('│  Hub ID        → "$hubId"');
    debugPrint('│  Hub Device ID → "$hubDeviceId"');
    debugPrint('│  Combined      → "$combined"');
    debugPrint('│  → Closing dialog & processing value...  │');
    debugPrint('└──────────────────────────────────────────┘');
    debugPrint('');

    Navigator.pop(ctx);
    setState(() => _scanned = true);
    _controller.stop();
    _processValue(combined);
  }

  // ─────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;

    // Scanner box: square, capped so it never crowds the bottom card
    final scannerSize = (screenW * 0.68).clamp(180.0, screenH * 0.40);

    return Scaffold(
      backgroundColor: _C.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () {
                        debugPrint(
                          '   [NAV] Back button pressed — popping route',
                        );
                        Navigator.maybePop(context);
                      },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                        color: _torchOn ? _C.cyan : Colors.white,
                      ),
                      onPressed: _toggleTorch,
                    ),
                  ),
                ],
              ),
            ),

            // ── Title ────────────────────────────────────────────────────
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Scan Charger Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Scan the QR code on the charger',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),

            // ── Equal spacers sandwich the scanner so it stays centred ───
            const Spacer(),

            SizedBox(
              width: scannerSize,
              height: scannerSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(controller: _controller, onDetect: _onDetect),
                    CustomPaint(painter: _OverlayPainter()),

                    // Loading overlay — API call in progress
                    if (_scanned && _state.isLoading)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(color: _C.cyan),
                        ),
                      ),

                    // Success overlay — only on actual success
                    if (_scanned &&
                        !_state.isLoading &&
                        _state.status == _ScanStatus.success)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: Icon(
                            Icons.check_circle,
                            color: _C.cyan,
                            size: 72,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // ── Bottom card ──────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: _C.card,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Not able to scan?',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Enter Device ID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _showManualEntryDialog,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.cyan, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          'ID',
                          style: TextStyle(
                            color: _C.cyan,
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cyan corner-bracket overlay painter
// ─────────────────────────────────────────────────────────────────────────────
class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _C.cyan
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const double len = 30;
    const double r = 12;
    final double w = size.width;
    final double h = size.height;

    // Top-left corner
    canvas.drawPath(
      Path()
        ..moveTo(0, len + r)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len + r, 0),
      p,
    );
    // Top-right corner
    canvas.drawPath(
      Path()
        ..moveTo(w - len - r, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, len + r),
      p,
    );
    // Bottom-left corner
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
      p,
    );
    // Bottom-right corner
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
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
