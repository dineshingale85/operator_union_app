import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';
import 'auth_storage.dart';

class PaymentHistoryPage extends StatefulWidget {
  final int memberId;

  const PaymentHistoryPage({super.key, required this.memberId});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadPaymentHistory();
  }

  Future<void> _loadPaymentHistory() async {
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
      final response = await api.getJson(
        '/api/payment-history/${widget.memberId}',
        bearer: authToken,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _data = response['data'] as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        throw Exception(
          response['message'] ?? 'Failed to load payment history',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: const Text('Payment History'),
        backgroundColor: const Color(0xFF3843A8),
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF3843A8),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _ErrorView(message: _errorMessage!, onRetry: _loadPaymentHistory)
          : _data != null
          ? RefreshIndicator(
              onRefresh: _loadPaymentHistory,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(summary: _data!['summary']),
                    const SizedBox(height: 24),
                    const Text(
                      'Transaction History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PaymentsList(
                      payments: _data!['payments'] as List<dynamic>,
                    ),
                  ],
                ),
              ),
            )
          : const Center(child: Text('No data available')),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3843A8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Icons.analytics_outlined,
                color: Color(0xFF3843A8),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Payment Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.receipt_long,
                  label: 'Total Transactions',
                  value: summary['total_transactions'].toString(),
                  color: const Color(0xFF3843A8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.currency_rupee,
                  label: 'Total Paid',
                  value: '₹${_formatAmount(summary['total_paid'])}',
                  color: const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  icon: Icons.card_membership,
                  label: 'Membership Payments',
                  value: summary['total_membership_paid']?.toString() ?? '0',
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryItem(
                  icon: Icons.volunteer_activism,
                  label: 'Donation Payments',
                  value: summary['total_donation_paid']?.toString() ?? '0',
                  color: const Color(0xFFEA580C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0';
    final numAmount = double.tryParse(amount.toString()) ?? 0;
    final formatter = NumberFormat('#,##,##0.00', 'en_IN');
    return formatter.format(numAmount);
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  final List<dynamic> payments;

  const _PaymentsList({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: const [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Color(0xFFD1D5DB),
            ),
            SizedBox(height: 16),
            Text(
              'No payment history',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: payments.map((payment) {
        return _PaymentCard(payment: payment as Map<String, dynamic>);
      }).toList(),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final status = payment['status'] as String? ?? 'pending';
    final isCompleted = status == 'completed';
    final type = payment['type'] as String? ?? 'payment';
    final formattedType = _formatPaymentType(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFFD1FAE5)
              : const Color(0xFFFEF3C7),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFFD1FAE5)
                            : const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getPaymentIcon(type),
                        color: isCompleted
                            ? const Color(0xFF059669)
                            : const Color(0xFFF59E0B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formattedType,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payment['receipt_number'] ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          payment['formatted_amount'] ?? '₹0',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isCompleted
                                ? const Color(0xFF059669)
                                : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _StatusBadge(status: status),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _DetailRow(
                  icon: Icons.description,
                  label: 'Description',
                  value: payment['description'] ?? 'N/A',
                ),
                if (payment['payment_method'] != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.payment,
                    label: 'Method',
                    value: _formatPaymentMethod(
                      payment['payment_method'] as String,
                    ),
                  ),
                ],
                if (payment['payment_date'] != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.calendar_today,
                    label: 'Payment Date',
                    value: _formatDate(payment['payment_date'] as String),
                  ),
                ],
                if (payment['razorpay_payment_id'] != null) ...[
                  const SizedBox(height: 8),
                  _DetailRow(
                    icon: Icons.confirmation_number,
                    label: 'Payment ID',
                    value: payment['razorpay_payment_id'] as String,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'membership_fee':
        return Icons.card_membership;
      case 'donation':
        return Icons.volunteer_activism;
      case 'subscription':
        return Icons.subscriptions;
      default:
        return Icons.payment;
    }
  }

  String _formatPaymentType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  String _formatPaymentMethod(String method) {
    // Show "Online" for razorpay, otherwise capitalize the method
    if (method.toLowerCase() == 'razorpay') {
      return 'Online';
    }
    return method[0].toUpperCase() + method.substring(1).toLowerCase();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, hh:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'completed';
    final isPending = status == 'pending';
    final isFailed = status == 'failed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFFD1FAE5)
            : isPending
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle
                : isPending
                ? Icons.pending
                : Icons.cancel,
            size: 14,
            color: isCompleted
                ? const Color(0xFF059669)
                : isPending
                ? const Color(0xFFF59E0B)
                : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 4),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isCompleted
                  ? const Color(0xFF059669)
                  : isPending
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
