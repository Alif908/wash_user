import 'package:flutter/material.dart';
import 'package:wash_user/views/homepage/map_page.dart';
import 'package:wash_user/views/homepage/profile/profile_page.dart';
import 'package:wash_user/views/qrscanner/qr_scanner_page.dart';

class Home extends StatefulWidget {
  final int initialTabIndex;

  const Home({super.key, this.initialTabIndex = 0});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late int _selectedScreen;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _selectedScreen = widget.initialTabIndex;
    _screens = [const MapPage(), const ProfilePage()];
  }

  void _onNavItemTapped(int index) {
    if (_selectedScreen != index) {
      setState(() => _selectedScreen = index);
    }
  }

  void _navigateToQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // ✅ content goes behind nav bar (map shows through)
      body: IndexedStack(index: _selectedScreen, children: _screens),
      bottomNavigationBar: _buildBottomNavWithFAB(),
    );
  }

  Widget _buildBottomNavWithFAB() {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: 70 + bottomPad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Bottom Bar ────────────────────────────────────────────────
          Positioned(
            bottom: bottomPad > 0 ? bottomPad : 7,
            left: 15,
            right: 15,
            child: Container(
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Left — Map / Laundry
                  _buildNavItem(
                    icon: Icons.local_laundry_service,
                    selectedIcon: Icons.local_laundry_service,
                    index: 0,
                  ),

                  // Centre gap for FAB
                  const SizedBox(width: 64),

                  // Right — Profile
                  _buildNavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    index: 1,
                  ),
                ],
              ),
            ),
          ),

          // ── Centre FAB ────────────────────────────────────────────────
          Positioned(
            bottom: (bottomPad > 0 ? bottomPad : 7) + 5,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 70,
                height: 70,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFF00CFFF),
                  elevation: 6,
                  shape: const CircleBorder(),
                  onPressed: _navigateToQRScanner,
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required int index,
  }) {
    final isSelected = _selectedScreen == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onNavItemTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Top blue indicator bar ──────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 3,
              width: isSelected ? 30 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFF00CFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            // ── Icon ────────────────────────────────────────────────
            Icon(
              isSelected ? selectedIcon : icon,
              size: 28,
              color: isSelected
                  ? const Color(0xFF00CFFF)
                  : const Color(0xFF8E8E93),
            ),
          ],
        ),
      ),
    );
  }
}
