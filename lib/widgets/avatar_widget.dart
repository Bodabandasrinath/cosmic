import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final bool isOnline;
  final bool showOnlineIndicator;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 24,
    this.isOnline = false,
    this.showOnlineIndicator = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    Widget avatarContent;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatarContent = CachedNetworkImage(
        imageUrl: photoUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.surface,
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildInitialsFallback(initials),
      );
    } else {
      avatarContent = _buildInitialsFallback(initials);
    }

    final avatar = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: avatarContent,
    );

    if (!showOnlineIndicator) {
      return GestureDetector(onTap: onTap, child: avatar);
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.6,
              height: radius * 0.6,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.online : AppColors.offline,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsFallback(String initials) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        gradient: AppColors.cosmicGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
