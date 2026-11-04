import 'package:flutter/material.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/phone_login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/contacts/user_search_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/blocked_users_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/splash/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot_password';
  static const String phoneLogin = '/phone_login';
  static const String home = '/home';
  static const String search = '/search';
  static const String settings = '/settings';
  static const String blocked = '/blocked';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashScreen(),
        login: (_) => const LoginScreen(),
        register: (_) => const RegisterScreen(),
        forgotPassword: (_) => const ForgotPasswordScreen(),
        phoneLogin: (_) => const PhoneLoginScreen(),
        home: (_) => const HomeScreen(),
        search: (_) => const UserSearchScreen(),
        settings: (_) => const SettingsScreen(),
        blocked: (_) => const BlockedUsersScreen(),
      };
}
