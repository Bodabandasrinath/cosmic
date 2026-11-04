import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/call_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/call_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/storage_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/presence_service.dart';
import '../../widgets/audio_bubble_player.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/video_bubble_player.dart';
import '../calls/active_voice_call_screen.dart';
import '../calls/active_video_call_screen.dart';
import 'fullscreen_media_viewer.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  final String? chatId;

  const ChatScreen({
    super.key,
    required this.otherUser,
    this.chatId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatRepository _chatRepository = ChatRepository();
  final StorageRepository _storageRepository = StorageRepository();
  final PresenceService _presenceService = PresenceService();
  final CallRepository _callRepository = CallRepository();
  final UserRepository _userRepository = UserRepository();
  final AudioRecorder _audioRecorder = AudioRecorder();

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _chatId;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  double? _uploadProgress;
  MessageModel? _replyingTo;
  bool _isSearching = false;

  // Instagram Double-Tap Heart animation tracker
  String? _animatingHeartMessageId;

  static const List<String> _reactionEmojis = ['❤️', '🙌', '🔥', '👏', '😂', '😮', '😢'];

  @override
  void initState() {
    super.initState();
    final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid!;
    _chatId = widget.chatId ?? _chatRepository.getChatId(currentUserId, widget.otherUser.uid);

    // Mark messages as seen & delivered when entering chat
    _chatRepository.markMessagesAsSeen(chatId: _chatId, currentUserId: currentUserId);
    _chatRepository.markMessagesAsDelivered(chatId: _chatId, currentUserId: currentUserId);

    // Typing listener
    _textController.addListener(_onTextChanged);
    _searchController.addListener(() => setState(() {}));
  }

  void _onTextChanged() {
    setState(() {}); // Updates send/heart button dynamically
    final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid;
    if (currentUserId != null) {
      _presenceService.sendTypingStatus(
        chatId: _chatId,
        userId: currentUserId,
        isTyping: _textController.text.trim().isNotEmpty,
      );
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _presenceService.dispose();
    super.dispose();
  }

  // --- Voice Message Recording ---
  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        if (mounted) {
          setState(() {
            _isRecording = true;
            _recordingSeconds = 0;
          });
        }

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) setState(() => _recordingSeconds++);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop();

    if (mounted) setState(() => _isRecording = false);

    if (path != null && _recordingSeconds > 0) {
      final file = File(path);
      if (await file.exists()) {
        if (!mounted) return;
        final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid!;
        setState(() => _uploadProgress = 0.1);

        try {
          final bytes = await file.readAsBytes();
          final audioUrl = await _storageRepository.uploadChatMedia(
            chatId: _chatId,
            file: !kIsWeb ? file : null,
            bytes: bytes,
            fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
            mediaType: 'audio',
            onProgress: (p) => setState(() => _uploadProgress = p),
          );

          await _chatRepository.sendMessage(
            chatId: _chatId,
            senderId: currentUserId,
            receiverId: widget.otherUser.uid,
            text: '🎤 Voice message',
            type: MessageType.audio,
            mediaUrl: audioUrl,
            durationSeconds: _recordingSeconds,
          );
        } finally {
          if (mounted) setState(() => _uploadProgress = null);
        }
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });
    }
  }

  // --- Media Attachments (Photos / Videos) ---
  Future<void> _pickAndSendMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    if (!mounted) return;
    final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid!;

    try {
      XFile? file;
      if (isVideo) {
        file = await picker.pickVideo(source: source);
      } else {
        file = await picker.pickImage(source: source, imageQuality: 85);
      }

      if (file == null || !mounted) return;

      setState(() => _uploadProgress = 0.1);

      final bytes = await file.readAsBytes();
      final mediaUrl = await _storageRepository.uploadChatMedia(
        chatId: _chatId,
        file: !kIsWeb ? File(file.path) : null,
        bytes: bytes,
        fileName: file.name,
        mediaType: isVideo ? 'video' : 'image',
        onProgress: (p) => setState(() => _uploadProgress = p),
      );

      await _chatRepository.sendMessage(
        chatId: _chatId,
        senderId: currentUserId,
        receiverId: widget.otherUser.uid,
        text: isVideo ? '🎥 Video' : '📷 Photo',
        type: isVideo ? MessageType.video : MessageType.image,
        mediaUrl: mediaUrl,
        replyToMessageId: _replyingTo?.id,
        replyToText: _replyingTo?.text,
        replyToSenderName: _replyingTo != null
            ? (_replyingTo!.senderId == currentUserId ? 'You' : widget.otherUser.displayName)
            : null,
      );

      if (mounted) setState(() => _replyingTo = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload media: $e'), backgroundColor: AppColors.callRed),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.igDarkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF262626)),
                child: const Icon(Icons.photo_library_rounded, color: AppColors.igBlue, size: 22),
              ),
              title: const Text('Photo & Video Library', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.gallery, false);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF262626)),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.nebulaPink, size: 22),
              ),
              title: const Text('Camera', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.camera, false);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF262626)),
                child: const Icon(Icons.videocam_rounded, color: AppColors.secondary, size: 22),
              ),
              title: const Text('Record Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.camera, true);
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- Send Text Message ---
  Future<void> _sendTextMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid!;
    _textController.clear();

    await _chatRepository.sendMessage(
      chatId: _chatId,
      senderId: currentUserId,
      receiverId: widget.otherUser.uid,
      text: text,
      type: MessageType.text,
      replyToMessageId: _replyingTo?.id,
      replyToText: _replyingTo?.text,
      replyToSenderName: _replyingTo != null
          ? (_replyingTo!.senderId == currentUserId ? 'You' : widget.otherUser.displayName)
          : null,
    );

    setState(() => _replyingTo = null);
  }

  // --- Instagram Instant Heart ❤️ Button ---
  Future<void> _sendInstantHeart() async {
    final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid!;
    HapticFeedback.lightImpact();

    await _chatRepository.sendMessage(
      chatId: _chatId,
      senderId: currentUserId,
      receiverId: widget.otherUser.uid,
      text: '❤️',
      type: MessageType.text,
    );
  }

  // --- Direct 1-to-1 Calls (Instagram Direct Style) ---
  Future<void> _initiateCall(CallType type) async {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final currentUser = authRepo.currentUser;
    if (currentUser == null) return;

    try {
      final call = await _callRepository.initiateDirectCall(
        caller: currentUser,
        receiver: widget.otherUser,
        type: type,
      );

      if (mounted) {
        if (type == CallType.video) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActiveVideoCallScreen(call: call, isCaller: true),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ActiveVoiceCallScreen(call: call, isCaller: true),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e'), backgroundColor: AppColors.callRed),
        );
      }
    }
  }

  // --- Instagram User Details Sheet ---
  void _showUserProfileSheet() {
    final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid!;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.igDarkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.instagramStoryGradient,
                ),
                child: AvatarWidget(
                  name: widget.otherUser.displayName,
                  photoUrl: widget.otherUser.profilePhoto,
                  radius: 46,
                  isOnline: widget.otherUser.isOnline,
                  showOnlineIndicator: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.otherUser.displayName,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '@${widget.otherUser.username}',
                style: const TextStyle(fontSize: 14, color: AppColors.igMutedGrey),
              ),
              if (widget.otherUser.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.otherUser.bio,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: 20),
              // Call action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF262626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Audio'),
                    onPressed: () {
                      Navigator.pop(context);
                      _initiateCall(CallType.voice);
                    },
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.igBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.videocam_rounded, size: 18),
                    label: const Text('Video'),
                    onPressed: () {
                      Navigator.pop(context);
                      _initiateCall(CallType.video);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.igDarkBorder),
              ListTile(
                leading: const Icon(Icons.search_rounded, color: Colors.white),
                title: const Text('Search in Chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _isSearching = true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppColors.callAmber),
                title: Text('Block ${widget.otherUser.displayName}', style: const TextStyle(color: AppColors.callAmber)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlockUser(currentUserId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_rounded, color: AppColors.callRed),
                title: Text('Report ${widget.otherUser.displayName}', style: const TextStyle(color: AppColors.callRed)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(currentUserId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmBlockUser(String currentUserId) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.igDarkSurface,
        title: Text('Block ${widget.otherUser.displayName}?'),
        content: const Text(
          'Blocked users will not be able to send you messages or start audio/video calls with you.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.callRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _userRepository.blockUser(
                  currentUserId: currentUserId,
                  targetUser: widget.otherUser,
                );
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('${widget.otherUser.displayName} has been blocked.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Failed to block user: $e'), backgroundColor: AppColors.callRed),
                  );
                }
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(String currentUserId) {
    final messenger = ScaffoldMessenger.of(context);
    String selectedReason = 'Spam or Scam';
    final reasons = [
      'Spam or Scam',
      'Harassment or Bullying',
      'Inappropriate Content',
      'Impersonation',
      'Other',
    ];
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.igDarkSurface,
          title: Text('Report ${widget.otherUser.displayName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Why are you reporting this user?', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                ...reasons.map((r) {
                  final isSelected = selectedReason == r;
                  return InkWell(
                    onTap: () => setDialogState(() => selectedReason = r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isSelected ? AppColors.igBlue : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r,
                              style: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    fillColor: Color(0xFF262626),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.callRed),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _userRepository.reportUser(
                    reporterId: currentUserId,
                    reportedUserId: widget.otherUser.uid,
                    reason: selectedReason,
                    details: detailsController.text.trim(),
                  );
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Report submitted. Thank you for keeping Cosmic safe.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: AppColors.callRed),
                    );
                  }
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthRepository>(context).currentUid!;

    return Scaffold(
      backgroundColor: AppColors.igDarkBackground,
      appBar: _isSearching ? _buildSearchAppBar() : _buildInstagramAppBar(),
      body: Column(
        children: [
          // Upload Progress Bar
          if (_uploadProgress != null)
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: AppColors.igDarkSurface,
              valueColor: const AlwaysStoppedAnimation(AppColors.igBlue),
            ),

          // Messages List Stream
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatRepository.streamMessages(_chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.igBlue));
                }

                final allMessages = snapshot.data ?? [];
                final messages = _isSearching && _searchController.text.trim().isNotEmpty
                    ? _chatRepository.filterMessages(allMessages, _searchController.text)
                    : allMessages;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.instagramStoryGradient,
                          ),
                          child: AvatarWidget(
                            name: widget.otherUser.displayName,
                            photoUrl: widget.otherUser.profilePhoto,
                            radius: 42,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          widget.otherUser.displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '@${widget.otherUser.username}',
                          style: const TextStyle(color: AppColors.igMutedGrey, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSearching
                              ? 'No messages found for "${_searchController.text.trim()}"'
                              : 'Instagram Direct chat with ${widget.otherUser.displayName}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // reverse so latest is at bottom
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return _buildMessageBubble(msg, isMe, currentUserId);
                  },
                );
              },
            ),
          ),

          // Reply Banner
          if (_replyingTo != null) _buildReplyPreview(),

          // Instagram Capsule Composer Input
          _buildInstagramComposer(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
        },
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: const TextStyle(color: AppColors.igMutedGrey),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.igMutedGrey, size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildInstagramAppBar() {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: GestureDetector(
        onTap: _showUserProfileSheet,
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _presenceService.getUserPresence(widget.otherUser.uid),
          builder: (context, presenceSnapshot) {
            final isOnline = presenceSnapshot.data?['isOnline'] ?? widget.otherUser.isOnline;
            final lastSeen = presenceSnapshot.data?['lastSeen'] as DateTime? ?? widget.otherUser.lastSeen;

            return StreamBuilder<bool>(
              stream: _presenceService.getTypingStream(chatId: _chatId, otherUserId: widget.otherUser.uid),
              builder: (context, typingSnapshot) {
                final isTyping = typingSnapshot.data ?? false;

                return Row(
                  children: [
                    Stack(
                      children: [
                        AvatarWidget(
                          name: widget.otherUser.displayName,
                          photoUrl: widget.otherUser.profilePhoto,
                          radius: 18,
                        ),
                        if (isOnline)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.otherUser.displayName,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          Text(
                            isTyping
                                ? 'typing...'
                                : (isOnline ? 'Active now' : DateFormatter.formatLastSeen(lastSeen)),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isTyping ? FontWeight.w600 : FontWeight.normal,
                              color: isTyping ? AppColors.igBlue : AppColors.igMutedGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      actions: [
        // Voice Call 📞
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Colors.white, size: 22),
          onPressed: () => _initiateCall(CallType.voice),
        ),
        // Video Call 🎥
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: Colors.white, size: 26),
          onPressed: () => _initiateCall(CallType.video),
        ),
        // Info Profile Sheet
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 22),
          onPressed: _showUserProfileSheet,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: AppColors.igBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!.senderId == Provider.of<AuthRepository>(context, listen: false).currentUid
                      ? 'Replying to yourself'
                      : 'Replying to ${widget.otherUser.displayName}',
                  style: const TextStyle(color: AppColors.igBlue, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  _replyingTo!.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.igMutedGrey, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  // --- Instagram Direct Pill Composer Bar ---
  Widget _buildInstagramComposer() {
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 10,
        right: 10,
        top: 6,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF1E1E1E), width: 0.8)),
      ),
      child: Row(
        children: [
          if (!_isRecording) ...[
            // Capsule Input Container
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.igDarkBubbleReceived,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.igDarkBorder, width: 0.6),
                ),
                child: Row(
                  children: [
                    // Camera Action Button
                    GestureDetector(
                      onTap: _showAttachmentSheet,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.igBlue,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Text Field
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Message...',
                          hintStyle: TextStyle(color: AppColors.igMutedGrey, fontSize: 15),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          isDense: true,
                        ),
                      ),
                    ),

                    // Actions when text is EMPTY
                    if (!hasText) ...[
                      // Mic icon for voice
                      IconButton(
                        icon: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 22),
                        onPressed: _startRecording,
                      ),
                      // Gallery icon
                      IconButton(
                        icon: const Icon(Icons.photo_outlined, color: Colors.white, size: 22),
                        onPressed: () => _pickAndSendMedia(ImageSource.gallery, false),
                      ),
                      // Instant Heart Icon ❤️ (Classic Instagram)
                      IconButton(
                        icon: const Icon(Icons.favorite_rounded, color: AppColors.igHeartRed, size: 24),
                        onPressed: _sendInstantHeart,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // When user is typing: show Instagram "Send" button
            if (hasText) ...[
              const SizedBox(width: 6),
              TextButton(
                onPressed: _sendTextMessage,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Send',
                  style: TextStyle(
                    color: AppColors.igBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ] else ...[
            // Recording UI
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.callRed, size: 24),
              onPressed: _cancelRecording,
            ),
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.mic, color: AppColors.callRed, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_recordingSeconds ~/ 60}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  const Text('Recording voice...', style: TextStyle(color: AppColors.igMutedGrey, fontSize: 13)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.igBlue, size: 24),
              onPressed: _stopAndSendRecording,
            ),
          ],
        ],
      ),
    );
  }

  // --- Instagram Style Message Bubble ---
  Widget _buildMessageBubble(MessageModel msg, bool isMe, String currentUserId) {
    // Tally reactions
    final Map<String, int> reactionCounts = {};
    msg.reactions.forEach((uid, emoji) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    });

    final hasReactions = reactionCounts.isNotEmpty && !msg.isDeleted;
    final isOnlyHeart = msg.type == MessageType.text && msg.text == '❤️' && !msg.isDeleted;

    return Dismissible(
      key: Key('reply_${msg.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (dir) async {
        HapticFeedback.lightImpact();
        setState(() => _replyingTo = msg);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 16),
        child: const Icon(Icons.reply_rounded, color: AppColors.igBlue, size: 22),
      ),
      child: GestureDetector(
        onDoubleTap: msg.isDeleted
            ? null
            : () {
                // Trigger Instagram heart burst animation on bubble
                HapticFeedback.mediumImpact();
                setState(() => _animatingHeartMessageId = msg.id);
                Timer(const Duration(milliseconds: 700), () {
                  if (mounted && _animatingHeartMessageId == msg.id) {
                    setState(() => _animatingHeartMessageId = null);
                  }
                });

                _chatRepository.toggleReaction(
                  chatId: _chatId,
                  messageId: msg.id,
                  userId: currentUserId,
                  emoji: '❤️',
                );
              },
        onLongPress: msg.isDeleted ? null : () => _showMessageOptions(msg, isMe, currentUserId),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              bottom: hasReactions ? 14 : 3,
              top: 2,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isOnlyHeart)
                  // Giant Instagram Animated Heart
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('❤️', style: TextStyle(fontSize: 48)),
                  )
                else
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isMe && !msg.isDeleted ? AppColors.instagramSentGradient : null,
                      color: msg.isDeleted
                          ? const Color(0xFF1E1E1E)
                          : (!isMe ? AppColors.igDarkBubbleReceived : null),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22),
                        topRight: const Radius.circular(22),
                        bottomLeft: Radius.circular(isMe ? 22 : 6),
                        bottomRight: Radius.circular(isMe ? 6 : 22),
                      ),
                      border: !isMe && !msg.isDeleted
                          ? Border.all(color: AppColors.igDarkBorder, width: 0.5)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reply Quote inside bubble
                        if (msg.replyToText != null && !msg.isDeleted) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                              border: Border(left: BorderSide(color: isMe ? Colors.white : AppColors.igBlue, width: 3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg.replyToSenderName ?? 'Reply',
                                  style: TextStyle(
                                    color: isMe ? Colors.white70 : AppColors.igBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  msg.replyToText!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Deleted message view
                        if (msg.isDeleted) ...[
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block_rounded, size: 14, color: AppColors.igMutedGrey),
                              SizedBox(width: 6),
                              Text(
                                'This message was deleted',
                                style: TextStyle(
                                  color: AppColors.igMutedGrey,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Content based on Message Type
                          if (msg.type == MessageType.image && msg.mediaUrl != null) ...[
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FullscreenMediaViewer(mediaUrl: msg.mediaUrl!),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(
                                  imageUrl: msg.mediaUrl!,
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 220,
                                    height: 220,
                                    color: Colors.black26,
                                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                  ),
                                ),
                              ),
                            ),
                            if (msg.text.isNotEmpty && msg.text != '📷 Photo') ...[
                              const SizedBox(height: 6),
                              Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
                            ],
                          ] else if (msg.type == MessageType.video && msg.mediaUrl != null) ...[
                            VideoBubblePlayer(videoUrl: msg.mediaUrl!, durationSeconds: msg.durationSeconds),
                          ] else if (msg.type == MessageType.audio && msg.mediaUrl != null) ...[
                            AudioBubblePlayer(audioUrl: msg.mediaUrl!, durationSeconds: msg.durationSeconds, isSentByMe: isMe),
                          ] else ...[
                            // Plain Text
                            Text(
                              msg.text,
                              style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.25),
                            ),
                          ],
                        ],

                        const SizedBox(height: 3),

                        // Timestamp & Status Ticks
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormatter.formatMessageTime(msg.timestamp),
                              style: TextStyle(
                                color: isMe ? Colors.white70 : AppColors.igMutedGrey,
                                fontSize: 10,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 4),
                              Icon(
                                msg.isSeen
                                    ? Icons.done_all
                                    : (msg.isDelivered ? Icons.done_all : Icons.done),
                                size: 13,
                                color: msg.isSeen
                                    ? const Color(0xFF64B5F6) // Instagram seen cyan
                                    : (msg.isDelivered ? Colors.white70 : Colors.white38),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                // Animated Bouncing Heart Effect on Double-Tap (Iconic Instagram feature)
                if (_animatingHeartMessageId == msg.id)
                  Positioned.fill(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.3, end: 1.2),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.elasticOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: const Icon(
                              Icons.favorite_rounded,
                              color: AppColors.igHeartRed,
                              size: 54,
                              shadows: [
                                BoxShadow(color: Colors.black54, blurRadius: 16),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Instagram Mini Reaction Capsule underneath bubble
                if (hasReactions)
                  Positioned(
                    bottom: -10,
                    right: isMe ? 8 : null,
                    left: !isMe ? 8 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262626),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.black, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: reactionCounts.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              '${e.key}${e.value > 1 ? ' ${e.value}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Instagram Floating Reaction Capsule on Long Press ---
  void _showMessageOptions(MessageModel msg, bool isMe, String currentUserId) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floating Instagram Reaction Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(color: Colors.black87, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _reactionEmojis.map((emoji) {
                    final isSelected = msg.reactions[currentUserId] == emoji;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        _chatRepository.toggleReaction(
                          chatId: _chatId,
                          messageId: msg.id,
                          userId: currentUserId,
                          emoji: emoji,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white24 : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 26)),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Options Menu
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.reply_rounded, color: Colors.white, size: 22),
                      title: const Text('Reply', style: TextStyle(color: Colors.white)),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _replyingTo = msg);
                      },
                    ),
                    if (msg.type == MessageType.text && msg.text.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                        title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          Clipboard.setData(ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Message copied to clipboard')),
                          );
                        },
                      ),
                    if (isMe) ...[
                      const Divider(color: Color(0xFF3A3A3C), height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: AppColors.callRed, size: 22),
                        title: const Text('Unsend Message', style: TextStyle(color: AppColors.callRed, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          _chatRepository.deleteMessage(
                            chatId: _chatId,
                            messageId: msg.id,
                            senderId: msg.senderId,
                            currentUserId: currentUserId,
                            forEveryone: true,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
