import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Us',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      home: const ContactUsScreen(),
    );
  }
}

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const String phoneNumber = '048-477-46385';
  static const String emailAddress = 'support@gmail.com';
  static const String whatsappNumber = '04847746385'; // digits only

  Future<void> _launchPhone() async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail() async {
    final uri = Uri(scheme: 'mailto', path: emailAddress);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$whatsappNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          'Contact Us',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card title
              const Text(
                'Contact Us',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // Phone Number row
              _ContactRow(
                label: 'Phone Number',
                value: phoneNumber,
                icon: Icons.phone_in_talk_outlined,
                onTap: _launchPhone,
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // Email ID row
              _ContactRow(
                label: 'Email ID',
                value: emailAddress,
                icon: Icons.email_outlined,
                onTap: _launchEmail,
              ),

              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 16),

              // WhatsApp row — uses image asset instead of icon
              _WhatsAppRow(onTap: _launchWhatsApp),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Generic contact row (phone / email) ──────────────────────────────────────
class _ContactRow extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;

  const _ContactRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                if (value != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    value!,
                    style: const TextStyle(
                      color: Color(0xFF29B6F6),
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Icon
          Icon(icon, color: const Color(0xFF29B6F6), size: 26),
        ],
      ),
    );
  }
}

// ── WhatsApp row — uses your image asset ─────────────────────────────────────
class _WhatsAppRow extends StatelessWidget {
  final VoidCallback onTap;

  const _WhatsAppRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label
          const Expanded(
            child: Text(
              'Chat Now on Whatsapp',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),

          // ✅ Image asset instead of Icons.whatsapp
          Image.asset(
            'assets/images/watsapp img.png',
            width: 26,
            height: 26,
            color: const Color(0xFF29B6F6), // tint to match theme
            colorBlendMode: BlendMode.srcIn,
            // If the image is already coloured (e.g. green WhatsApp logo),
            // remove the `color` and `colorBlendMode` lines above.
          ),
        ],
      ),
    );
  }
}
  