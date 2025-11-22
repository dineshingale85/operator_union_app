import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'register.dart';
import 'api_client.dart';
import 'otp.dart';
import 'auth_storage.dart';

class LoginFramePage extends StatelessWidget {
  const LoginFramePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(child: const _LoginScreen()),
    );
  }
}

class _LoginScreen extends StatefulWidget {
  const _LoginScreen({super.key});

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isButtonEnabled = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final clean = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _isButtonEnabled = clean.length >= 9;
      _errorMessage = null; // Clear error when user types
    });
  }

  Future<void> _handleContinue() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 9) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ApiClient();
      final response = await api.postJson('/api/login', {'mobile': phone});

      if (!mounted) return;

      if (response['success'] == true) {
        // Save the OTP token for verification
        final otpToken =
            response['otp_token'] as String? ??
            response['token'] as String? ??
            '';
        if (otpToken.isNotEmpty) {
          await AuthStorage.saveOtpToken(otpToken);
        }

        // Navigate to OTP page
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const OtpPage()));
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ??
              'Please enter a valid mobile number.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Please enter a valid mobile number.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top: logo, title, subtitle
          Flexible(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _LogoBox(),
                SizedBox(height: 12),
                Text(
                  'महाराष्ट्र राज्य विद्युत ऑपरेटर्स संघटना, महाराष्ट्र राज्य.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 133, 25, 25),
                  ),
                ),
                SizedBox(height: 4),
              ],
            ),
          ),
          // Middle: phone input and button
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Phone number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _PhoneInputField(
                controller: _phoneController,
                errorMessage: _errorMessage,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isButtonEnabled && !_isLoading)
                      ? _handleContinue
                      : null,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith((
                      states,
                    ) {
                      if (states.contains(MaterialState.disabled)) {
                        return const Color(0xFFCCCCCC);
                      }
                      if (states.contains(MaterialState.pressed)) {
                        return const Color(0xFF333333);
                      }
                      return Colors.black;
                    }),
                    foregroundColor: MaterialStateProperty.all<Color>(
                      Colors.white,
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    elevation: MaterialStateProperty.all(0),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF666666),
                    ),
                    children: [
                      const TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Sign Up',
                        style: const TextStyle(
                          color: Color(0xFF3843A8),
                          fontWeight: FontWeight.w600,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Footer
          const _FooterText(),
        ],
      ),
    );
  }
}

class _LogoBox extends StatelessWidget {
  const _LogoBox({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 170,
      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
    );
  }
}

class _PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorMessage;

  const _PhoneInputField({
    super.key,
    required this.controller,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              hintText: '12345 67890',
              hintStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: Color(0xFFAAAAAA),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFDDDDDD),
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFDDDDDD),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? const Color(0xFFEF4444) : Colors.black,
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ),
        if (hasError) const SizedBox(height: 6),
        if (hasError)
          Text(
            errorMessage!,
            style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
          ),
      ],
    );
  }
}

class _FooterText extends StatelessWidget {
  const _FooterText({super.key});

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(fontSize: 14, color: Color(0xFF888888));
    const linkStyle = TextStyle(
      fontSize: 14,
      color: Colors.black,
      fontWeight: FontWeight.w500,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE), width: 1)),
      ),
      alignment: Alignment.center,
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          children: [
            TextSpan(text: 'नोंदणी क्रमांक AWB/3071-2017. ', style: baseStyle),
          ],
        ),
      ),
    );
  }
}
