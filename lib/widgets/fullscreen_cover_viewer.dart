import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/comic_theme.dart';

/// Visor de portada a pantalla completa con zoom y Hero animation
class FullscreenCoverViewer extends StatefulWidget {
  final String? coverUrl;
  final String? localCoverPath;
  final String heroTag;
  final String? title;

  const FullscreenCoverViewer({
    super.key,
    this.coverUrl,
    this.localCoverPath,
    required this.heroTag,
    this.title,
  });

  @override
  State<FullscreenCoverViewer> createState() => _FullscreenCoverViewerState();
}

class _FullscreenCoverViewerState extends State<FullscreenCoverViewer> {
  final TransformationController _transformController = TransformationController();
  bool _showUI = true;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen con zoom
          GestureDetector(
            onTap: _toggleUI,
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Hero(
                  tag: widget.heroTag,
                  child: _buildImage(),
                ),
              ),
            ),
          ),

          // AppBar transparente
          AnimatedOpacity(
            opacity: _showUI ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showUI,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                    stops: [0.0, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        if (widget.title != null)
                          Expanded(
                            child: Text(
                              widget.title!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    // Prioridad: imagen local → URL remota
    if (widget.localCoverPath != null && widget.localCoverPath!.isNotEmpty) {
      final file = File(widget.localCoverPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildNetworkImage(),
        );
      }
    }
    return _buildNetworkImage();
  }

  Widget _buildNetworkImage() {
    if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.coverUrl!,
        fit: BoxFit.contain,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(
            color: ComicTheme.primaryOrange,
          ),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.broken_image,
          color: Colors.white54,
          size: 64,
        ),
      );
    }
    return const Icon(
      Icons.image_not_supported,
      color: Colors.white54,
      size: 64,
    );
  }
}

/// Abre el visor de portada a pantalla completa
void openFullscreenCover(
  BuildContext context, {
  String? coverUrl,
  String? localCoverPath,
  required String heroTag,
  String? title,
}) {
  // Solo abrir si hay alguna imagen
  if ((coverUrl == null || coverUrl.isEmpty) &&
      (localCoverPath == null || localCoverPath.isEmpty)) {
    return;
  }

  Navigator.push(
    context,
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) =>
          FullscreenCoverViewer(
        coverUrl: coverUrl,
        localCoverPath: localCoverPath,
        heroTag: heroTag,
        title: title,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}
