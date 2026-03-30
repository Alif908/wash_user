// ── CHANGES SUMMARY ───────────────────────────────────────────────────────────
// 1. _HubBottomSheet now accepts a BuildContext from MapPage and loads hub
//    devices via ApiService.getDevicesOfHub() before navigating.
// 2. "Book Now" shows a loading spinner while fetching devices, then navigates
//    to LaundryMachineScreen with the first available/online device.
//    If no device is available, shows a snackbar.
// 3. Only _HubBottomSheet is changed — rest of map_page.dart is untouched.
//
// REPLACE your existing _HubBottomSheet class with this one.
// Also update _showHubSheet() in _MapPageState (shown at the bottom).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:wash_user/views/homepage/laudary_machine_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';
import 'package:wash_user/views/homepage/profile/contact_us.dart';
import 'package:wash_user/views/qrscanner/qr_scanner_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const Color _cyan = Color(0xFF00CFFF);
  static const Color _cardBg = Color(0xFF1C1C1E);
  static const double _navBarHeight = 80.0;

  late final WebViewController _webViewController;
  bool _mapReady = false;

  LatLngSimple? _userLatLng;
  String _locationLabel = 'Your location';
  List<HubModel> _hubs = [];
  List<HubModel> _filteredHubs = [];
  bool _isLoadingHubs = false;
  String? _error;
  int _selectedHubIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _initWebView();
    _initLocation();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'HereMapChannel',
        onMessageReceived: (msg) => _onMapMessage(msg.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _mapReady = true);
            _syncMapState();
          },
        ),
      )
      ..loadFlutterAsset('assets/map.html');
  }

  void _syncMapState() {
    if (!_mapReady) return;
    if (_userLatLng != null) {
      _js('flutterInit(${_userLatLng!.lat}, ${_userLatLng!.lng}, 14)');
      _js('flutterSetUserMarker(${_userLatLng!.lat}, ${_userLatLng!.lng})');
    } else {
      _js('flutterInit(10.5276, 76.2144, 13)');
    }
    if (_filteredHubs.isNotEmpty) _pushHubMarkers();
  }

  void _js(String script) {
    _webViewController.runJavaScript(script).catchError((_) {});
  }

  void _onMapMessage(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['type'] == 'hubTap') {
        final hub = HubModel.fromJson(map['hub'] as Map<String, dynamic>);
        if (!mounted) return;
        _showHubSheet(hub);
      }
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locationLabel = 'Location service disabled');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _locationLabel = 'Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(
          () => _locationLabel = 'Location permission permanently denied',
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _userLatLng = LatLngSimple(pos.latitude, pos.longitude);
        _locationLabel = 'Your location';
      });
      if (_mapReady) {
        _js('flutterMoveToLocation(${pos.latitude}, ${pos.longitude}, 14)');
        _js('flutterSetUserMarker(${pos.latitude}, ${pos.longitude})');
      }
      await ApiService.updateLocation(pos.latitude, pos.longitude);
      _loadNearestHubs();
    } catch (e) {
      debugPrint('Location error: $e');
      if (!mounted) return;
      setState(() => _locationLabel = 'Could not get location');
    }
  }

  Future<void> _loadNearestHubs() async {
    setState(() {
      _isLoadingHubs = true;
      _error = null;
    });
    final result = await ApiService.getNearestHubs();
    if (!mounted) return;
    if (result.success) {
      final rawList = result.data?['hubs'] ?? result.data?['data'] ?? [];
      final hubs = (rawList as List)
          .map((e) => HubModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _hubs = hubs;
        _filteredHubs = hubs;
        _isLoadingHubs = false;
        _selectedHubIndex = 0;
      });
      _pushHubMarkers();
    } else {
      setState(() {
        _error = result.errorMessage;
        _isLoadingHubs = false;
      });
    }
  }

  void _pushHubMarkers() {
    if (!_mapReady) return;
    final jsonStr = jsonEncode(
      _filteredHubs
          .map(
            (h) => {
              'latitude': h.latitude,
              'longitude': h.longitude,
              'hubName': h.hubName,
              'address': h.address,
              'operatorName': h.operatorName,
              'operatorMobile': h.operatorMobile,
              'deviceCount': h.deviceCount,
            },
          )
          .toList(),
    );
    final escaped = jsonStr.replaceAll("'", "\\'");
    _js("flutterSetHubMarkers('$escaped')");
  }

  void _goToMyLocation() {
    if (_userLatLng == null) {
      _initLocation();
      return;
    }
    _js('flutterMoveToLocation(${_userLatLng!.lat}, ${_userLatLng!.lng}, 15)');
  }

  // ── UPDATED: pass outer context so _HubBottomSheet can navigate ──────────
  void _showHubSheet(HubModel hub) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _HubBottomSheet(
        hub: hub,
        cyan: _cyan,
        outerContext: context, // ← pass map page context for navigation
      ),
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SearchSheet(
        hubs: _hubs,
        cyan: _cyan,
        cardBg: _cardBg,
        onHubSelected: (hub) {
          Navigator.pop(ctx);
          _showHubSheet(hub);
          if (hub.latitude != null && hub.longitude != null) {
            _js('flutterMoveToLocation(${hub.latitude}, ${hub.longitude}, 15)');
          }
        },
        onFilterApplied: (filtered) {
          setState(() => _filteredHubs = filtered);
          _pushHubMarkers();
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final bottomOffset = _navBarHeight + bottomPad;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _webViewController)),

          // Top Search Bar
          Positioned(
            top: topPad + 8,
            left: 16,
            right: 72,
            child: GestureDetector(
              onTap: _showSearchSheet,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isLoadingHubs)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: _cyan,
                          strokeWidth: 2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Right FABs
          Positioned(
            top: topPad + 8,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapFab(
                  icon: Icons.phone,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _MapFab(icon: Icons.tune, onTap: _showSearchSheet),
                const SizedBox(height: 12),
                _MapFab(icon: Icons.my_location, onTap: _goToMyLocation),
                const SizedBox(height: 12),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _MapFab(
                      icon: Icons.shopping_cart_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QrScannerPage(),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -6,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Error Banner
          if (_error != null)
            Positioned(
              top: topPad + 70,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Nearby Hubs Panel
          if (_filteredHubs.isNotEmpty)
            Positioned(
              bottom: bottomOffset + 8,
              left: 0,
              right: 0,
              child: _NearbyHubsPanel(
                hubs: _filteredHubs,
                cyan: _cyan,
                cardBg: const Color(0xFF1C1C1E),
                selectedIndex: _selectedHubIndex,
                onHubTap: (hub, index) {
                  setState(() => _selectedHubIndex = index);
                  _showHubSheet(hub);
                  if (hub.latitude != null && hub.longitude != null) {
                    _js(
                      'flutterMoveToLocation(${hub.latitude}, ${hub.longitude}, 15)',
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── LatLng helper ─────────────────────────────────────────────────────────────
class LatLngSimple {
  final double lat, lng;
  const LatLngSimple(this.lat, this.lng);
}

// ── Nearby Hubs Panel ─────────────────────────────────────────────────────────
class _NearbyHubsPanel extends StatelessWidget {
  final List<HubModel> hubs;
  final Color cyan;
  final Color cardBg;
  final int selectedIndex;
  final void Function(HubModel hub, int index) onHubTap;

  const _NearbyHubsPanel({
    required this.hubs,
    required this.cyan,
    required this.cardBg,
    required this.selectedIndex,
    required this.onHubTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW * 0.85).clamp(260.0, 320.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.80),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.waves, color: cyan, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${hubs.length} Hub${hubs.length != 1 ? 's' : ''} Nearby',
                  style: TextStyle(
                    color: cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(hubs.length, (i) {
              final hub = hubs[i];
              final isSelected = i == selectedIndex;
              return Padding(
                padding: EdgeInsets.only(right: i < hubs.length - 1 ? 10 : 0),
                child: _HubCard(
                  hub: hub,
                  cyan: cyan,
                  cardBg: cardBg,
                  isSelected: isSelected,
                  cardWidth: cardW,
                  onTap: () => onHubTap(hub, i),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ── Hub Card ──────────────────────────────────────────────────────────────────
class _HubCard extends StatelessWidget {
  final HubModel hub;
  final Color cyan;
  final Color cardBg;
  final bool isSelected;
  final double cardWidth;
  final VoidCallback onTap;

  const _HubCard({
    required this.hub,
    required this.cyan,
    required this.cardBg,
    required this.isSelected,
    required this.cardWidth,
    required this.onTap,
  });

  String _distanceLabel(double? dist) {
    if (dist == null) return 'Nearby';
    if (dist < 1) return 'Very Near';
    if (dist < 3) return 'Near';
    if (dist < 10) return 'Moderate';
    return 'Far Away';
  }

  @override
  Widget build(BuildContext context) {
    final dist = hub.distance;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cardWidth,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.92),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? cyan : cyan.withOpacity(0.22),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? cyan.withOpacity(0.18)
                  : Colors.black.withOpacity(0.35),
              blurRadius: isSelected ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves, color: cyan, size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'High-speed laundry cleaner',
                    style: TextStyle(
                      color: cyan.withOpacity(0.85),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white30,
                  size: 15,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cyan.withOpacity(0.25), width: 1),
                  ),
                  child: Icon(
                    Icons.local_laundry_service,
                    color: cyan,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hub.hubName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hub.address ?? 'No address',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          const Text(
                            '4.7',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Available',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    if (dist != null) ...[
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: cyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: cyan.withOpacity(0.45),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.navigation, color: cyan, size: 9),
                            const SizedBox(width: 2),
                            Text(
                              '${dist.toStringAsFixed(1)}km',
                              style: TextStyle(
                                color: cyan,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _ServiceIcon(Icons.shopping_basket_outlined),
                  const SizedBox(width: 3),
                  _ServiceIcon(Icons.local_laundry_service_outlined),
                  const SizedBox(width: 6),
                  _DividerLine(),
                  const SizedBox(width: 6),
                  _ServiceIcon(Icons.dry_cleaning_outlined),
                  const SizedBox(width: 3),
                  _ServiceIcon(Icons.accessibility_new_outlined),
                  const SizedBox(width: 6),
                  _DividerLine(),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _distanceLabel(dist),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
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

class _ServiceIcon extends StatelessWidget {
  final IconData icon;
  const _ServiceIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Colors.white54, size: 13);
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 12, color: Colors.white24);
  }
}

// ── Hub Bottom Sheet ── UPDATED ───────────────────────────────────────────────
class _HubBottomSheet extends StatefulWidget {
  final HubModel hub;
  final Color cyan;
  final BuildContext outerContext; // ← map page context for Navigator.push

  const _HubBottomSheet({
    required this.hub,
    required this.cyan,
    required this.outerContext,
  });

  @override
  State<_HubBottomSheet> createState() => _HubBottomSheetState();
}

class _HubBottomSheetState extends State<_HubBottomSheet> {
  bool _loadingDevices = false;

  Future<void> raiseTicket(String deviceId) async {
    try {
      await ApiService().createServiceTicket(
        deviceId: deviceId,
        issue: "All machines are offline",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Ticket created ✅")));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to create ticket ❌")));
    }
  }

  /// Fetch devices for this hub, pick the first online one,
  /// then navigate to LaundryMachineScreen.
  Future<void> _onBookNow() async {
    setState(() => _loadingDevices = true);

    final result = await ApiService.getDevicesOfHub(widget.hub.id.toString());

    if (!mounted) return;
    setState(() => _loadingDevices = false);

    if (!result.success) {
      _showSnack(result.errorMessage ?? 'Failed to load devices');
      return;
    }

    // Parse device list — backend may wrap in 'devices', 'hubDevices', or 'data'
    final raw =
        result.data?['devices'] ??
        result.data?['hubDevices'] ??
        result.data?['data'] ??
        [];

    final devices = (raw as List)
        .whereType<Map<String, dynamic>>()
        .map(HubDeviceModel.fromJson)
        .toList();

    if (devices.isEmpty) {
      _showSnack('No devices found for this hub');
      return;
    }

    // Prefer an online device; fall back to the first one
    final device = devices.firstWhere(
      (d) => d.isOnline,
      orElse: () => devices.first,
    );

    // final onlineDevices = devices.where((d) => d.isOnline).toList();

    // if (onlineDevices.isEmpty) {
    //   _showSnack("All machines are currently offline ❌");

    //   // 👉 Optional: allow ticket here
    //   raiseTicket(devices.first.id.toString());
    //   ;

    //   return;
    // }

    // final device = onlineDevices.first;

    // Close the bottom sheet, then push from the map page context
    if (!mounted) return;
    Navigator.pop(context);

    Navigator.push(
      widget.outerContext,
      MaterialPageRoute(
        builder: (_) => LaundryMachineScreen(hub: widget.hub, device: device),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = widget.hub;
    final cyan = widget.cyan;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cyan.withOpacity(0.3), width: 1),
                ),
                child: Icon(Icons.local_laundry_service, color: cyan, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hub.hubName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.star, color: Colors.amber, size: 14),
                            SizedBox(width: 4),
                            Text(
                              '4.7',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.circle, color: Colors.green, size: 8),
                            SizedBox(width: 4),
                            Text(
                              'Available',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (hub.distance != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: cyan.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.navigation, color: cyan, size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  '${hub.distance!.toStringAsFixed(2)}km',
                                  style: TextStyle(
                                    color: cyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          if (hub.address != null)
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: hub.address!,
              cyan: cyan,
            ),
          if (hub.operatorName != null)
            _InfoRow(
              icon: Icons.person_outline,
              text: 'Operator: ${hub.operatorName}',
              cyan: cyan,
            ),
          if (hub.operatorMobile != null)
            _InfoRow(
              icon: Icons.phone_outlined,
              text: hub.operatorMobile!,
              cyan: cyan,
            ),
          if (hub.deviceCount != null)
            _InfoRow(
              icon: Icons.devices_outlined,
              text: '${hub.deviceCount} Devices available',
              cyan: cyan,
            ),

          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ServiceChip(
                  icon: Icons.shopping_basket_outlined,
                  label: 'Wash',
                  cyan: cyan,
                ),
                _ServiceChip(
                  icon: Icons.local_laundry_service_outlined,
                  label: 'Dry',
                  cyan: cyan,
                ),
                _ServiceChip(
                  icon: Icons.dry_cleaning_outlined,
                  label: 'Iron',
                  cyan: cyan,
                ),
                _ServiceChip(
                  icon: Icons.accessibility_new_outlined,
                  label: 'Fold',
                  cyan: cyan,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Book Now Button ───────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loadingDevices ? null : _onBookNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: cyan,
                disabledBackgroundColor: cyan.withOpacity(0.5),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loadingDevices
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Book Now',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Search Sheet ──────────────────────────────────────────────────────────────
class _SearchSheet extends StatefulWidget {
  final List<HubModel> hubs;
  final Color cyan;
  final Color cardBg;
  final void Function(HubModel) onHubSelected;
  final void Function(List<HubModel>) onFilterApplied;

  const _SearchSheet({
    required this.hubs,
    required this.cyan,
    required this.cardBg,
    required this.onHubSelected,
    required this.onFilterApplied,
  });

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<HubModel> _results = [];

  @override
  void initState() {
    super.initState();
    _results = widget.hubs;
    _controller.addListener(() {
      final q = _controller.text.toLowerCase().trim();
      setState(() {
        _results = q.isEmpty
            ? widget.hubs
            : widget.hubs
                  .where(
                    (h) =>
                        h.hubName.toLowerCase().contains(q) ||
                        (h.address ?? '').toLowerCase().contains(q),
                  )
                  .toList();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final keyboardH = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardH),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: widget.cyan.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: widget.cyan.withOpacity(0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search hub name or address...',
                          hintStyle: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      GestureDetector(
                        onTap: _controller.clear,
                        child: const Icon(
                          Icons.close,
                          color: Colors.white38,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_results.length} hub${_results.length != 1 ? 's' : ''} found',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No hubs found',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPad + 16),
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (ctx, i) {
                        final hub = _results[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: widget.cyan.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_laundry_service,
                              color: widget.cyan,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            hub.hubName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: hub.address != null
                              ? Text(
                                  hub.address!,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: widget.cyan.withOpacity(0.5),
                            size: 13,
                          ),
                          onTap: () => widget.onHubSelected(hub),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── FAB Button ────────────────────────────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.82),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF00CFFF), size: 22),
      ),
    );
  }
}

// ── Service Chip ──────────────────────────────────────────────────────────────
class _ServiceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color cyan;
  const _ServiceChip({
    required this.icon,
    required this.label,
    required this.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: cyan, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: cyan.withOpacity(0.8), fontSize: 10),
        ),
      ],
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color cyan;
  const _InfoRow({required this.icon, required this.text, required this.cyan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, color: cyan, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
