import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'otp_page.dart'; // adjust path to match your project structure
import 'package:wash_user/services/api_service.dart';

// ─── Language Model ────────────────────────────────────────────────────────

class _Lang {
  final String code;
  final String label;
  final String title;
  final String phonePlaceholder;
  final String requestOtp;
  final String terms;
  final String termsLink;
  final String privacyLink;
  final String invalidPhone;
  final String countryCode;

  const _Lang({
    required this.code,
    required this.label,
    required this.title,
    required this.phonePlaceholder,
    required this.requestOtp,
    required this.terms,
    required this.termsLink,
    required this.privacyLink,
    required this.invalidPhone,
    required this.countryCode,
  });
}

const _languages = <_Lang>[
  _Lang(
    code: 'en',
    label: 'English',
    title: 'Enter Your Phone\nNumber',
    phonePlaceholder: 'Enter Phone Number',
    requestOtp: 'REQUEST OTP',
    terms: 'Joining our app means you agree with our ',
    termsLink: 'Terms of Service',
    privacyLink: 'Privacy Policy',
    invalidPhone: 'Please enter a valid 10-digit phone number',
    countryCode: '+91',
  ),
  _Lang(
    code: 'hi',
    label: 'हिंदी',
    title: 'अपना फ़ोन नंबर\nदर्ज करें',
    phonePlaceholder: 'फ़ोन नंबर दर्ज करें',
    requestOtp: 'OTP मंगाएं',
    terms: 'ऐप से जुड़ने पर आप हमारी ',
    termsLink: 'सेवा की शर्तें',
    privacyLink: 'गोपनीयता नीति',
    invalidPhone: 'कृपया 10 अंकों का वैध फ़ोन नंबर दर्ज करें',
    countryCode: '+91',
  ),
  _Lang(
    code: 'ta',
    label: 'தமிழ்',
    title: 'உங்கள் தொலைபேசி\nஎண்ணை உள்ளிடுக',
    phonePlaceholder: 'தொலைபேசி எண்ணை உள்ளிடுக',
    requestOtp: 'OTP கோரவும்',
    terms: 'பயன்பாட்டில் சேர்வதன் மூலம் நீங்கள் எங்கள் ',
    termsLink: 'சேவை விதிமுறைகள்',
    privacyLink: 'தனியுரிமைக் கொள்கை',
    invalidPhone: 'சரியான 10 இலக்க தொலைபேசி எண்ணை உள்ளிடவும்',
    countryCode: '+91',
  ),
  _Lang(
    code: 'ml',
    label: 'മലയാളം',
    title: 'നിങ്ങളുടെ ഫോൺ\nനമ്പർ നൽകുക',
    phonePlaceholder: 'ഫോൺ നമ്പർ നൽകുക',
    requestOtp: 'OTP അഭ്യർത്ഥിക്കുക',
    terms: 'ആപ്പിൽ ചേരുന്നതിലൂടെ നിങ്ങൾ ഞങ്ങളുടെ ',
    termsLink: 'സേവന നിബന്ധനകൾ',
    privacyLink: 'സ്വകാര്യതാ നയം',
    invalidPhone: 'ദയവായി 10 അക്ക ഫോൺ നമ്പർ നൽകുക',
    countryCode: '+91',
  ),
  _Lang(
    code: 'te',
    label: 'తెలుగు',
    title: 'మీ ఫోన్ నంబర్\nనమోదు చేయండి',
    phonePlaceholder: 'ఫోన్ నంబర్ నమోదు చేయండి',
    requestOtp: 'OTP అభ్యర్థించండి',
    terms: 'యాప్‌లో చేరడం ద్వారా మీరు మా ',
    termsLink: 'సేవా నిబంధనలు',
    privacyLink: 'గోప్యతా విధానం',
    invalidPhone: 'దయచేసి చెల్లుబాటు అయ్యే 10 అంకెల ఫోన్ నంబర్ నమోదు చేయండి',
    countryCode: '+91',
  ),
];

// ─── Login Page ────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  _Lang _currentLang = _languages[0];
  bool _isLoading = false;

  static const Color kCyan = Color(0xFF00C8E8);
  static const Color kBg = Color(0xFF050A0F);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onLanguageSelected(_Lang lang) {
    setState(() => _currentLang = lang);
  }

  void _onRequestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_currentLang.invalidPhone),
          backgroundColor: const Color.fromARGB(255, 122, 161, 190),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullPhone = phone; // backend expects 10 digits only, no +91
      debugPrint('[LOGIN] Sending OTP to: $fullPhone');
      debugPrint('[LOGIN] API URL: ${ApiService.baseUrl}/send-otp');
      debugPrint('========================================');

      final result = await ApiService.sendOtp(fullPhone);

      if (!mounted) return;
      setState(() => _isLoading = false);

      debugPrint('[LOGIN] result.success  : ${result.success}');
      debugPrint('[LOGIN] result.data     : ${result.data}');
      debugPrint('[LOGIN] result.error    : ${result.errorMessage}');

      if (result.success) {
        debugPrint('[LOGIN] ✅ Navigating to OtpPage');
        debugPrint('========================================');
        debugPrint('[LOGIN] 🔑 OTP : ${result.data?['otp']}');
        debugPrint('========================================');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(
              phoneNumber: '${_currentLang.countryCode} $phone',
              mobileNumber: phone,
              debugOtp: result.data?['otp']?.toString(), // dev only
            ),
          ),
        );
      } else {
        final msg = result.errorMessage ?? 'Failed to send OTP';
        debugPrint('[LOGIN] ❌ Error: $msg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 6), // longer so you can read it
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('[LOGIN] 🔥 Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exception: $e'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      // resizeToAvoidBottomInset: true (default) — Scaffold shrinks body when
      // keyboard appears. SingleChildScrollView + ConstrainedBox + IntrinsicHeight
      // ensure the Column fills full height when keyboard is hidden, and scrolls
      // when keyboard is shown — eliminating the overflow.
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: ConstrainedBox(
                      // minHeight = available height so Spacer fills gap
                      // when keyboard is NOT open
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),

                              // Language selector (top right)
                              Align(
                                alignment: Alignment.topRight,
                                child: _LanguageSelector(
                                  currentLang: _currentLang,
                                  languages: _languages,
                                  onSelected: _onLanguageSelected,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Logo
                              const _Logo(),

                              const SizedBox(height: 28),

                              // Title
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                      opacity: anim,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.05),
                                          end: Offset.zero,
                                        ).animate(anim),
                                        child: child,
                                      ),
                                    ),
                                child: Text(
                                  _currentLang.title,
                                  key: ValueKey(_currentLang.code),
                                  style: const TextStyle(
                                    color: kCyan,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Phone Input
                              _PhoneInputField(
                                controller: _phoneController,
                                placeholder: _currentLang.phonePlaceholder,
                                countryCode: _currentLang.countryCode,
                              ),

                              // Spacer pushes bottom content down when keyboard
                              // is hidden; collapses when keyboard is shown so
                              // scroll takes over — no overflow either way
                              const Spacer(),

                              // Terms text
                              _TermsText(lang: _currentLang),

                              const SizedBox(height: 16),

                              // Request OTP Button
                              _OtpButton(
                                label: _currentLang.requestOtp,
                                onPressed: _isLoading ? () {} : _onRequestOtp,
                                isLoading: _isLoading,
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Language Selector ─────────────────────────────────────────────────────

class _LanguageSelector extends StatelessWidget {
  final _Lang currentLang;
  final List<_Lang> languages;
  final ValueChanged<_Lang> onSelected;

  static const Color kCyan = Color(0xFF00C8E8);
  static const Color kCard = Color(0xFF0D1822);
  static const Color kBorder = Color(0xFF1A3040);

  const _LanguageSelector({
    required this.currentLang,
    required this.languages,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_Lang>(
      color: kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: kBorder, width: 1),
      ),
      offset: const Offset(0, 36),
      onSelected: onSelected,
      itemBuilder: (context) => languages
          .map(
            (lang) => PopupMenuItem<_Lang>(
              value: lang,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lang.code == currentLang.code)
                    const Icon(Icons.check_rounded, color: kCyan, size: 16)
                  else
                    const SizedBox(width: 16),
                  const SizedBox(width: 8),
                  Text(
                    lang.label,
                    style: TextStyle(
                      color: lang.code == currentLang.code
                          ? kCyan
                          : Colors.white70,
                      fontSize: 14,
                      fontWeight: lang.code == currentLang.code
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currentLang.label,
            style: const TextStyle(
              color: kCyan,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, color: kCyan, size: 20),
        ],
      ),
    );
  }
}

// ─── Logo ──────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  static const Color kCyan = Color(0xFF00C8E8);

  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kCyan, width: 2.5),
          ),
          child: const Center(
            child: Icon(Icons.water_drop_rounded, color: kCyan, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'CLEAN.WASH',
          style: TextStyle(
            color: kCyan,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

// ─── Phone Input Field ─────────────────────────────────────────────────────

class _PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final String countryCode;

  const _PhoneInputField({
    required this.controller,
    required this.placeholder,
    required this.countryCode,
  });

  static const Color kCyan = Color(0xFF00C8E8);
  static const Color kCard = Color(0xFF0D1822);
  static const Color kBorder = Color(0xFF1A3040);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: kBorder, width: 1.5),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Text(
            countryCode,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: kBorder,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: const TextStyle(
                  color: Color(0xFF4A6070),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              cursorColor: kCyan,
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

// ─── Terms Text ────────────────────────────────────────────────────────────

class _TermsText extends StatelessWidget {
  final _Lang lang;

  static const Color kCyan = Color(0xFF00C8E8);

  const _TermsText({required this.lang});

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Color(0xFF8AA0B0), fontSize: 12.5),
        children: [
          TextSpan(text: lang.terms),
          TextSpan(
            text: lang.termsLink,
            style: const TextStyle(
              color: kCyan,
              decoration: TextDecoration.underline,
              decorationColor: kCyan,
            ),
          ),
          const TextSpan(text: ' & '),
          TextSpan(
            text: lang.privacyLink,
            style: const TextStyle(
              color: kCyan,
              decoration: TextDecoration.underline,
              decorationColor: kCyan,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OTP Button ────────────────────────────────────────────────────────────

class _OtpButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final bool isLoading;

  const _OtpButton({
    required this.onPressed,
    required this.label,
    this.isLoading = false,
  });

  @override
  State<_OtpButton> createState() => _OtpButtonState();
}

class _OtpButtonState extends State<_OtpButton> {
  bool _pressed = false;

  static const Color kCyan = Color(0xFF00C8E8);
  static const Color kCyanDark = Color(0xFF0099BB);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kCyan, kCyanDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: kCyan.withOpacity(0.35),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isLoading
                  ? const SizedBox(
                      key: ValueKey('loader'),
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      widget.label,
                      key: ValueKey(widget.label),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
