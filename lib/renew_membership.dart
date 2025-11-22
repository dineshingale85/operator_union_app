import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'api_client.dart';
import 'auth_storage.dart';

class RenewMembershipPage extends StatefulWidget {
  const RenewMembershipPage({super.key});

  @override
  State<RenewMembershipPage> createState() => _RenewMembershipPageState();
}

class _RenewMembershipPageState extends State<RenewMembershipPage> {
  bool _isLoading = false;
  bool _isLoadingFees = true;
  String? _errorMessage;
  Map<String, dynamic>? _paymentData;
  Map<String, dynamic>? _membershipFee;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadMembershipFees();
  }

  Future<void> _loadMembershipFees() async {
    try {
      final authToken = await AuthStorage.getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoadingFees = false;
        });
        return;
      }

      final api = ApiClient();
      final response = await api.getJson(
        '/api/settings/membership-fee',
        bearer: authToken,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _membershipFee = response['membership_fee'] as Map<String, dynamic>?;
          _isLoadingFees = false;
        });
      } else {
        setState(() {
          _isLoadingFees = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFees = false;
      });
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _initiateRenewal() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authToken = await AuthStorage.getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Please login again');
      }

      final api = ApiClient();
      final response = await api.postJson(
        '/api/renew-membership',
        {},
        bearer: authToken,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        final payment = response['payment'] as Map<String, dynamic>;
        final membershipFee =
            response['membership_fee'] as Map<String, dynamic>?;
        setState(() {
          _paymentData = payment;
          _membershipFee = membershipFee;
          _isLoading = false;
        });
        _openRazorpay(payment);
      } else {
        throw Exception(
          response['message'] ?? 'Failed to create renewal payment',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _openRazorpay(Map<String, dynamic> payment) {
    final orderId = payment['razorpay_order_id'];
    final amount = payment['amount'];
    final razorpayKey = payment['razorpay_key'];

    if (orderId == null || orderId.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid payment order. Please try again.';
      });
      return;
    }

    var options = {
      'key': razorpayKey ?? 'rzp_test_xG557fjPYwxAjx',
      'order_id': orderId,
      'amount': amount * 100,
      'name': "Operator's Union",
      'description': payment['description'] ?? 'Membership Renewal Payment',
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#3843A8'},
    };

    debugPrint('=== Razorpay Renewal Debug ===');
    debugPrint('Key: ${razorpayKey ?? 'rzp_test_Rba3FroIHoMreW'}');
    debugPrint('Order ID: $orderId');
    debugPrint('Amount: ${amount * 100} paise ($amount INR)');
    debugPrint('Options: $options');
    debugPrint('============================');

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to open payment gateway: ${e.toString()}';
      });
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final authToken = await AuthStorage.getAuthToken();
      if (authToken == null) {
        throw Exception('Session expired. Please login again.');
      }

      final api = ApiClient();
      final result = await api.postJson('/api/payment/success', {
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': response.orderId,
        'razorpay_signature': response.signature,
      }, bearer: authToken);

      if (!mounted) return;

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        throw Exception(result['message'] ?? 'Payment verification failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Payment verification failed: ${e.toString()}';
      });
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    try {
      final authToken = await AuthStorage.getAuthToken();
      if (authToken == null) return;

      final orderId = _paymentData?['razorpay_order_id'];
      if (orderId != null) {
        final api = ApiClient();
        await api.postJson('/api/payment/failure', {
          'razorpay_order_id': orderId,
          'error_code': response.code.toString(),
          'error_description': response.message ?? 'Payment failed',
        }, bearer: authToken);
      }

      if (!mounted) return;
      setState(() {
        _errorMessage = response.message ?? 'Payment failed. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Payment failed: ${e.toString()}';
      });
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    setState(() {
      _errorMessage = 'External wallet not supported';
    });
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF059669), size: 64),
            SizedBox(height: 16),
            Text(
              'Renewal Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your membership has been renewed successfully. Thank you!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous page
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3843A8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: const Text('Renew Membership'),
        backgroundColor: const Color(0xFF3843A8),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF3843A8),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3843A8), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A3843A8),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.card_membership,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Membership Renewal',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Continue your journey with us',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  if (_membershipFee != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Renewal Fee: ',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          Text(
                            '₹${_membershipFee!['membershipfee']}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_isLoadingFees) ...[
                    const SizedBox(height: 16),
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Fee Breakdown Card
            if (_membershipFee != null)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Color(0xFF3843A8),
                          size: 24,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Fee Breakdown',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildFeeRow(
                      'Membership Fee',
                      _membershipFee!['membershipfee'],
                    ),
                    const Divider(height: 24),
                    _buildFeeRow(
                      'Registration Fee',
                      _membershipFee!['registration_fee'],
                    ),
                    const Divider(height: 24),
                    _buildFeeRow(
                      'Monthly Subscription',
                      _membershipFee!['monthly_subscription'],
                    ),
                    const Divider(height: 24),
                    _buildFeeRow(
                      'Organization Funds',
                      _membershipFee!['organization_funds'],
                    ),
                    const Divider(height: 24),
                    _buildFeeRow(
                      'Transaction Fee',
                      '${_membershipFee!['transaction_percentage']}%',
                      isPercentage: true,
                    ),
                  ],
                ),
              ),
            if (_membershipFee != null) const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFF3843A8),
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Renewal Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoItem(
                    Icons.check_circle_outline,
                    'Extend Your Membership',
                    'Continue enjoying all member benefits',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    Icons.security,
                    'Secure Payment',
                    'Your payment is processed securely via Razorpay',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem(
                    Icons.receipt_long,
                    'Instant Confirmation',
                    'Get immediate renewal confirmation',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Renew Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _initiateRenewal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3843A8),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
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
                        'Proceed to Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Help Text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.help_outline, color: Color(0xFFD97706), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Only active members can renew their membership',
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
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

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF3843A8)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeeRow(
    String label,
    dynamic value, {
    bool isPercentage = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          isPercentage ? value.toString() : '₹${value}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}
