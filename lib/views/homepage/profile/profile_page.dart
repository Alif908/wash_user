import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wash_user/models/usermodel.dart';
import 'package:wash_user/services/api_service.dart';
import 'package:wash_user/views/homepage/profile/contact_us.dart';
import 'package:wash_user/views/homepage/profile/my_booking.dart';
import 'package:wash_user/views/homepage/profile/washing_status.dart';
import 'package:wash_user/views/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color _cyan = Color(0xFF00CFFF);
  static const Color _cardBg = Color(0xFF1C1C1E);
  static const Color _scaffoldBg = Color(0xFF0A0A0A);

  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    final idStr = prefs.getString('user_id');
    final name = prefs.getString('user_name') ?? 'User';
    final mobile = prefs.getString('user_mobile') ?? '';

    setState(() {
      _user = UserModel(
        id: int.tryParse(idStr ?? '') ?? 0,
        name: name,
        mobile: mobile,
        isVerified: true,
      );
      _isLoading = false;
    });
  }

  Future<void> _onLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: _cyan)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await ApiService.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      appBar: AppBar(
        backgroundColor: _scaffoldBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8, bottom: 8),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyan,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 0,
                ),
              ),
              child: const Text(
                'USER',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _cyan))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // ── Profile Card ─────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user?.name ?? 'User',
                          style: const TextStyle(
                            color: _cyan,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (_user?.mobile.isNotEmpty ?? false)
                              ? '+91 ${_user!.mobile}'
                              : '',
                          style: const TextStyle(
                            color: _cyan,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {},
                          child: const Text(
                            'Edit Profile >',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Menu Items ───────────────────────────────────────
                  _buildMenuItem(
                    icon: Icons.waves,
                    label: 'Washing Status',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WashingStatus()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.format_list_bulleted,
                    label: 'My Bookings',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyBookingsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.phone,
                    label: 'Contact Us',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ContactUsScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.language,
                    label: 'Language',
                    onTap: () {},
                  ),
                  const SizedBox(height: 12),
                  _buildMenuItem(
                    icon: Icons.logout,
                    label: 'Log Out',
                    onTap: _onLogout,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: _cyan, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: _cyan, size: 22),
          ],
        ),
      ),
    );
  }
}
