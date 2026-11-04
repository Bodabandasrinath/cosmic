import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/avatar_widget.dart';
import '../auth/login_screen.dart';
import 'blocked_users_screen.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to log out of Cosmic?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.callRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final authRepo = Provider.of<AuthRepository>(context, listen: false);
              await authRepo.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthRepository>(context);
    final user = authRepo.currentUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        child: Column(
          children: [
            // User Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                children: [
                  AvatarWidget(
                    name: user.displayName,
                    photoUrl: user.profilePhoto,
                    radius: 46,
                    isOnline: true,
                    showOnlineIndicator: true,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user.bio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.cardBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.secondary),
                    label: const Text('Edit Profile'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings & Options List
            _buildSectionHeader('PREFERENCES & SECURITY'),
            _buildSettingsTile(
              icon: Icons.notifications_outlined,
              color: AppColors.primaryLight,
              title: 'Notifications',
              subtitle: 'Message and call alerts',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.block_outlined,
              color: AppColors.callRed,
              title: 'Blocked Users',
              subtitle: 'Manage blocked accounts',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                );
              },
            ),
            _buildSettingsTile(
              icon: Icons.lock_outline_rounded,
              color: AppColors.secondary,
              title: 'Privacy & Security',
              subtitle: 'Online status, read receipts',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),

            const SizedBox(height: 16),
            _buildSectionHeader('APP INFO'),
            _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              color: AppColors.accentPink,
              title: 'About Cosmic',
              subtitle: '${AppConstants.appName} v1.0.0 — ${AppConstants.appTagline}',
              onTap: () {},
            ),

            const SizedBox(height: 24),
            // Log Out Button
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.cardBorder),
              ),
              tileColor: AppColors.card,
              leading: const Icon(Icons.logout_rounded, color: AppColors.callRed),
              title: const Text(
                'Log Out',
                style: TextStyle(color: AppColors.callRed, fontWeight: FontWeight.w600),
              ),
              onTap: () => _showLogoutDialog(context),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ListTile(
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        onTap: onTap,
      ),
    );
  }
}
