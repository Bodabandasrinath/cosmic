import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/auth_repository.dart';
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
        }
      },
    );
  }

  Future<void> _resendOtp() async {
    if (_cooldownSeconds > 0) return;
    setState(() => _errorMessage = null);

    final fullPhone = _getFullPhoneNumber();
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    await authRepo.resendPhoneOtp(
      phoneNumber: fullPhone,
      onCodeSent: (id) {
        if (mounted) {
          _startCooldown();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('New code sent to $fullPhone'),
              backgroundColor: AppColors.callGreen,
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _errorMessage = error);
        }
      },
    );
  }

  Future<void> _verifyOtp() async {
    setState(() => _errorMessage = null);

    if (!_otpFormKey.currentState!.validate()) return;

    final smsCode = _otpController.text.trim();
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : null;

    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    try {
      await authRepo.verifyPhoneOtp(
        smsCode: smsCode,
        displayName: name,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthRepository>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.instagramStoryGradient,
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                    ),
                    child: const Icon(
                      Icons.phone_android_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  !_codeSent ? 'Enter your mobile number' : 'Enter confirmation code',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  !_codeSent
                      ? 'Cosmic will send a 6-digit verification code to this mobile number.'
                      : 'We sent a verification code to ${_getFullPhoneNumber()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 13.5, height: 1.4),
                ),
              ),
              const SizedBox(height: 28),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1014),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.igHeartRed.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.igHeartRed, size: 20),
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
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF121212),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF262626)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCountryCode,
                                dropdownColor: const Color(0xFF1E1E1E),
                                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8E8E8E)),
                                items: _countryCodes.map((item) {
                                  return DropdownMenuItem<String>(
                                    value: item['code'],
                                    child: Text(
                                      '${item['flag']} ${item['code']}',
                                      style: const TextStyle(
                                        color: Colors.white,
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
                            child: TextFormField(
                              controller: _phoneController,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (_selectedCountryCode == '+91') {
                                  return Validators.validateIndianPhone(val);
                                }
                                return Validators.validatePhone(val);
                              },
                              decoration: InputDecoration(
                                hintText: _selectedCountryCode == '+91' ? '98765 43210' : 'Mobile number',
                                hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 14),
                                filled: true,
                                fillColor: const Color(0xFF121212),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF262626)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFF262626)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.igBlue, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: authRepo.isLoading ? null : _sendOtp,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.igBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: authRepo.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Send Code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
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
                      TextFormField(
                        controller: _otpController,
                        style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 4),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().length != 6) {
                            return 'Enter the complete 6-digit code';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: '1 2 3 4 5 6',
                          hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 16, letterSpacing: 4),
                          filled: true,
                          fillColor: const Color(0xFF121212),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF262626)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF262626)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.igBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Full name (optional if already registered)',
                          hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 14),
                          filled: true,
                          fillColor: const Color(0xFF121212),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF262626)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF262626)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.igBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: authRepo.isLoading ? null : _verifyOtp,
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.igBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: authRepo.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Confirm',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
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
                              style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: _cooldownSeconds == 0 ? _resendOtp : null,
                            child: Text(
                              _cooldownSeconds > 0
                                  ? 'Resend in ${_cooldownSeconds}s'
                                  : 'Resend SMS code',
                              style: TextStyle(
                                color: _cooldownSeconds == 0
                                    ? AppColors.igBlue
                                    : const Color(0xFF555555),
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
