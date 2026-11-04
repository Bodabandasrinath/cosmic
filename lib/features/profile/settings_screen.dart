import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          _buildHeader('NOTIFICATIONS'),
          _buildSwitchTile(
            title: 'Push Notifications',
            subtitle: 'Receive alerts for incoming calls and messages',
            value: _notifications,
            onChanged: (val) {
              setState(() => _notifications = val);
              _savePreference(AppConstants.keyNotificationsEnabled, val);
            },
          ),
          const SizedBox(height: 16),

          _buildHeader('PRIVACY'),
          _buildSwitchTile(
            title: 'Online Status Visibility',
            subtitle: 'Let friends know when you are active on Cosmic',
            value: _showOnline,
            onChanged: (val) {
              setState(() => _showOnline = val);
              _savePreference(AppConstants.keyOnlineVisibility, val);
            },
          ),
          _buildSwitchTile(
            title: 'Read Receipts',
            subtitle: 'Show double checkmarks when messages are seen',
            value: _readReceipts,
            onChanged: (val) {
              setState(() => _readReceipts = val);
              _savePreference(AppConstants.keyReadReceipts, val);
            },
          ),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            tileColor: AppColors.card,
            title: const Text('Blocked Accounts', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('View and manage accounts you blocked', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              );
            },
          ),
          const SizedBox(height: 16),

          _buildHeader('APPEARANCE'),
          _buildSwitchTile(
            title: 'Cosmic Dark Mode',
            subtitle: 'Deep space dark UI theme',
            value: _darkMode,
            onChanged: (val) {
              setState(() => _darkMode = val);
              _savePreference(AppConstants.keyDarkMode, val);
            },
          ),
          const SizedBox(height: 16),

          _buildHeader('ABOUT'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cosmic for Android', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 4),
                Text('Version 1.0.0 (Build 1)', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                SizedBox(height: 8),
                Text('Connect beyond distance. Featuring real-time messaging, photos, videos, voice notes, and direct WebRTC voice & video calling.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
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
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        value: value,
        activeThumbColor: AppColors.primaryLight,
        activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
        onChanged: onChanged,
      ),
    );
  }
}
