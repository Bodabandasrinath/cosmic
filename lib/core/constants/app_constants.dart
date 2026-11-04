class AppConstants {
  static const String appName = 'Cosmic';
  static const String appTagline = 'Connect beyond distance.';

  // Collections in Firestore
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String conversationsCollection = 'chats'; // Canonical alias for Phase 5 structure
  static const String messagesCollection = 'messages';
  static const String callsCollection = 'calls';
  static const String contactsSubcollection = 'contacts';
  static const String blockedSubcollection = 'blocked';
  static const String callLogsCollection = 'call_logs';
  static const String typingSubcollection = 'typing';
  static const String notificationsSubcollection = 'notifications';
  static const String reportsCollection = 'reports';

  // Call Signaling Subcollections
  static const String callerCandidatesSubcollection = 'callerCandidates';
  static const String receiverCandidatesSubcollection = 'receiverCandidates';

  // WebRTC ICE Servers (STUN + TURN for symmetric NAT & mobile cellular networks)
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
    {
      'urls': [
        'stun:global.stun.twilio.com:3478',
      ],
    },
    {
      'urls': [
        'turn:openrelay.metered.ca:80',
        'turn:openrelay.metered.ca:443',
        'turn:openrelay.metered.ca:443?transport=tcp',
      ],
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
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
