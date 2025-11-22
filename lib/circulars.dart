import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
// Uses dashboard's bottom navigation; no local bottom nav here.
import 'api_client.dart';

class CircularsPage extends StatefulWidget {
  const CircularsPage({super.key});

  @override
  State<CircularsPage> createState() => _CircularsPageState();
}

class _CircularsPageState extends State<CircularsPage> {
  bool _isLoading = true;
  String? _error;
  List<_CircularItemData> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadCirculars();
  }

  Future<void> _loadCirculars() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final resp = await api.getJson('/api/circulars');

      if (resp['success'] == true && resp['data'] is List) {
        final List data = resp['data'] as List;
        final items = data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final category = map['category']?.toString().toLowerCase() ?? '';
          final tagType = _mapCategoryToTagType(category);

          // Format date to D-M-Y
          String formattedDate = '';
          final dateStr = map['created_at']?.toString() ?? '';
          if (dateStr.isNotEmpty) {
            try {
              final parsedDate = DateTime.parse(dateStr.split('T').first);
              formattedDate =
                  '${parsedDate.day}-${parsedDate.month}-${parsedDate.year}';
            } catch (_) {
              formattedDate = dateStr.split('T').first;
            }
          }

          return _CircularItemData(
            title: map['title']?.toString() ?? 'Untitled',
            tag: _mapCategoryToLabel(category),
            tagType: tagType,
            fileSize: map['file_size_formatted']?.toString() ?? '-',
            date: formattedDate,
            fileUrl: map['file_url']?.toString(),
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _items = items;
          _isLoading = false;
        });
      } else {
        throw Exception(
          resp['message']?.toString() ?? 'Failed to load circulars',
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
        const _CircularsHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Failed to load circulars',
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
                          onPressed: _loadCirculars,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _CircularsList(items: _items),
        ),
      ],
    );
  }
}

class _CircularsHeader extends StatelessWidget {
  const _CircularsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          const Text(
            'Circulars',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.search, size: 18, color: Color(0xFF9CA3AF)),
                ),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search circulars...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      border: InputBorder.none,
                    ),
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

class _CircularsList extends StatelessWidget {
  final List<_CircularItemData> items;

  const _CircularsList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No circulars available',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CircularCard(data: items[index]),
        );
      },
    );
  }
}

class _CircularItemData {
  final String title;
  final String tag;
  final _CircularTagType tagType;
  final String fileSize;
  final String date;
  final String? fileUrl;

  const _CircularItemData({
    required this.title,
    required this.tag,
    required this.tagType,
    required this.fileSize,
    required this.date,
    this.fileUrl,
  });
}

enum _CircularTagType { meeting, policy, event, finance }

_CircularTagType _mapCategoryToTagType(String category) {
  switch (category) {
    case 'meeting':
      return _CircularTagType.meeting;
    case 'policy':
      return _CircularTagType.policy;
    case 'event':
      return _CircularTagType.event;
    case 'finance':
      return _CircularTagType.finance;
    default:
      return _CircularTagType.meeting;
  }
}

String _mapCategoryToLabel(String category) {
  switch (category) {
    case 'meeting':
      return 'Meeting';
    case 'policy':
      return 'Policy';
    case 'event':
      return 'Event';
    case 'finance':
      return 'Finance';
    default:
      return 'Other';
  }
}

class _CircularCard extends StatelessWidget {
  final _CircularItemData data;

  const _CircularCard({required this.data});

  Color _badgeBg(_CircularTagType type) {
    switch (type) {
      case _CircularTagType.meeting:
        return const Color(0x1A3843A8);
      case _CircularTagType.policy:
        return const Color(0x1AF97316);
      case _CircularTagType.event:
        return const Color(0x1A22C55E);
      case _CircularTagType.finance:
        return const Color(0x1AE11D48);
    }
  }

  Color _badgeColor(_CircularTagType type) {
    switch (type) {
      case _CircularTagType.meeting:
        return const Color(0xFF3843A8);
      case _CircularTagType.policy:
        return const Color(0xFFF97316);
      case _CircularTagType.event:
        return const Color(0xFF22C55E);
      case _CircularTagType.finance:
        return const Color(0xFFE11D48);
    }
  }

  Future<void> _downloadFile(BuildContext context) async {
    if (data.fileUrl == null || data.fileUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download link not available'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(data.fileUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not open download link');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0x1A3843A8),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF3843A8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _badgeBg(data.tagType),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            data.tag,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _badgeColor(data.tagType),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data.fileSize,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                            SizedBox(width: 4),
                          ],
                        ),
                        Text(
                          data.date,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _downloadFile(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.download,
                            size: 14,
                            color: Color(0xFF111827),
                          ),
                          label: const Text(
                            'Download',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Bottom navigation is handled by DashboardPage; no local nav here.
