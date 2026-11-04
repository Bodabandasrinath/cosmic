import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';
import '../features/chats/fullscreen_media_viewer.dart';

class VideoBubblePlayer extends StatelessWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;

  const VideoBubblePlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullscreenMediaViewer(
              mediaUrl: videoUrl,
              isVideo: true,
            ),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: thumbnailUrl != null && thumbnailUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: thumbnailUrl!,
                    width: 220,
                    height: 160,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildPlaceholder(),
                    errorWidget: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),
          ),
          // Dark overlay
          Container(
            width: 220,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          // Play button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          // Video indicator badge
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.videocam, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'VIDEO',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 220,
      height: 160,
      color: AppColors.surface,
      child: const Center(
        child: Icon(Icons.movie_creation_outlined, color: AppColors.textMuted, size: 36),
      ),
    );
  }
}
