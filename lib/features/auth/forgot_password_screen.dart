import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/auth_repository.dart';
import 'register_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    try {
      await authRepo.sendPasswordResetEmail(_emailController.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.callRed),
        );
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: _sent
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF121212),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF262626), width: 1.5),
                        ),
                        child: const Icon(Icons.mark_email_read_outlined, size: 40, color: AppColors.igBlue),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Login Link Sent',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'We sent an email to ${_emailController.text} with a link to get back into your account.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF8E8E8E), fontSize: 13.5, height: 1.4),
                      ),
                      const SizedBox(height: 32),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.igBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Back to Login',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 20),
                              Center(
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.lock_outline_rounded, size: 44, color: Colors.white),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Center(
                                child: Text(
                                  'Trouble logging in?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Enter your email and we\'ll send you a link to reset your password and get back into your account.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 13.5, height: 1.4),
                              ),
                              const SizedBox(height: 24),

                              TextFormField(
                                controller: _emailController,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                keyboardType: TextInputType.emailAddress,
                                validator: Validators.validateEmail,
                                decoration: InputDecoration(
                                  hintText: 'Email address',
                                  hintStyle: const TextStyle(color: Color(0xFF555555), fontSize: 14),
                                  filled: true,
                                  fillColor: const Color(0xFF121212),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                              const SizedBox(height: 20),

                              GestureDetector(
                                onTap: authRepo.isLoading ? null : _handleReset,
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
                                          'Send login link',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // OR divider
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: Color(0xFF262626))),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Color(0xFF8E8E8E),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Color(0xFF262626))),
                                ],
                              ),
                              const SizedBox(height: 24),

                              Center(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                    );
                                  },
                                  child: const Text(
                                    'Create new account',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Bottom back to login bar
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0xFF1C1C1E))),
                      ),
                      child: Center(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Back to login',
                            style: TextStyle(
                              color: Color(0xFF8E8E8E),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
