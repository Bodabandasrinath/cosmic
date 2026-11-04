import 'dart:async';
import 'package:flutter/foundation.dart';
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

class _ChatScreenState extends State<ChatScreen> {
  final ChatRepository _chatRepository = ChatRepository();
  final StorageRepository _storageRepository = StorageRepository();
  final PresenceService _presenceService = PresenceService();
  final CallRepository _callRepository = CallRepository();
  final AudioRecorder _audioRecorder = AudioRecorder();

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _chatId;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  double? _uploadProgress;
  MessageModel? _replyingTo;

  @override
  void initState() {
    super.initState();
    final currentUserId = Provider.of<AuthRepository>(context, listen: false).currentUid!;
    _chatId = widget.chatId ?? _chatRepository.getChatId(currentUserId, widget.otherUser.uid);

    // Mark messages as seen when entering chat
    _chatRepository.markMessagesAsSeen(chatId: _chatId, currentUserId: currentUserId);

    // Typing listener
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
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
        file = await picker.pickImage(source: source, imageQuality: 80);
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primaryLight),
              title: const Text('Photo Gallery', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.gallery, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.secondary),
              title: const Text('Take Photo', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.camera, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded, color: AppColors.accentPink),
              title: const Text('Video from Gallery', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendMedia(ImageSource.gallery, true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_call_rounded, color: AppColors.accentElectric),
              title: const Text('Record Video', style: TextStyle(color: AppColors.textPrimary)),
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

  // --- Direct 1-to-1 Calls (NO ROOM ID!) ---
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthRepository>(context).currentUid!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<Map<String, dynamic>>(
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
                    AvatarWidget(
                      name: widget.otherUser.displayName,
                      photoUrl: widget.otherUser.profilePhoto,
                      radius: 20,
                      isOnline: isOnline,
                      showOnlineIndicator: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.otherUser.displayName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isTyping
                                ? 'typing...'
                                : (isOnline ? 'Online' : DateFormatter.formatLastSeen(lastSeen)),
                            style: TextStyle(
                              fontSize: 12,
                              color: isTyping || isOnline ? AppColors.online : AppColors.textMuted,
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
        actions: [
          // Direct Voice Call 📞
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.secondary),
            onPressed: () => _initiateCall(CallType.voice),
          ),
          // Direct Video Call 🎥
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: AppColors.primaryLight),
            onPressed: () => _initiateCall(CallType.video),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Upload Progress Bar
          if (_uploadProgress != null)
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: AppColors.surface,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryLight),
            ),

          // Messages List Stream
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatRepository.streamMessages(_chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primaryLight));
                }

                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.waving_hand_rounded, size: 48, color: AppColors.primaryLight),
                        const SizedBox(height: 12),
                        Text(
                          'Say hello to ${widget.otherUser.displayName}!',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // reverse so latest is at bottom
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == currentUserId;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Reply Banner
          if (_replyingTo != null) _buildReplyPreview(),

          // Composer Input
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        children: [
          Container(width: 4, height: 36, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!.senderId == Provider.of<AuthRepository>(context, listen: false).currentUid
                      ? 'You'
                      : widget.otherUser.displayName,
                  style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.bold),
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
            icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bottomBar,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.8)),
      ),
      child: Row(
        children: [
          if (!_isRecording) ...[
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primaryLight, size: 26),
              onPressed: _showAttachmentSheet,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: 4,
                  minLines: 1,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Type a cosmic message...',
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            // Recording UI
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.callRed),
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
                  const Text('Recording voice...', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],

          // Record / Send Button
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopAndSendRecording(),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: Icon(
                  _isRecording
                      ? Icons.send
                      : (_textController.text.trim().isEmpty ? Icons.mic_rounded : Icons.send_rounded),
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  if (_isRecording) {
                    _stopAndSendRecording();
                  } else if (_textController.text.trim().isNotEmpty) {
                    _sendTextMessage();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.bubbleSent : AppColors.bubbleReceived,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
            border: !isMe ? Border.all(color: AppColors.bubbleBorder) : null,
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Reply Quote inside bubble
              if (msg.replyToText != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: isMe ? Colors.white : AppColors.primary, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.replyToSenderName ?? 'Reply',
                        style: TextStyle(
                          color: isMe ? Colors.white70 : AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        msg.replyToText!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],

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
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: msg.mediaUrl!,
                      width: 220,
                      height: 220,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 220,
                        height: 220,
                        color: Colors.black12,
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
                  style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.3),
                ),
              ],

              const SizedBox(height: 4),

              // Timestamp & Status Ticks
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormatter.formatMessageTime(msg.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white.withValues(alpha: 0.7) : AppColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      msg.isSeen ? Icons.done_all : Icons.done,
                      size: 14,
                      color: msg.isSeen ? AppColors.secondary : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.primaryLight),
              title: const Text('Reply', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyingTo = msg);
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.callRed),
                title: const Text('Delete Message', style: TextStyle(color: AppColors.callRed)),
                onTap: () {
                  Navigator.pop(context);
                  _chatRepository.deleteMessage(
                    chatId: _chatId,
                    messageId: msg.id,
                    senderId: msg.senderId,
                    currentUserId: Provider.of<AuthRepository>(context, listen: false).currentUid!,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
