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
    final currentUserId = Provider.of<AuthRepository>(context).currentUid;

    if (currentUserId == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.cosmicGradient,
              ),
              child: const Icon(Icons.all_inclusive_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Text('Cosmic', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserSearchScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search in active conversations
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search chats...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                suffixIcon: _searchFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchFilter = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                fillColor: AppColors.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
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
                    child: CircularProgressIndicator(color: AppColors.primaryLight),
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
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: const Icon(Icons.chat_bubble_outline_rounded,
                              size: 40, color: AppColors.primaryLight),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap below to find friends and start chatting',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                          label: const Text('Find People'),
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

                return ListView.separated(
                  itemCount: chats.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  separatorBuilder: (_, __) => const Divider(
                    color: AppColors.cardBorder,
                    height: 1,
                    indent: 76,
                  ),
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

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: AvatarWidget(
                            name: displayName,
                            photoUrl: otherUser?.profilePhoto,
                            radius: 26,
                            isOnline: otherUser?.isOnline ?? false,
                            showOnlineIndicator: true,
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              chat.lastMessage.isNotEmpty ? chat.lastMessage : 'Tap to chat',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateFormatter.formatChatListTime(chat.lastMessageTime),
                                style: TextStyle(
                                  color: unreadCount > 0 ? AppColors.primaryLight : AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                              if (unreadCount > 0) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.cosmicGradient,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
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
        backgroundColor: AppColors.primary,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.cosmicGradient,
          ),
          child: const Icon(Icons.chat_rounded, color: Colors.white),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const UserSearchScreen()),
          );
        },
      ),
    );
  }
}
