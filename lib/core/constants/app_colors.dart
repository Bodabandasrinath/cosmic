import 'package:flutter/material.dart';

class AppColors {
  // Cosmic Dark Backgrounds
  static const Color background = Color(0xFF0B0E17);
  static const Color surface = Color(0xFF13192B);
  static const Color card = Color(0xFF1B2238);
  static const Color cardBorder = Color(0xFF28334E);
  static const Color bottomBar = Color(0xFF0F1524);

  // Cosmic Nebula Brand Accents
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color secondary = Color(0xFF00D2D3);
  static const Color cyan = Color(0xFF00D2D3);
  static const Color electricBlue = Color(0xFF54A0FF);
  static const Color nebulaPink = Color(0xFFFF7675);
  static const Color accentPink = Color(0xFFFF7675);
  static const Color accentElectric = Color(0xFF54A0FF);

  // Typography
  static const Color textPrimary = Color(0xFFF1F2F6);
  static const Color textSecondary = Color(0xFFA4B0BE);
  static const Color textMuted = Color(0xFF57606F);

  // Message Bubbles
  static const Color bubbleSent = Color(0xFF6C5CE7);
  static const Color bubbleReceived = Color(0xFF1B2238);
  static const Color bubbleBorder = Color(0xFF28334E);

  // Real-time Indicators & Calling
  static const Color online = Color(0xFF00E676);
  static const Color offline = Color(0xFF747D8C);
  static const Color callGreen = Color(0xFF2ED573);
  static const Color callRed = Color(0xFFFF4757);
  static const Color callAmber = Color(0xFFFFA502);

  // Gradients
  static const LinearGradient cosmicGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF8C7AE6)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient callGradient = LinearGradient(
    colors: [Color(0xFF2ED573), Color(0xFF10AC84)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient endCallGradient = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFEE5253)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
