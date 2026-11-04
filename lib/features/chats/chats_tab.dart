import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/avatar_widget.dart';
import 'chat_screen.dart';
import '../contacts/user_search_screen.dart';

class ChatsTab extends StatefulWidget {
  const ChatsTab({super.key});

  @override
  State<ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends State<ChatsTab> {
  final ChatRepository _chatRepository = ChatRepository();
  final UserRepository _userRepository = UserRepository();
  final TextEditingController _searchController = TextEditingController();
  String _searchFilter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthRepository>(context);
    final currentUserId = authRepo.currentUid;
    final currentUser = authRepo.currentUser;

    if (currentUserId == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.igBlue));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Text(
              currentUser?.username != null && currentUser!.username.isNotEmpty
                  ? currentUser.username
                  : 'Cosmic Direct',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Colors.white, letterSpacing: -0.5),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 20),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.white, size: 22),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Instagram Capsule Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: const TextStyle(color: AppColors.igMutedGrey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppColors.igMutedGrey, size: 20),
                  suffixIcon: _searchFilter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.igMutedGrey, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchFilter = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),

          // Conversation Stream
          Expanded(
            child: StreamBuilder<List<ChatModel>>(
              stream: _chatRepository.streamUserConversations(currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.igBlue),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading chats: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.callRed)),
                  );
                }

                final chats = snapshot.data ?? [];
                if (chats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1E1E1E),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, size: 36, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your Messages',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Send private photos, videos, and calls to a friend.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.igMutedGrey),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.igBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Send Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const UserSearchScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: chats.length,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final otherUserId = chat.participants.firstWhere(
                      (p) => p != currentUserId,
                      orElse: () => '',
                    );

                    return FutureBuilder<UserModel?>(
                      future: _userRepository.getUserById(otherUserId),
                      builder: (context, userSnapshot) {
                        final otherUser = userSnapshot.data;
                        final displayName = otherUser?.displayName ?? 'Cosmic User';
                        final username = otherUser?.username ?? '';

                        // Apply search filter
                        if (_searchFilter.isNotEmpty) {
                          final match = displayName.toLowerCase().contains(_searchFilter) ||
                              username.toLowerCase().contains(_searchFilter) ||
                              chat.lastMessage.toLowerCase().contains(_searchFilter);
                          if (!match) return const SizedBox.shrink();
                        }

                        final unreadCount = chat.unreadCounts[currentUserId] ?? 0;
                        final hasUnread = unreadCount > 0;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          leading: Stack(
                            children: [
                              AvatarWidget(
                                name: displayName,
                                photoUrl: otherUser?.profilePhoto,
                                radius: 28,
                              ),
                              if (otherUser?.isOnline == true)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 13,
                                    height: 13,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E676),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(
                            displayName,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    chat.lastMessage.isNotEmpty ? chat.lastMessage : 'Sent an attachment',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: hasUnread ? Colors.white : AppColors.igMutedGrey,
                                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '· ${DateFormatter.formatChatListTime(chat.lastMessageTime)}',
                                  style: const TextStyle(
                                    color: AppColors.igMutedGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.igBlue,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              else
                                const Icon(Icons.camera_alt_outlined, color: AppColors.igMutedGrey, size: 22),
                            ],
                          ),
                          onTap: () {
                            if (otherUser != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    otherUser: otherUser,
                                    chatId: chat.id,
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF262626),
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 24),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UserSearchScreen()),
          );
        },
      ),
    );
  }
}
