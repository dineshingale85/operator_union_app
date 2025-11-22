import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_client.dart';
import 'register_otp.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  int _currentStep = 1; // 1..3
  bool _isLoading = false;
  String? _registerToken; // registration OTP/token from /api/register

  // Form field state
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  int? _circleId;
  int? _zoneId;
  int? _designationId;
  String? _dob; // yyyy-MM-dd
  String? _anniversary; // yyyy-MM-dd

  // Dynamic membership fee config
  Map<String, dynamic>? _membershipFee;

  // Master data lists
  List<Map<String, dynamic>> _designations = [];
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _circles = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
    _loadMembershipFee();
  }

  Future<void> _loadMasterData() async {
    try {
      final api = ApiClient();

      final designationsResp = await api.getJson('/api/designations');
      final zonesResp = await api.getJson('/api/zones');
      final circlesResp = await api.getJson('/api/circles');

      if (!mounted) return;
      setState(() {
        _designations =
            (designationsResp['data'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
        _zones =
            (zonesResp['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        _circles =
            (circlesResp['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      // Show a visible error so user knows why dropdowns are empty.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load master data: $e')));
      setState(() {
        _designations = [];
        _zones = [];
        _circles = [];
      });
    }
  }

  Future<void> _loadMembershipFee() async {
    try {
      final api = ApiClient();
      final resp = await api.getJson('/api/membership-fee');
      if (!mounted) return;

      if (resp['success'] == true && resp['data'] is Map) {
        setState(() {
          _membershipFee = Map<String, dynamic>.from(resp['data'] as Map);
        });
      } else {
        final msg =
            resp['message'] as String? ?? 'Membership fee is not configured.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load membership fee: $e')),
      );
    }
  }

  Future<void> _pickDate({required String field}) async {
    final now = DateTime.now();
    final initialDate = now.subtract(const Duration(days: 365 * 18));
    final firstDate = DateTime(1900);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) return;

    final String formatted =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

    setState(() {
      if (field == 'dob') {
        _dob = formatted;
      } else if (field == 'anniversary') {
        _anniversary = formatted;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _cpfController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _goNext() {
    // Validate current step before moving to next
    if (_currentStep == 1) {
      // Step 1: Personal Details validation
      if (_nameController.text.trim().isEmpty) {
        _showError('Please enter your full name');
        return;
      }
      if (_cpfController.text.trim().isEmpty) {
        _showError('Please enter your CPF number');
        return;
      }
      final mobile = _mobileController.text.replaceAll(RegExp(r'\D'), '');
      if (mobile.isEmpty || mobile.length != 10) {
        _showError('Please enter a valid 10-digit mobile number');
        return;
      }
      if (_emailController.text.trim().isEmpty) {
        _showError('Please enter your email address');
        return;
      }
      // Basic email validation
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(_emailController.text.trim())) {
        _showError('Please enter a valid email address');
        return;
      }
    } else if (_currentStep == 2) {
      // Step 2: Organization Details validation
      if (_designationId == null) {
        _showError('Please select your designation');
        return;
      }
      if (_zoneId == null) {
        _showError('Please select your zone');
        return;
      }
      if (_circleId == null) {
        _showError('Please select your circle');
        return;
      }
      if (_dob == null || _dob!.isEmpty) {
        _showError('Please select your date of birth');
        return;
      }
    }

    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      _submitRegistration();
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _goPrev() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Map<String, dynamic> _buildPayload({required String? otp}) {
    return {
      'otp': otp,
      'token': _registerToken,
      'name': _nameController.text.trim(),
      'mobile': _mobileController.text.replaceAll(RegExp(r'\D'), ''),
      'cpf_number': _cpfController.text.trim(),
      'email': _emailController.text.trim(),
      'circle_id': _circleId,
      'zone_id': _zoneId,
      'designation_id': _designationId,
      'date_of_birth': _dob,
      'anniversary_date': _anniversary,
    };
  }

  Future<void> _submitRegistration() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    final api = ApiClient();

    try {
      // First call: /api/register to send OTP and get token
      final body = _buildPayload(otp: null)
        ..remove('otp')
        ..remove('token');

      final response = await api.postJson('/api/register', body);

      if (response['success'] != true) {
        String message =
            response['message'] as String? ?? 'Registration failed';
        final errors = response['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstKey = errors.keys.first;
          final firstList = errors[firstKey];
          if (firstList is List && firstList.isNotEmpty) {
            message = firstList.first.toString();
          }
        }
        if (!mounted) return;
        _showError(message);
        return;
      }

      final token = response['token'] as String?;
      if (token == null || token.isEmpty) {
        if (!mounted) return;
        _showError('Missing registration token');
        return;
      }
      _registerToken = token;

      if (!mounted) return;
      final payload = _buildPayload(otp: null)
        ..remove('otp')
        ..['token'] = _registerToken;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegisterOtpPage(registrationData: payload),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String errorMessage = 'An error occurred during registration';

      // Try to parse the error message
      final errorString = e.toString();
      if (errorString.contains('The mobile has already been taken')) {
        errorMessage = 'This mobile number is already registered';
      } else if (errorString.contains('The email has already been taken')) {
        errorMessage = 'This email address is already registered';
      } else if (errorString.contains(
        'The cpf_number has already been taken',
      )) {
        errorMessage = 'This CPF number is already registered';
      } else if (errorString.contains('HTTP')) {
        errorMessage =
            'Network error. Please check your connection and try again';
      }

      _showError(errorMessage);
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
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 512),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _RegisterHeader(),
                  _RegisterStepper(currentStep: _currentStep),
                  _RegisterCard(
                    currentStep: _currentStep,
                    designations: _designations,
                    zones: _zones,
                    circles: _circles,
                    dob: _dob,
                    onDobTap: () => _pickDate(field: 'dob'),
                    cpfController: _cpfController,
                    nameController: _nameController,
                    mobileController: _mobileController,
                    emailController: _emailController,
                    membershipFee: _membershipFee,
                    onDesignationChanged: (id) => _designationId = id,
                    onZoneChanged: (id) => _zoneId = id,
                    onCircleChanged: (id) => _circleId = id,
                  ),
                  const SizedBox(height: 16),
                  _RegisterButtons(
                    currentStep: _currentStep,
                    isLoading: _isLoading,
                    onNext: _goNext,
                    onPrev: _goPrev,
                  ),
                  const SizedBox(height: 16),
                  const _RegisterFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterHeader extends StatelessWidget {
  const _RegisterHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: const [
        SizedBox(height: 8),
        Text(
          'Member Registration',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Join our community today',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
        ),
        SizedBox(height: 24),
      ],
    );
  }
}

class _RegisterStepper extends StatelessWidget {
  final int currentStep;

  const _RegisterStepper({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              top: 32,
              child: Container(height: 2, color: const Color(0xFFE5E7EB)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepIndicator(
                  step: 1,
                  label: 'Personal Details',
                  currentStep: currentStep,
                ),
                _StepIndicator(
                  step: 2,
                  label: 'Organization Details',
                  currentStep: currentStep,
                ),
                _StepIndicator(
                  step: 3,
                  label: 'Payment',
                  currentStep: currentStep,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  final String label;
  final int currentStep;

  const _StepIndicator({
    required this.step,
    required this.label,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = currentStep == step;
    final bool isCompleted = currentStep > step;

    Color bgColor = Colors.white;
    Color borderColor = const Color(0xFFE5E7EB);
    Color textColor = const Color(0xFF111827);

    if (isCompleted) {
      bgColor = const Color(0xFF16A34A);
      borderColor = const Color(0xFF16A34A);
      textColor = Colors.white;
    } else if (isActive) {
      bgColor = const Color(0xFF3843A8);
      borderColor = const Color(0xFF3843A8);
      textColor = Colors.white;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            border: Border.all(color: borderColor, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            step.toString(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

class _RegisterCard extends StatelessWidget {
  final int currentStep;
  final List<Map<String, dynamic>> designations;
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> circles;
  final String? dob;
  final VoidCallback onDobTap;
  final TextEditingController cpfController;
  final TextEditingController nameController;
  final TextEditingController mobileController;
  final TextEditingController emailController;
  final Map<String, dynamic>? membershipFee;
  final ValueChanged<int?> onDesignationChanged;
  final ValueChanged<int?> onZoneChanged;
  final ValueChanged<int?> onCircleChanged;

  const _RegisterCard({
    required this.currentStep,
    required this.designations,
    required this.zones,
    required this.circles,
    this.dob,
    required this.onDobTap,
    required this.cpfController,
    required this.nameController,
    required this.mobileController,
    required this.emailController,
    required this.membershipFee,
    required this.onDesignationChanged,
    required this.onZoneChanged,
    required this.onCircleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _buildStep(currentStep),
      ),
    );
  }

  Widget _buildStep(int step) {
    switch (step) {
      case 1:
        return _StepPersonal(
          key: const ValueKey('step1'),
          cpfController: cpfController,
          nameController: nameController,
          mobileController: mobileController,
          emailController: emailController,
        );
      case 2:
        return _StepOrganization(
          key: const ValueKey('step2'),
          designations: designations,
          zones: zones,
          circles: circles,
          dob: dob,
          onDobTap: onDobTap,
          onDesignationChanged: onDesignationChanged,
          onZoneChanged: onZoneChanged,
          onCircleChanged: onCircleChanged,
        );
      case 3:
        return _StepPayment(
          key: const ValueKey('step3'),
          membershipFee: membershipFee,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StepPersonal extends StatelessWidget {
  final TextEditingController cpfController;
  final TextEditingController nameController;
  final TextEditingController mobileController;
  final TextEditingController emailController;

  const _StepPersonal({
    super.key,
    required this.cpfController,
    required this.nameController,
    required this.mobileController,
    required this.emailController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Personal Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        _FormField(
          label: 'CPF Number *',
          hint: 'Enter CPF number',
          controller: cpfController,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[@.]'))],
        ),
        _FormField(
          label: 'Member Name *',
          hint: 'Enter full name',
          controller: nameController,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[@.]'))],
        ),
        _FormField(
          label: 'Mobile Number *',
          hint: '+91 XXXXX XXXXX',
          keyboardType: TextInputType.phone,
          controller: mobileController,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        _FormField(
          label: 'Email *',
          hint: 'name@example.com',
          keyboardType: TextInputType.emailAddress,
          controller: emailController,
        ),
      ],
    );
  }
}

class _StepOrganization extends StatelessWidget {
  final List<Map<String, dynamic>> designations;
  final List<Map<String, dynamic>> zones;
  final List<Map<String, dynamic>> circles;
  final String? dob;
  final VoidCallback onDobTap;
  final ValueChanged<int?> onDesignationChanged;
  final ValueChanged<int?> onZoneChanged;
  final ValueChanged<int?> onCircleChanged;

  const _StepOrganization({
    super.key,
    required this.designations,
    required this.zones,
    required this.circles,
    this.dob,
    required this.onDobTap,
    required this.onDesignationChanged,
    required this.onZoneChanged,
    required this.onCircleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organization Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        _DropdownField(
          label: 'Designation *',
          items: designations,
          onChanged: onDesignationChanged,
        ),
        _DropdownField(label: 'Zone *', items: zones, onChanged: onZoneChanged),
        _DropdownField(
          label: 'Circle *',
          items: circles,
          onChanged: onCircleChanged,
        ),
        _DateField(label: 'Date of Birth *', value: dob, onTap: onDobTap),
      ],
    );
  }
}

class _StepPayment extends StatelessWidget {
  final Map<String, dynamic>? membershipFee;

  const _StepPayment({super.key, this.membershipFee});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Membership Fee',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3843A8), Color(0xFF6370FF)],
            ),
          ),
          child: Column(
            children: [
              const Text(
                'Annual Membership Fee',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                membershipFee != null
                    ? '₹${membershipFee!['membershipfee'] ?? '-'}'
                    : '₹-',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Per year',
                style: TextStyle(fontSize: 15, color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: const Text(
                  'Your membership will be active for one year from the date of payment. You\'ll receive an invoice after successful payment.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;

  const _FormField({
    required this.label,
    required this.hint,
    this.keyboardType,
    this.controller,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3843A8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final List<Map<String, dynamic>> items;
  final ValueChanged<int?> onChanged;

  const _DropdownField({
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            isExpanded: true,
            items: items
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e['id'].toString(),
                    child: Text(
                      (e['name'] ?? e['designation'] ?? '').toString(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                onChanged(null);
              } else {
                onChanged(int.tryParse(value));
              }
            },
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3843A8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            onTap: onTap,
            decoration: InputDecoration(
              hintText: value ?? 'Select date',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
              ),
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3843A8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegisterButtons extends StatelessWidget {
  final int currentStep;
  final bool isLoading;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _RegisterButtons({
    required this.currentStep,
    required this.isLoading,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    final bool showPrev = currentStep > 1;
    final String nextLabel = currentStep == 3 ? 'Proceed to Payment' : 'Next';

    return Row(
      children: [
        if (showPrev)
          Expanded(
            child: OutlinedButton(
              onPressed: isLoading ? null : onPrev,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Previous',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        if (showPrev) const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: isLoading ? null : onNext,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.black54,
              disabledForegroundColor: Colors.white70,
            ),
            child: isLoading && currentStep == 3
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Processing...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : Text(
                    nextLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _RegisterFooter extends StatelessWidget {
  const _RegisterFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
        },
        child: const Text.rich(
          TextSpan(
            text: 'Already have an account? ',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            children: [
              TextSpan(
                text: 'Login',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF3843A8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
