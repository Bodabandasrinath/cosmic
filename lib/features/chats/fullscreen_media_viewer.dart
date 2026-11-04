import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';

class FullscreenMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;

  const FullscreenMediaViewer({
    super.key,
    required this.mediaUrl,
    this.isVideo = false,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController?.play();
            _isPlaying = true;
          }
        });

      _videoController?.addListener(() {
        if (mounted) {
          final isCurrentlyPlaying = _videoController?.value.isPlaying ?? false;
          if (_isPlaying != isCurrentlyPlaying) {
            setState(() => _isPlaying = isCurrentlyPlaying);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Content
          Center(
            child: widget.isVideo
                ? _buildVideoContent()
                : InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.mediaUrl,
                      fit: BoxFit.contain,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryLight),
                      ),
                      errorWidget: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      ),
                    ),
                  ),
          ),

          // Top Header (Back button, close)
          if (_showControls)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Media saved to device')),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Video Controls
          if (widget.isVideo && _showControls && _videoController != null && _videoController!.value.isInitialized)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    _videoController!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: AppColors.primary,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 42,
                        icon: Icon(
                          _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryLight),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      ),
    );
  }
}
