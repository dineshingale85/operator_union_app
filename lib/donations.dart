import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:convert';
import 'api_client.dart';
import 'auth_storage.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  int? _selectedAmount;
  bool _isSubmitting = false;
  late Razorpay _razorpay;
  String? _lastOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final authToken = await AuthStorage.getAuthToken();
      if (authToken == null) {
        throw Exception('Session expired. Please login again.');
      }

      debugPrint('=== Payment Success Callback ===');
      debugPrint('Payment ID: ${response.paymentId}');
      debugPrint('Order ID: ${response.orderId}');
      debugPrint('Signature: ${response.signature}');
      debugPrint('==============================');

      final api = ApiClient();
      final result = await api.postJson('/api/payment/success', {
        'razorpay_payment_id': response.paymentId,
        'razorpay_order_id': response.orderId,
        'razorpay_signature': response.signature,
      }, bearer: authToken);

      debugPrint('Backend Response: $result');

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Donation successful! Thank you for your contribution.',
            ),
            backgroundColor: Color(0xFF16A34A),
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      } else {
        throw Exception(result['message'] ?? 'Payment verification failed');
      }
    } catch (e) {
      debugPrint('Payment success handler error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment verification failed: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    try {
      final authToken = await AuthStorage.getAuthToken();
      if (authToken == null || _lastOrderId == null) return;

      final api = ApiClient();
      await api.postJson('/api/payment/failure', {
        'razorpay_order_id': _lastOrderId!,
        'error_code': response.code.toString(),
        'error_description': response.message ?? 'Payment failed',
      }, bearer: authToken);
    } catch (e) {
      debugPrint('Error reporting payment failure: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message ?? "Unknown error"}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External wallet selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet: ${response.walletName}'),
        backgroundColor: const Color(0xFF3843A8),
      ),
    );
  }

  void _selectAmount(int amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toString();
    });
  }

  void _selectCustom() {
    setState(() {
      _selectedAmount = null;
      _amountController.clear();
    });
  }

  void _openRazorpay({
    required int amount,
    required int donationId,
    required String orderId,
    required String receiptNumber,
    required String description,
    String? razorpayKey,
  }) {
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid order ID. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Track order ID for failure callback
    _lastOrderId = orderId;

    // Use key from backend if available, otherwise fallback to hardcoded test key
    final key = razorpayKey ?? 'rzp_test_xG557fjPYwxAjx';

    var options = {
      'key': key,
      'amount': amount * 100, // Amount in paise (multiply by 100)
      'currency': 'INR',
      'name': "Operator's Union",
      'description': description,
      'order_id': orderId, // Proper Razorpay order ID from backend
      'prefill': {
        'contact': '', // User phone if available
        'email': '', // User email if available
      },
      'theme': {'color': '#FF9A3E'},
      'notes': {
        'donation_id': donationId.toString(),
        'receipt_number': receiptNumber,
      },
    };

    debugPrint('=== Razorpay Donation Debug ===');
    debugPrint('Key: $key');
    debugPrint('Order ID: $orderId');
    debugPrint('Amount: ${amount * 100} paise ($amount INR)');
    debugPrint('Options: $options');
    debugPrint('============================');

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open payment gateway: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final authToken = await AuthStorage.getAuthToken();
        debugPrint('Auth token: ${authToken?.substring(0, 20)}...');

        if (authToken == null || authToken.isEmpty) {
          throw Exception('Please login again');
        }

        final amount = int.parse(_amountController.text);
        final description = 'Donation to M.S.E. Operators Union';

        final api = ApiClient();
        final response = await api.postJson('/api/donations', {
          'amount': amount,
          'description': description,
        }, bearer: authToken);

        debugPrint('Donation response: $response');

        if (!mounted) return;

        if (response['success'] == true) {
          final donationData = response['data'] as Map<String, dynamic>;
          final donationId = donationData['id'];
          final receiptNumber = donationData['receipt_number'];
          final orderId = donationData['razorpay_order_id'] as String? ?? '';
          final razorpayKey = donationData['razorpay_key'] as String?;

          if (orderId.isEmpty) {
            throw Exception('Backend did not return a valid Razorpay order ID');
          }

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Donation created! Receipt: $receiptNumber\nOpening payment gateway...',
              ),
              backgroundColor: const Color(0xFF16A34A),
              duration: const Duration(seconds: 2),
            ),
          );

          // Reset submitting state before opening Razorpay
          setState(() {
            _isSubmitting = false;
          });

          // Open Razorpay payment gateway
          _openRazorpay(
            amount: amount,
            donationId: donationId,
            orderId: orderId,
            receiptNumber: receiptNumber,
            description: description,
            razorpayKey: razorpayKey,
          );
        } else {
          throw Exception(response['message'] ?? 'Failed to create donation');
        }
      } catch (e) {
        if (!mounted) return;

        debugPrint('Full donation error: $e');

        // Parse backend error message
        String errorMessage = 'Failed to create donation';

        if (e.toString().contains('HTTP 500')) {
          errorMessage =
              'Server error. Please check:\n• Razorpay credentials configured in backend\n• Database connection\n• Backend logs for details';
        } else if (e.toString().contains('HTTP 401') ||
            e.toString().contains('Unauthorized')) {
          errorMessage = 'Session expired. Please login again';
        } else if (e.toString().contains('HTTP 422')) {
          // Validation error - try to extract message
          final errorStr = e.toString();
          if (errorStr.contains('"message"')) {
            try {
              final jsonStart = errorStr.indexOf('{');
              if (jsonStart != -1) {
                final jsonStr = errorStr.substring(jsonStart);
                final jsonEnd = jsonStr.lastIndexOf('}');
                if (jsonEnd != -1) {
                  final json = jsonDecode(jsonStr.substring(0, jsonEnd + 1));
                  errorMessage = json['message'] ?? errorMessage;
                }
              }
            } catch (_) {
              errorMessage = 'Validation failed. Please check your input.';
            }
          }
        } else if (e.toString().contains('Please login again')) {
          errorMessage = 'Session expired. Please login again';
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: const Color(0xFFFF9A3E),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFFF9A3E),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _DonationHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _InfoCard(),
                    const SizedBox(height: 16),
                    _DonationForm(
                      formKey: _formKey,
                      amountController: _amountController,
                      selectedAmount: _selectedAmount,
                      onSelectAmount: _selectAmount,
                      onSelectCustom: _selectCustom,
                      onSubmit: _handleSubmit,
                      isSubmitting: _isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    _NoteCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonationHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9A3E), Color(0xFFFFC56F)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F1F2937),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '🙏 Make a Donation',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Support our community initiatives and help us make a difference together',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141F2937),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9A3E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.monetization_on_outlined,
              color: Color(0xFFFF9A3E),
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Why Donate?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your generous donations help us organize community events, support members in need, and strengthen our union\'s initiatives for the betterment of all members.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController amountController;
  final int? selectedAmount;
  final Function(int) onSelectAmount;
  final VoidCallback onSelectCustom;
  final VoidCallback onSubmit;
  final bool isSubmitting;

  const _DonationForm({
    required this.formKey,
    required this.amountController,
    required this.selectedAmount,
    required this.onSelectAmount,
    required this.onSelectCustom,
    required this.onSubmit,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x141F2937),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.favorite, color: Color(0xFFFF9A3E), size: 20),
                SizedBox(width: 8),
                Text(
                  'Donation Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Donation Amount *',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            _AmountOptions(
              selectedAmount: selectedAmount,
              onSelectAmount: onSelectAmount,
              onSelectCustom: onSelectCustom,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Enter amount (₹)',
                prefixText: '₹ ',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF3843A8),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFEF4444)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFEF4444),
                    width: 2,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a donation amount';
                }
                final amount = int.tryParse(value);
                if (amount == null || amount < 100) {
                  return 'Minimum donation amount is ₹100';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9A3E),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE5E7EB),
                  disabledForegroundColor: const Color(0xFF9CA3AF),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: const Color(0xFFFF9A3E).withOpacity(0.3),
                ),
                child: isSubmitting
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.monetization_on_outlined, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Proceed to Payment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountOptions extends StatelessWidget {
  final int? selectedAmount;
  final Function(int) onSelectAmount;
  final VoidCallback onSelectCustom;

  const _AmountOptions({
    required this.selectedAmount,
    required this.onSelectAmount,
    required this.onSelectCustom,
  });

  @override
  Widget build(BuildContext context) {
    final amounts = [500, 1000, 2000, 5000, 10000];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: amounts.length + 1,
          itemBuilder: (context, index) {
            if (index < amounts.length) {
              final amount = amounts[index];
              final isSelected = selectedAmount == amount;
              return _AmountButton(
                label: '₹${_formatAmount(amount)}',
                isSelected: isSelected,
                onTap: () => onSelectAmount(amount),
              );
            } else {
              final isSelected = selectedAmount == null;
              return _AmountButton(
                label: 'Custom',
                isSelected: isSelected,
                onTap: onSelectCustom,
              );
            }
          },
        ),
      ],
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return amount.toString();
  }
}

class _AmountButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AmountButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3843A8) : Colors.white,
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3843A8)
                : const Color(0xFFE5E7EB),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F8),
        border: const Border(
          left: BorderSide(color: Color(0xFF3843A8), width: 4),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: const TextSpan(
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.5),
          children: [
            TextSpan(
              text: '📝 Note: ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text:
                  'All donations are processed through a secure payment gateway. You will receive a confirmation receipt via email after successful payment. Donations are tax-exempt as per applicable laws.',
            ),
          ],
        ),
      ),
    );
  }
}
