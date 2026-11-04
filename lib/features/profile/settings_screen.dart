import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/auth_repository.dart';
import '../auth/login_screen.dart';
import 'blocked_users_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifications = true;
  bool _showOnline = true;
  bool _readReceipts = true;
  bool _darkMode = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifications = prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true;
      _showOnline = prefs.getBool(AppConstants.keyOnlineVisibility) ?? true;
      _readReceipts = prefs.getBool(AppConstants.keyReadReceipts) ?? true;
      _darkMode = prefs.getBool(AppConstants.keyDarkMode) ?? true;
    });
  }

  Future<void> _savePreference(String key, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out of COSMIC?', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        content: const Text('You will need to enter your username and password or phone OTP to log back in.', style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 13.5)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: const Text('Log out', style: TextStyle(color: AppColors.igHeartRed, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authRepo = Provider.of<AuthRepository>(context, listen: false);
      await authRepo.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings and activity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          _buildHeader('HOW YOU USE COSMIC'),
          _buildSwitchTile(
            icon: Icons.notifications_none_rounded,
            title: 'Push Notifications',
            subtitle: 'Direct messages, voice calls and video calls',
            value: _notifications,
            onChanged: (val) {
              setState(() => _notifications = val);
              _savePreference(AppConstants.keyNotificationsEnabled, val);
            },
          ),
          const SizedBox(height: 16),

          _buildHeader('WHO CAN SEE YOUR CONTENT'),
          _buildSwitchTile(
            icon: Icons.circle_outlined,
            title: 'Activity Status',
            subtitle: 'Allow accounts you message to see when you were last active',
            value: _showOnline,
            onChanged: (val) {
              setState(() => _showOnline = val);
              _savePreference(AppConstants.keyOnlineVisibility, val);
            },
          ),
          _buildSwitchTile(
            icon: Icons.done_all_rounded,
            title: 'Read Receipts',
            subtitle: 'Show blue checkmarks when messages have been seen',
            value: _readReceipts,
            onChanged: (val) {
              setState(() => _readReceipts = val);
              _savePreference(AppConstants.keyReadReceipts, val);
            },
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: ListTile(
              leading: const Icon(Icons.block_outlined, color: Colors.white70, size: 22),
              title: const Text('Blocked accounts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
              subtitle: const Text('Manage accounts you have restricted or blocked', style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E8E8E), size: 20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          _buildHeader('YOUR APP & MEDIA'),
          _buildSwitchTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark Mode',
            subtitle: 'Pure OLED black aesthetic',
            value: _darkMode,
            onChanged: (val) {
              setState(() => _darkMode = val);
              _savePreference(AppConstants.keyDarkMode, val);
            },
          ),
          const SizedBox(height: 16),

          _buildHeader('MORE INFO AND SUPPORT'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.all_inclusive_rounded, color: AppColors.igBlue, size: 20),
                    SizedBox(width: 8),
                    Text('COSMIC Platform', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ],
                ),
                SizedBox(height: 6),
                Text('Version 1.0.0 (Build 1)', style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 12.5)),
                SizedBox(height: 8),
                Text(
                  'Instagram-inspired direct messaging, photo & video sharing, voice notes, and direct WebRTC audio/video calling.',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Log out button
          GestureDetector(
            onTap: _confirmLogout,
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF262626)),
              ),
              child: const Text(
                'Log out',
                style: TextStyle(
                  color: AppColors.igHeartRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF8E8E8E),
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.white70, size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 12)),
        value: value,
        activeThumbColor: Colors.white,
        activeTrackColor: AppColors.igBlue,
        inactiveTrackColor: const Color(0xFF262626),
        onChanged: onChanged,
      ),
    );
  }
}
