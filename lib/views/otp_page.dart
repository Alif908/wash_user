import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wash_user/views/home.dart';
import 'package:wash_user/services/api_service.dart';

class OtpPage extends StatefulWidget {
  final String phoneNumber; // display only e.g. "+91 7736193302"
  final String mobileNumber; // raw 10 digits for API e.g. "7736193302"
  final String? debugOtp; // dev only — remove in production

  const OtpPage({
    super.key,
    required this.phoneNumber,
    required this.mobileNumber,
    this.debugOtp,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> with SingleTickerProviderStateMixin {
  // 4 controllers + 4 focus nodes for each OTP box
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  bool _isLoading = false;

  // ── Colors ──────────────────────────────────────────────
  static const Color kCyan = Color(0xFF00C8E8);
  static const Color kCyanDark = Color(0xFF0099BB);
  static const Color kBg = Color(0xFF050A0F);
  static const Color kCard = Color(0xFF0D1822);
  static const Color kBorder = Color(0xFF1A3040);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();

    // Auto-focus first box after frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();

      // ── DEV ONLY: professional sequential OTP auto-fill ─
      if (widget.debugOtp != null && widget.debugOtp!.length == 4) {
        debugPrint('========================================');
        debugPrint('🔑 OTP: ${widget.debugOtp}');
        debugPrint('========================================');

        // Fill each box one by one with a small delay — looks like typing
        for (int i = 0; i < 4; i++) {
          Future.delayed(Duration(milliseconds: 120 * (i + 1)), () {
            if (!mounted) return;
            _controllers[i].text = widget.debugOtp![i];
            if (i < 3) {
              _focusNodes[i + 1].requestFocus();
            } else {
              _focusNodes[i].unfocus();
            }
            setState(() {});
          });
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  // Called on every keystroke in an OTP box
  void _onOtpChanged(String value, int index) {
    if (value.length == 1) {
      // Move forward
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last box filled — dismiss keyboard
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      // Backspace — move back
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {}); // rebuild to update box fill state
  }

  String get _otpValue => _controllers.map((c) => c.text).join();

  void _onNext() async {
    if (_otpValue.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 4-digit OTP'),
          backgroundColor: Color.fromARGB(255, 122, 161, 190),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.verifyOtp(widget.mobileNumber, _otpValue);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Home()),
      );
    } else {
      // Clear OTP boxes on failure so user can re-enter
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ?? 'Invalid OTP. Please try again.',
          ),
          backgroundColor: const Color.fromARGB(255, 122, 161, 190),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
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

                              // ── Back button ──────────────────────
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),

                              const SizedBox(height: 28),

                              // ── Logo ─────────────────────────────
                              _Logo(),

                              const SizedBox(height: 28),

                              // ── Title ────────────────────────────
                              const Text(
                                'OTP Sent!',
                                style: TextStyle(
                                  color: kCyan,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ── Subtitle ─────────────────────────
                              Text(
                                'A verification OTP has been sent to\n${widget.phoneNumber}',
                                style: const TextStyle(
                                  color: Color(0xFFB0C8D8),
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),

                              const SizedBox(height: 36),

                              // ── OTP Boxes ────────────────────────
                              Row(
                                children: List.generate(4, (i) {
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      right: i < 3 ? 16 : 0,
                                    ),
                                    child: _OtpBox(
                                      controller: _controllers[i],
                                      focusNode: _focusNodes[i],
                                      onChanged: (v) => _onOtpChanged(v, i),
                                    ),
                                  );
                                }),
                              ),

                              const Spacer(),

                              // ── Resend row ───────────────────────
                              Center(
                                child: RichText(
                                  text: const TextSpan(
                                    style: TextStyle(
                                      color: Color(0xFF8AA0B0),
                                      fontSize: 13,
                                    ),
                                    children: [
                                      TextSpan(text: "Didn't receive OTP? "),
                                      TextSpan(
                                        text: 'Resend',
                                        style: TextStyle(
                                          color: kCyan,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: kCyan,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // ── NEXT Button ──────────────────────
                              _NextButton(
                                onPressed: _isLoading ? () {} : _onNext,
                                isLoading: _isLoading,
                              ),

                              const SizedBox(height: 28),
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

// ─── Logo ──────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  static const Color kCyan = Color(0xFF00C8E8);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: kCyan, width: 2.5),
          ),
          child: const Center(
            child: Icon(Icons.water_drop_rounded, color: kCyan, size: 36),
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

// ─── OTP Box ───────────────────────────────────────────────────────────────

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  static const Color kCyan = Color(0xFF00C8E8);
  static const Color kCard = Color(0xFF0D1822);
  static const Color kBorder = Color(0xFF1A3040);

  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool filled = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focused
              ? kCyan
              : filled
              ? kCyan.withOpacity(0.5)
              : kBorder,
          width: _focused ? 2.0 : 1.5,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: kCyan.withOpacity(0.18),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Center(
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          decoration: const InputDecoration(
            counterText: '', // hide the "0/1" counter
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          cursorColor: kCyan,
          cursorWidth: 2,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

// ─── Next Button ───────────────────────────────────────────────────────────

class _NextButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _NextButton({required this.onPressed, this.isLoading = false});

  @override
  State<_NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<_NextButton> {
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
                  : const Text(
                      'NEXT',
                      key: ValueKey('text'),
                      style: TextStyle(
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
