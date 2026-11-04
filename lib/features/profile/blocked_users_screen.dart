import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/avatar_widget.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthRepository>(context).currentUid!;
    final userRepository = UserRepository();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Blocked Accounts')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: userRepository.streamBlockedUsers(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
          }

          final blocked = snapshot.data ?? [];
          if (blocked.isEmpty) {
            return const Center(
              child: Text(
                'No blocked accounts',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: blocked.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.cardBorder, height: 1),
            itemBuilder: (context, index) {
              final user = blocked[index];
              final blockedId = user['blockedId'] ?? '';
              final name = user['displayName'] ?? 'Blocked User';
              final username = user['username'] ?? '';

              return ListTile(
                leading: AvatarWidget(name: name, radius: 22),
                title: Text(name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('@$username', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                trailing: TextButton(
                  child: const Text('Unblock', style: TextStyle(color: AppColors.primaryLight)),
                  onPressed: () async {
                    await userRepository.unblockUser(currentUserId: currentUserId, targetUserId: blockedId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unblocked $name')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
