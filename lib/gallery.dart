import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Used inside DashboardPage as a tab body; no local bottom nav.
import 'api_client.dart';

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  bool _isLoading = true;
  String? _error;
  List<_AlbumData> _albums = const [];

  @override
  void initState() {
    super.initState();
    _loadGalleries();
  }

  Future<void> _loadGalleries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final resp = await api.getJson('/api/galleries');

      if (resp['success'] == true && resp['data'] is List) {
        final List data = resp['data'] as List;
        final albums = data.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          final List images = (map['images'] as List?) ?? [];

          return _AlbumData(
            id: int.tryParse(map['id'].toString()) ?? 0,
            title: map['title']?.toString() ?? 'Untitled',
            date: map['event_date']?.toString() ?? '-',
            photos: images.length,
            thumbnails: images
                .map((img) => Map<String, dynamic>.from(img as Map))
                .map((img) => img['thumbnail_url']?.toString() ?? '')
                .where((url) => url.isNotEmpty)
                .toList(),
          );
        }).toList();

        if (!mounted) return;
        setState(() {
          _albums = albums;
          _isLoading = false;
        });
      } else {
        throw Exception(
          resp['message']?.toString() ?? 'Failed to load galleries',
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
          backgroundColor: const Color(0xFF16A34A),
          elevation: 0,
          automaticallyImplyLeading: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Color(0xFF16A34A),
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        ),
        const _GalleryHeader(),
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
                          'Failed to load galleries',
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
                          onPressed: _loadGalleries,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _GalleryGrid(albums: _albums),
        ),
      ],
    );
  }
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader();

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
          colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
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
        children: const [
          Text(
            'Event Gallery',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Browse through our memorable moments',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _GalleryGrid extends StatelessWidget {
  final List<_AlbumData> albums;

  const _GalleryGrid({required this.albums});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const Center(
        child: Text(
          'No galleries available',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AlbumCard(album: albums[index]),
        );
      },
    );
  }
}

class _AlbumData {
  final int id;
  final String title;
  final String date;
  final int photos;
  final List<String> thumbnails;

  const _AlbumData({
    required this.id,
    required this.title,
    required this.date,
    required this.photos,
    this.thumbnails = const [],
  });
}

class _AlbumCard extends StatelessWidget {
  final _AlbumData album;

  const _AlbumCard({required this.album});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GalleryDetailPage(galleryId: album.id),
          ),
        );
      },
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AlbumImage(thumbnails: album.thumbnails),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: const [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(width: 4),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          album.date,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${album.photos} photos',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF16A34A),
                      ),
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
}

class _AlbumImage extends StatelessWidget {
  final List<String> thumbnails;

  const _AlbumImage({required this.thumbnails});

  @override
  Widget build(BuildContext context) {
    final displayThumbs = thumbnails.take(4).toList();
    final placeholdersToAdd = 4 - displayThumbs.length;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3843A8), Color(0xFF16A34A)],
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          children: [
            ...displayThumbs.map((url) {
              return Container(
                decoration: const BoxDecoration(color: Colors.black12),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) {
                    return const Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF3843A8),
                    );
                  },
                ),
              );
            }),
            ...List.generate(placeholdersToAdd.clamp(0, 4), (index) {
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF3843A8).withOpacity(0.2),
                      const Color(0xFF16A34A).withOpacity(0.2),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.photo,
                  color: Color(0xFF3843A8),
                  size: 28,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class GalleryDetailPage extends StatefulWidget {
  final int galleryId;

  const GalleryDetailPage({super.key, required this.galleryId});

  @override
  State<GalleryDetailPage> createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends State<GalleryDetailPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _gallery;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiClient();
      final resp = await api.getJson('/api/galleries/${widget.galleryId}');

      if (resp['success'] == true && resp['data'] is Map) {
        if (!mounted) return;
        setState(() {
          _gallery = Map<String, dynamic>.from(resp['data'] as Map);
          _isLoading = false;
        });
      } else {
        throw Exception(resp['message']?.toString() ?? 'Gallery not found.');
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
    final title = _gallery?['title']?.toString() ?? 'Gallery';
    final description = _gallery?['description']?.toString() ?? '';
    final List images = (_gallery?['images'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF16A34A),
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF16A34A),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      backgroundColor: const Color(0xFFF3F4F8),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Failed to load gallery',
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
                      onPressed: _loadGallery,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                Expanded(
                  child: images.isEmpty
                      ? const Center(
                          child: Text(
                            'No images available',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                              ),
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            final img = Map<String, dynamic>.from(
                              images[index],
                            );
                            final url = img['image_url']?.toString() ?? '';
                            final caption = img['caption']?.toString() ?? '';
                            return InkWell(
                              onTap: () {
                                if (url.isEmpty) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => _FullImagePage(
                                      imageUrl: url,
                                      caption: caption,
                                    ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, _, __) =>
                                            Container(
                                              color: Colors.black12,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                                color: Color(0xFF3843A8),
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                                  if (caption.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        left: 2,
                                        right: 2,
                                      ),
                                      child: Text(
                                        caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF4B5563),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _FullImagePage extends StatelessWidget {
  final String imageUrl;
  final String caption;

  const _FullImagePage({
    super.key,
    required this.imageUrl,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        title: Text(
          caption.isNotEmpty ? caption : 'Photo',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, _, __) => Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Bottom navigation is provided by DashboardPage; no local nav widget.
