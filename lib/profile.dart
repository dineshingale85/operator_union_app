import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Used inside DashboardPage tabs; dashboard owns bottom navigation.
import 'api_client.dart';
import 'auth_storage.dart';
import 'login.dart';
import 'payment_history.dart';
import 'renew_membership.dart';
import 'privacy_policy.dart';
import 'delete_account.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _membershipStatus;
  List<Map<String, dynamic>> _payments = const [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authToken = await AuthStorage.getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        throw Exception('Missing auth token, please login again');
      }

      final api = ApiClient();
      final resp = await api.getJson('/api/profile', bearer: authToken);

      if (resp['success'] == true) {
        final member = resp['member'] as Map?;
        if (member == null) {
          throw Exception('Invalid profile response');
        }
        setState(() {
          _member = Map<String, dynamic>.from(member as Map);
          _membershipStatus = resp['membership_status'] is Map
              ? Map<String, dynamic>.from(resp['membership_status'] as Map)
              : null;
          final payments = (resp['payments'] as List?) ?? [];
          _payments = payments
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          _isLoading = false;
        });
      } else {
        throw Exception(
          resp['message']?.toString() ?? 'Failed to load profile',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        children: [
          AppBar(
            toolbarHeight: 0,
            backgroundColor: const Color(0xFF3843A8),
            elevation: 0,
            automaticallyImplyLeading: false,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Color(0xFF3843A8),
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      );
    }

    if (_error != null) {
      return Column(
        children: [
          AppBar(
            toolbarHeight: 0,
            backgroundColor: const Color(0xFF3843A8),
            elevation: 0,
            automaticallyImplyLeading: false,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Color(0xFF3843A8),
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Failed to load profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final member = _member ?? const {};
    final name = member['name']?.toString() ?? 'Member';
    final initials = name.isNotEmpty
        ? name
              .trim()
              .split(RegExp(r'\s+'))
              .where((p) => p.isNotEmpty)
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join()
        : 'M';
    final memberId = member['cpf_number']?.toString() ?? '-';
    final mobile = member['mobile']?.toString() ?? '';
    final email = member['email']?.toString() ?? '';
    final circle = member['circle']?.toString() ?? '';
    final zone = member['zone']?.toString() ?? '';
    final designation = member['designation']?.toString() ?? '';

    // Format date of birth to D-M-Y
    String dob = '';
    final dobRaw = member['date_of_birth']?.toString() ?? '';
    if (dobRaw.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(dobRaw.split('T').first);
        dob = '${parsedDate.day}-${parsedDate.month}-${parsedDate.year}';
      } catch (_) {
        dob = dobRaw.split('T').first;
      }
    }

    // Format anniversary date to D-M-Y
    String anniversary = '';
    final anniversaryRaw = member['anniversary_date']?.toString() ?? '';
    if (anniversaryRaw.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(anniversaryRaw.split('T').first);
        anniversary =
            '${parsedDate.day}-${parsedDate.month}-${parsedDate.year}';
      } catch (_) {
        anniversary = anniversaryRaw.split('T').first;
      }
    }

    final status = member['status']?.toString() ?? '';

    String? membershipExpiresText;
    if (_membershipStatus != null) {
      final ms = _membershipStatus!;
      membershipExpiresText = ms['expires_on']?.toString();
    }

    return Column(
      children: [
        AppBar(
          toolbarHeight: 0,
          backgroundColor: const Color(0xFF3843A8),
          elevation: 0,
          automaticallyImplyLeading: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Color(0xFF3843A8),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 88),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHeader(
                  initials: initials,
                  name: name,
                  memberId: memberId,
                  status: status,
                ),
                const SizedBox(height: 12),
                _ContactCard(
                  mobile: mobile,
                  email: email,
                  circle: circle,
                  zone: zone,
                ),
                _MembershipCard(
                  designation: designation,
                  memberSince: membershipExpiresText == null
                      ? ''
                      : '', // placeholder
                  membershipExpires: membershipExpiresText ?? '-',
                ),
                _ImportantDatesCard(dob: dob, anniversary: anniversary),
                const SizedBox(height: 4),
                _QuickActionsSection(memberId: member['id'] as int? ?? 0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String memberId;
  final String status;

  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.memberId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3843A8), Color(0xFF4F46E5)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1F1F2937),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.15),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Member ID: $memberId',
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status.isEmpty ? 'Member' : status.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String mobile;
  final String email;
  final String circle;
  final String zone;

  const _ContactCard({
    required this.mobile,
    required this.email,
    required this.circle,
    required this.zone,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      title: 'Contact Information',
      icon: Icons.person_outline,
      child: Column(
        children: [
          if (mobile.isNotEmpty)
            _InfoRow(icon: Icons.phone_outlined, text: mobile),
          if (email.isNotEmpty)
            _InfoRow(icon: Icons.email_outlined, text: email),
          if (circle.isNotEmpty || zone.isNotEmpty)
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: [circle, zone].where((e) => e.isNotEmpty).join(', '),
            ),
        ],
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final String designation;
  final String memberSince;
  final String membershipExpires;

  const _MembershipCard({
    required this.designation,
    required this.memberSince,
    required this.membershipExpires,
  });

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      title: 'Membership Details',
      icon: Icons.verified_outlined,
      child: Column(
        children: [
          _DetailRow(label: 'Designation', value: designation),
          if (memberSince.isNotEmpty)
            _DetailRow(label: 'Member Since', value: memberSince),
          _DetailRow(
            label: 'Membership Expires',
            value: membershipExpires,
            valueColor: const Color(0xFF16A34A),
          ),
        ],
      ),
    );
  }
}

class _ImportantDatesCard extends StatelessWidget {
  final String dob;
  final String anniversary;

  const _ImportantDatesCard({required this.dob, required this.anniversary});

  @override
  Widget build(BuildContext context) {
    return _ProfileCard(
      title: 'Important Dates',
      icon: Icons.event_note_outlined,
      child: Column(
        children: [
          if (dob.isNotEmpty) _DetailRow(label: 'Date of Birth', value: dob),
          if (anniversary.isNotEmpty)
            _DetailRow(label: 'Anniversary', value: anniversary),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatelessWidget {
  final int memberId;

  const _QuickActionsSection({required this.memberId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _ActionButton(
            label: 'Payment History',
            icon: Icons.receipt_long_outlined,
            onTap: () {
              // Navigate to payment history page
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PaymentHistoryPage(memberId: memberId),
                ),
              );
            },
          ),
          _ActionButton(
            label: 'Renew Membership',
            icon: Icons.credit_card_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RenewMembershipPage()),
              );
            },
          ),
          _ActionButton(
            label: 'Privacy Policy',
            icon: Icons.privacy_tip_outlined,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              );
            },
          ),
          _ActionButton(
            label: 'Delete Account',
            icon: Icons.delete_forever_outlined,
            destructive: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DeleteAccountPage()),
              );
            },
          ),
          _ActionButton(
            label: 'Logout',
            icon: Icons.logout,
            destructive: true,
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                barrierDismissible: true,
                builder: (dialogContext) {
                  return Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFFF6B6B),
                                    Color(0xFFFF8E53),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: const Icon(
                                Icons.logout,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF222B45),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Are you sure you want to logout from your account?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(
                                        color: Color(0xFFE5E7EB),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop(false);
                                    },
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4B5563),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFEF4444),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop(true);
                                    },
                                    child: const Text(
                                      'Logout',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );

              if (shouldLogout != true) return;

              await AuthStorage.clearTokens();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginFramePage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ProfileCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
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
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF3843A8)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = destructive
        ? const Color(0xFFDC2626)
        : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: textColor,
          side: BorderSide(color: const Color(0xFFE5E7EB)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.white,
        ),
        icon: Icon(icon, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}

// Bottom navigation is handled globally in DashboardPage; no local nav.
