import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/foundation.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> payment;

  const PaymentPage({super.key, required this.payment});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late Razorpay _razorpay;

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
    super.dispose();
  }

  void _openCheckout() {
    final payment = widget.payment;
    final amount = payment['amount'];
    final currency = (payment['currency'] as String?) ?? 'INR';
    final orderId = payment['razorpay_order_id'] as String?;
    final receipt = payment['receipt_number'] as String?;
    final razorpayKey = payment['razorpay_key'] as String?;

    // Razorpay expects amount in paise (INR minor units).
    final doubleAmount = double.tryParse(amount.toString()) ?? 0;
    final intAmount = (doubleAmount * 100).round();

    if (orderId == null || orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid order. Please try again.')),
      );
      return;
    }

    // Use key from backend if available, otherwise fallback to hardcoded test key
    final key = razorpayKey ?? 'rzp_test_xG557fjPYwxAjx';

    final options = {
      'key': key,
      'amount': intAmount,
      'currency': currency,
      'name': "Operator's Union",
      'description': 'Membership Fee Payment',
      'order_id': orderId, // Proper Razorpay order ID from backend
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': '#FF9A3E'},
      'notes': {'receipt_number': receipt ?? ''},
    };

    debugPrint('=== Razorpay Payment Debug ===');
    debugPrint('Key: $key');
    debugPrint('Order ID: $orderId');
    debugPrint('Amount: $intAmount paise ($doubleAmount INR)');
    debugPrint('Options: $options');
    debugPrint('============================');

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open payment gateway: $e')),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment successful. Registration completed.'),
      ),
    );
    // TODO: Optionally call backend to confirm payment status and then
    // navigate to dashboard.
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External wallet selected: ${response.walletName}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    final amount = payment['amount'];
    final currency = payment['currency'] ?? 'INR';
    final status = payment['status'] ?? 'pending';
    final receipt = payment['receipt_number'] ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership Payment'),
        backgroundColor: const Color(0xFF3843A8),
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF3843A8),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'Amount Due',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              '$currency $amount',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Text('Receipt Number: $receipt'),
            const SizedBox(height: 8),
            Text('Status: ${status.toString().toUpperCase()}'),
            const Spacer(),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _openCheckout,
                child: const Text(
                  'Pay with Razorpay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
