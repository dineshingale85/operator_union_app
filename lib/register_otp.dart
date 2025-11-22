import 'package:flutter/material.dart';
import 'api_client.dart';
import 'dashboard.dart';
import 'payment_page.dart';

class RegisterOtpPage extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const RegisterOtpPage({super.key, required this.registrationData});

  @override
  State<RegisterOtpPage> createState() => _RegisterOtpPageState();
}

class _RegisterOtpPageState extends State<RegisterOtpPage> {
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (_) => FocusNode(debugLabel: 'reg_otp'),
  );
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  bool _isLoading = false;

  bool get _isComplete =>
      _controllers.every((c) => c.text.trim().isNotEmpty && c.text.length == 1);

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  Future<void> _submitOtp() async {
    if (!_isComplete || _isLoading) return;

    final otp = _controllers.map((c) => c.text).join();
    setState(() {
      _isLoading = true;
    });

    try {
      final api = ApiClient();
      final payload = Map<String, dynamic>.from(widget.registrationData);
      payload['otp'] = otp;

      final response = await api.postJson('/api/register/verify-otp', payload);

      if (response['success'] != true) {
        String message =
            response['message'] as String? ??
            'Registration verification failed';
        final errors = response['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstKey = errors.keys.first;
          final firstList = errors[firstKey];
          if (firstList is List && firstList.isNotEmpty) {
            message = firstList.first.toString();
          }
        }
        throw Exception(message);
      }

      if (!mounted) return;

      // After successful OTP verification, create membership payment for this member.
      final memberMap = response['member'] as Map<String, dynamic>?;
      final memberId = memberMap != null ? memberMap['id'] as int? : null;
      Map<String, dynamic>? payment;
      if (memberId != null) {
        final paymentResp = await api.postJson(
          '/api/members/$memberId/membership-payment',
          <String, dynamic>{},
        );

        if (paymentResp['success'] != true) {
          final msg =
              paymentResp['message'] as String? ??
              'Membership payment could not be created.';
          throw Exception(msg);
        }

        payment = paymentResp['payment'] as Map<String, dynamic>?;
      }

      if (!mounted) return;

      if (payment != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => PaymentPage(payment: payment!)),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  _LogoBox(),
                  SizedBox(height: 24),
                  Text(
                    'Verify registration',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Enter the 6-digit code we sent for registration',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 44,
                        height: 56,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          decoration: const InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                              borderSide: BorderSide(
                                color: Color(0xFFDDDDDD),
                                width: 1.5,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                              borderSide: BorderSide(
                                color: Color(0xFFDDDDDD),
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                              borderSide: BorderSide(
                                color: Colors.black,
                                width: 1.5,
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          onChanged: (v) => _onChanged(index, v),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Check your email or SMS for the registration code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isComplete && !_isLoading ? _submitOtp : null,
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
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Verify & Continue',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              const _FooterText(),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoBox extends StatelessWidget {
  const _LogoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC43D5A), Color(0xFFE69B3A)],
        ),
      ),
    );
  }
}

class _FooterText extends StatelessWidget {
  const _FooterText();

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
            TextSpan(
              text: 'By continuing, you agree to our ',
              style: baseStyle,
            ),
            TextSpan(text: 'Terms', style: linkStyle),
            TextSpan(text: ' and ', style: baseStyle),
            TextSpan(text: 'Privacy Policy', style: linkStyle),
          ],
        ),
      ),
    );
  }
}
