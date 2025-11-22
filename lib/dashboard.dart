import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_client.dart';
import 'auth_storage.dart';
import 'gallery.dart';
import 'circulars.dart';
import 'profile.dart';
import 'donations.dart';
import 'committee_list.dart';
import 'chat.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
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
      final response = await api.getJson('/api/dashboard', bearer: authToken);

      setState(() {
        _data = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onNavTap(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardBody(
        isLoading: _isLoading,
        error: _error,
        data: _data,
        onRetry: _loadDashboard,
        onNavigateToGallery: () => _onNavTap(2),
      ),
      const CircularsPage(),
      const GalleryPage(),
      const ProfilePage(),
    ];

    final showHeader = _selectedIndex == 0;

    return WillPopScope(
      onWillPop: () async {
        // If not on Home tab, go back to Home instead of exiting
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return false;
        }

        // Handle double back to exit on Home tab
        final now = DateTime.now();
        const exitThreshold = Duration(seconds: 2);

        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > exitThreshold) {
          _lastBackPressTime = now;

          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF3843A8), Color(0xFF6370FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.home,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Press again to exit',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              duration: exitThreshold,
            ),
          );

          return false;
        }

        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F8),
        appBar: showHeader
            ? AppBar(
                toolbarHeight: 0,
                backgroundColor: const Color(0xFF3843A8),
                elevation: 0,
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Color(0xFF3843A8),
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
              )
            : null,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (showHeader) _DashboardHeader(data: _data),
              Expanded(child: pages[_selectedIndex]),
              _BottomNavBar(
                selectedIndex: _selectedIndex,
                onItemSelected: _onNavTap,
              ),
            ],
          ),
        ),
        // Remove bottomNavigationBar so it doesn't go under gesture bar
        // bottomNavigationBar: const _BottomNavBar(),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final Map<String, dynamic>? data;

  const _DashboardHeader({this.data});

  @override
  Widget build(BuildContext context) {
    final member = data?['member'] as Map<String, dynamic>?;
    final name = member != null
        ? (member['name'] as String? ??
              member['full_name'] as String? ??
              'Member')
        : 'Member';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3843A8), Color(0xFF6370FF)],
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'महाराष्ट्र राज्य विद्युत ऑपरेटर्स संघटना',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Good Morning',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuvicharCard extends StatelessWidget {
  const _SuvicharCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF9A3E), Color(0xFFFFC56F)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x141F2937),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _Badge(text: "Today's Suvichar"),
            SizedBox(height: 8),
            Text(
              '"जीवन का सबसे बड़ा उपहार है - आज का दिन। इसे सार्थक बनाएं।"',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.6,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '— Sant Kabir',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: const [
          _StatCard(label: 'Members', value: '450'),
          SizedBox(width: 8),
          _StatCard(label: 'Circulars', value: '12'),
          SizedBox(width: 8),
          _StatCard(label: 'Events', value: '8'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3843A8),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessSection extends StatelessWidget {
  final VoidCallback onNavigateToGallery;

  const _QuickAccessSection({required this.onNavigateToGallery});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Quick Access'),
        _QuickAccessGrid(onNavigateToGallery: onNavigateToGallery),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  final VoidCallback onNavigateToGallery;

  const _QuickAccessGrid({required this.onNavigateToGallery});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Row(
            children: [
              _QuickLinkCard(
                title: 'Committee',
                subtitle: 'Committee List',
                icon: Icons.description_outlined,
                color: Color(0xFF3843A8),
              ),
              SizedBox(width: 12),
              _QuickLinkCard(
                title: 'Donation',
                subtitle: 'View donations',
                icon: Icons.mail_outline,
                color: Color(0xFFFF9A3E),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickLinkCard(
                title: 'Gallery',
                subtitle: 'View photos',
                icon: Icons.photo_outlined,
                color: Color(0xFF16A34A),
                onNavigateToGallery: onNavigateToGallery,
              ),
              const SizedBox(width: 12),
              const _QuickLinkCard(
                title: 'Chat',
                subtitle: '3 unread',
                icon: Icons.chat_bubble_outline,
                color: Color(0xFF3843A8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onNavigateToGallery;

  const _QuickLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onNavigateToGallery,
  });

  void _handleTap(BuildContext context) {
    if (title == 'Donation') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DonationsPage()));
    } else if (title == 'Committee') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CommitteeListPage()));
    } else if (title == 'Chat') {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatPage()));
    } else if (title == 'Gallery' && onNavigateToGallery != null) {
      onNavigateToGallery!();
    }
    // Add other navigation handlers here as needed
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentUpdatesSection extends StatelessWidget {
  const _RecentUpdatesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [_SectionTitle('Recent Updates'), _UpdatesCard()],
    );
  }
}

class _UpdatesCard extends StatelessWidget {
  const _UpdatesCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
          children: const [
            _UpdateItem(
              title: 'Annual General Meeting Notice - 2024',
              time: '2 hours ago',
            ),
            _UpdateItem(
              title: 'New letter from Secretary',
              time: '5 hours ago',
            ),
            _UpdateItem(
              title: 'Festival photos uploaded',
              time: '1 day ago',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _UpdateItem extends StatelessWidget {
  final String title;
  final String time;
  final bool isLast;

  const _UpdateItem({
    required this.title,
    required this.time,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3843A8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF3843A8),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
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

class _BirthdaysSection extends StatelessWidget {
  const _BirthdaysSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [_SectionTitle('Upcoming Birthdays'), _BirthdaysCard()],
    );
  }
}

class _BirthdaysCard extends StatelessWidget {
  const _BirthdaysCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
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
          children: const [
            _BirthdayItem(
              initials: 'AK',
              name: 'Amit Kumar',
              subtitle: 'Circle 2 - East • Tomorrow',
            ),
            _BirthdayItem(
              initials: 'PS',
              name: 'Priya Sharma',
              subtitle: 'Circle 1 - North • Dec 28',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _BirthdayItem extends StatelessWidget {
  final String initials;
  final String name;
  final String subtitle;
  final bool isLast;

  const _BirthdayItem({
    required this.initials,
    required this.name,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3843A8), Color(0xFF6370FF)],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
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

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const _BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x141F2937),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _BottomNavItem(
            icon: Icons.home_outlined,
            label: 'Home',
            active: selectedIndex == 0,
            onTap: () => onItemSelected(0),
          ),
          _BottomNavItem(
            icon: Icons.description_outlined,
            label: 'Circulars',
            active: selectedIndex == 1,
            onTap: () => onItemSelected(1),
          ),
          _BottomNavItem(
            icon: Icons.photo_outlined,
            label: 'Gallery',
            active: selectedIndex == 2,
            onTap: () => onItemSelected(2),
          ),
          _BottomNavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            active: selectedIndex == 3,
            onTap: () => onItemSelected(3),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? data;
  final VoidCallback onRetry;
  final VoidCallback onNavigateToGallery;

  const _DashboardBody({
    required this.isLoading,
    required this.error,
    required this.data,
    required this.onRetry,
    required this.onNavigateToGallery,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Failed to load dashboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SuvicharCard(),
          const _StatsRow(),
          _QuickAccessSection(onNavigateToGallery: onNavigateToGallery),
          const _RecentUpdatesSection(),
          const _BirthdaysSection(),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF3843A8) : const Color(0xFF9CA3AF);
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
