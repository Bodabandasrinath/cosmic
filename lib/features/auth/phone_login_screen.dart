import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_text_field.dart';
import '../home/home_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();

  String _selectedCountryCode = '+91';
  bool _codeSent = false;
  String? _errorMessage;

  // Resend OTP Cooldown
  static const int _initialCooldownSeconds = 60;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'name': 'India', 'flag': '🇮🇳'},
    {'code': '+1', 'name': 'USA / Canada', 'flag': '🇺🇸'},
    {'code': '+44', 'name': 'UK', 'flag': '🇬🇧'},
    {'code': '+971', 'name': 'UAE', 'flag': '🇦🇪'},
    {'code': '+65', 'name': 'Singapore', 'flag': '🇸🇬'},
    {'code': '+61', 'name': 'Australia', 'flag': '🇦🇺'},
    {'code': '+49', 'name': 'Germany', 'flag': '🇩🇪'},
    {'code': '+33', 'name': 'France', 'flag': '🇫🇷'},
    {'code': '+81', 'name': 'Japan', 'flag': '🇯🇵'},
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = _initialCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  String _getFullPhoneNumber() {
    final cleanNumber = _phoneController.text.trim().replaceAll(' ', '').replaceAll('-', '');
    return '$_selectedCountryCode$cleanNumber';
  }

  Future<void> _sendOtp() async {
    setState(() => _errorMessage = null);

    if (!_phoneFormKey.currentState!.validate()) return;

    final fullPhone = _getFullPhoneNumber();
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    await authRepo.sendPhoneOtp(
      phoneNumber: fullPhone,
      onCodeSent: (id) {
        if (mounted) {
          setState(() {
            _codeSent = true;
            _errorMessage = null;
          });
          _startCooldown();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification code sent to $fullPhone'),
              backgroundColor: AppColors.callGreen,
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _errorMessage = error);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.callRed,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      },
    );
  }

  Future<void> _resendOtp() async {
    if (_cooldownSeconds > 0) return;
    await _sendOtp();
  }

  Future<void> _verifyOtp() async {
    setState(() => _errorMessage = null);

    if (!_otpFormKey.currentState!.validate()) return;

    final otp = _otpController.text.trim();
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    try {
      await authRepo.verifyPhoneOtp(
        smsCode: otp,
        displayName: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
        setState(() => _errorMessage = message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.callRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthRepository>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Phone Verification'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.cosmicGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.phone_android_rounded, size: 32, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  !_codeSent ? 'Enter Phone Number' : 'Enter 6-Digit Code',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  !_codeSent
                    ? 'Cosmic will send a 6-digit OTP code to verify your mobile number'
                    : 'We sent a verification SMS to ${_getFullPhoneNumber()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
              const SizedBox(height: 28),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.callRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.callRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.callRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!_codeSent) ...[
                // Phone Number Form
                Form(
                  key: _phoneFormKey,
                  child: Column(
                    children: [
                      // Country Code Selector + Phone Field
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                dropdownColor: AppColors.surface,
                                icon: const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                                items: _countryCodes.map((item) {
                                  return DropdownMenuItem<String>(
                                    value: item['code'],
                                    child: Text(
                                      '${item['flag']} ${item['code']}',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedCountryCode = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: CosmicTextField(
                              controller: _phoneController,
                              labelText: 'Mobile Number',
                              hintText: _selectedCountryCode == '+91' ? '98765 43210' : 'Mobile number',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (_selectedCountryCode == '+91') {
                                  return Validators.validateIndianPhone(val);
                                }
                                return Validators.validatePhone(val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      CosmicButton(
                        text: 'Send Verification Code',
                        isLoading: authRepo.isLoading,
                        onPressed: _sendOtp,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // OTP Code Form
                Form(
                  key: _otpFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CosmicTextField(
                        controller: _otpController,
                        labelText: '6-Digit SMS Code',
                        hintText: '123456',
                        prefixIcon: Icons.sms_outlined,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().length != 6) {
                            return 'Enter the complete 6-digit code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CosmicTextField(
                        controller: _nameController,
                        labelText: 'Your Name (if new user)',
                        hintText: 'e.g. Rahul Sharma',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 24),
                      CosmicButton(
                        text: 'Verify & Sign In',
                        isLoading: authRepo.isLoading,
                        onPressed: _verifyOtp,
                      ),
                      const SizedBox(height: 20),

                      // Resend OTP / Change number actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              _cooldownTimer?.cancel();
                              setState(() {
                                _codeSent = false;
                                _otpController.clear();
                                _errorMessage = null;
                              });
                            },
                            child: const Text(
                              'Change Number',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _cooldownSeconds == 0 ? _resendOtp : null,
                            child: Text(
                              _cooldownSeconds > 0
                                  ? 'Resend OTP in ${_cooldownSeconds}s'
                                  : 'Resend OTP',
                              style: TextStyle(
                                color: _cooldownSeconds == 0
                                    ? AppColors.primaryLight
                                    : AppColors.textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
