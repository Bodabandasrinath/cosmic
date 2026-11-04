import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Blocked accounts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: userRepository.streamBlockedUsers(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final blocked = snapshot.data ?? [];
          if (blocked.isEmpty) {
            return const Center(
              child: Text(
                'No blocked accounts',
                style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 15),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: blocked.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFF1C1C1E), height: 1, indent: 70),
            itemBuilder: (context, index) {
              final user = blocked[index];
              final blockedId = user['blockedId'] ?? '';
              final name = user['displayName'] ?? 'Blocked User';
              final username = user['username'] ?? '';

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: AvatarWidget(name: name, radius: 22),
                title: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
                ),
                subtitle: Text(
                  '@$username',
                  style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 12.5),
                ),
                trailing: GestureDetector(
                  onTap: () async {
                    await userRepository.unblockUser(currentUserId: currentUserId, targetUserId: blockedId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Unblocked $name')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Unblock',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
