class AppConstants {
  static const String appName = 'Cosmic';
  static const String appTagline = 'Connect beyond distance.';
  
  // Collections in Firestore
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String callsCollection = 'calls';
  static const String contactsSubcollection = 'contacts';
  static const String blockedSubcollection = 'blocked';
  static const String callLogsCollection = 'call_logs';
  static const String typingSubcollection = 'typing';

  // Call Signaling Subcollections
  static const String callerCandidatesSubcollection = 'callerCandidates';
  static const String receiverCandidatesSubcollection = 'receiverCandidates';

  // WebRTC ICE Servers (STUN)
  static const List<Map<String, dynamic>> iceServers = [
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
        'stun:stun3.l.google.com:19302',
        'stun:stun4.l.google.com:19302',
      ],
    },
  ];

  // Calling timeouts
  static const int callTimeoutSeconds = 45;

  // Shared Preferences Keys
  static const String keyDarkMode = 'cosmic_dark_mode';
  static const String keyNotificationsEnabled = 'cosmic_notifications_enabled';
  static const String keyOnlineVisibility = 'cosmic_online_visibility';
  static const String keyReadReceipts = 'cosmic_read_receipts';
}
