import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_text_field.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: _sent
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.mark_email_read_outlined,
                            size: 44, color: AppColors.primaryLight),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Password Reset Email Sent',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check ${_emailController.text} for instructions to reset your password.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      CosmicButton(
                        text: 'Back to Login',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Forgot your password?',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the email address registered with your Cosmic account and we will send you a password reset link.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      CosmicTextField(
                        controller: _emailController,
                        labelText: 'Email Address',
                        hintText: 'name@example.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.validateEmail,
                      ),
                      const SizedBox(height: 28),
                      CosmicButton(
                        text: 'Send Reset Link',
                        isLoading: authRepo.isLoading,
                        onPressed: _handleReset,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
