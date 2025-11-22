import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_client.dart';

class CommitteeListPage extends StatefulWidget {
  const CommitteeListPage({super.key});

  @override
  State<CommitteeListPage> createState() => _CommitteeListPageState();
}

class _CommitteeListPageState extends State<CommitteeListPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _committeeMembers = [];
  List<Map<String, dynamic>> _filteredMembers = [];
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCommitteeMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCommitteeMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final response = await api.getJson('/api/committee-members');

      if (response['success'] == true) {
        final members = (response['data'] as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();

        setState(() {
          _committeeMembers = members;
          _filteredMembers = members;
          _isLoading = false;
        });
      } else {
        throw Exception(
          response['message'] ?? 'Failed to load committee members',
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _committeeMembers;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredMembers = _committeeMembers.where((member) {
          final name = (member['name'] ?? '').toString().toLowerCase();
          final designation = (member['designation'] ?? '')
              .toString()
              .toLowerCase();
          final committeeRole = (member['committee_designation'] ?? '')
              .toString()
              .toLowerCase();
          final location = (member['working_location'] ?? '')
              .toString()
              .toLowerCase();
          final circle = (member['circle'] ?? '').toString().toLowerCase();

          return name.contains(lowerQuery) ||
              designation.contains(lowerQuery) ||
              committeeRole.contains(lowerQuery) ||
              location.contains(lowerQuery) ||
              circle.contains(lowerQuery);
        }).toList();
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch email client')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: const Color(0xFF2563EB),
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF2563EB),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildStats(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildError()
                  : _buildMemberGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 15,
            offset: Offset(0, 4),
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
                  'Union Committee',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'MSE Operators Union Leadership Team',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: _filterMembers,
        decoration: InputDecoration(
          hintText: 'Search committee members...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final activeCount = _committeeMembers
        .where((m) => m['status'] == 'active')
        .length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_filteredMembers.length} Members',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
          const Text(' • ', style: TextStyle(color: Color(0xFF64748B))),
          Text(
            '$activeCount Active',
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Failed to load committee members',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCommitteeMembers,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberGrid() {
    if (_filteredMembers.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredMembers.length,
      itemBuilder: (context, index) {
        return _buildMemberCard(_filteredMembers[index], index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No committee members found'
                : 'No members found matching "${_searchController.text}"',
            style: const TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member, int index) {
    final colors = [
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFDC2626),
      const Color(0xFF059669),
      const Color(0xFFD97706),
    ];
    final avatarColor = colors[index % colors.length];

    final name = member['name'] ?? 'Unknown';
    final committeeRole = member['committee_designation'] as String?;
    final designation = member['designation'] as String?;
    final employeeNumber = member['employee_number'] as String?;
    final workingLocation = member['working_location'] as String?;
    final circle = member['circle'] as String?;
    final mobile = member['mobile'] as String?;
    final email = member['email'] as String?;
    final photo = member['photo_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with avatar and name
            Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: photo != null && photo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                name.substring(0, 2).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            name.substring(0, 2).toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Name and committee role
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (committeeRole != null &&
                          committeeRole.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            committeeRole,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Details
            if (designation != null && designation.isNotEmpty)
              _buildDetailRow(Icons.work_outline, designation, false),
            if (employeeNumber != null && employeeNumber.isNotEmpty)
              _buildDetailRow(
                Icons.badge_outlined,
                'Emp. $employeeNumber',
                true,
              ),
            if (workingLocation != null && workingLocation.isNotEmpty)
              _buildDetailRow(
                Icons.location_on_outlined,
                workingLocation,
                false,
              ),
            if (circle != null && circle.isNotEmpty)
              _buildDetailRow(Icons.business_outlined, circle, true),
            const SizedBox(height: 16),
            // Contact actions
            Row(
              children: [
                if (mobile != null && mobile.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _makePhoneCall(mobile),
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                if (mobile != null &&
                    mobile.isNotEmpty &&
                    email != null &&
                    email.isNotEmpty &&
                    email != 'N/A')
                  const SizedBox(width: 8),
                if (email != null && email.isNotEmpty && email != 'N/A')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _sendEmail(email),
                      icon: const Icon(Icons.email_outlined, size: 16),
                      label: const Text('Email'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isMuted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isMuted
                    ? const Color(0xFF64748B)
                    : const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
