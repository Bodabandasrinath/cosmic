import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/storage_repository.dart';
import '../../widgets/cosmic_button.dart';
import '../../widgets/cosmic_text_field.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageExtension;
  bool _isUploadingPhoto = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageExtension = ext;
          if (!kIsWeb) {
            _selectedImage = File(picked.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryLight),
              title: const Text('Choose from Gallery', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.secondary),
              title: const Text('Take a Photo', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppColors.callRed,
        ),
      );
      return;
    }

    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final storageRepo = StorageRepository();

    try {
      // 1. Create account and user profile in Firestore at canonical users/{uid}
      final user = await authRepo.registerWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        name: _displayNameController.text,
        username: _usernameController.text,
        phone: _phoneController.text,
      );

      // 2. Upload profile photo if selected
      if (_selectedImageBytes != null || _selectedImage != null) {
        setState(() => _isUploadingPhoto = true);
        try {
          final photoUrl = await storageRepo.uploadProfilePhoto(
            userId: user.uid,
            imageBytes: _selectedImageBytes,
            imageFile: _selectedImage,
            fileExtension: _selectedImageExtension,
          );

          await authRepo.updateUserProfile(
            photoURL: photoUrl,
            profilePhoto: photoUrl,
          );
        } catch (photoError) {
          if (kDebugMode) print('Profile photo upload error during registration: $photoError');
        }
      }

      // 3. Navigate to home screen only after successful profile creation
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        String message = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.callRed,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
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
        title: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Photo Avatar with Edit Badge & Story Gradient
                Center(
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.instagramStoryGradient,
                        ),
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1E1E1E),
                          ),
                          child: ClipOval(
                            child: _selectedImageBytes != null
                                ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                                : (_selectedImage != null
                                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                                    : const Icon(Icons.person_rounded, size: 50, color: Colors.white70)),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _showImagePickerSheet,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: AppColors.igBlue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Add Profile Photo',
                    style: TextStyle(color: AppColors.igMutedGrey, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 24),

                // Name / Display Name
                CosmicTextField(
                  controller: _displayNameController,
                  labelText: 'Full Name',
                  hintText: 'Full Name',
                  prefixIcon: Icons.badge_outlined,
                  validator: Validators.validateDisplayName,
                ),
                const SizedBox(height: 14),

                // Username
                CosmicTextField(
                  controller: _usernameController,
                  labelText: 'Username',
                  hintText: 'Username',
                  prefixIcon: Icons.alternate_email,
                  validator: Validators.validateUsername,
                ),
                const SizedBox(height: 14),

                // Email
                CosmicTextField(
                  controller: _emailController,
                  labelText: 'Email',
                  hintText: 'Email address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.validateEmail,
                ),
                const SizedBox(height: 14),

                // Phone
                CosmicTextField(
                  controller: _phoneController,
                  labelText: 'Mobile Number (Optional)',
                  hintText: '+91 98765 43210',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: Validators.validatePhone,
                ),
                const SizedBox(height: 14),

                // Password
                CosmicTextField(
                  controller: _passwordController,
                  labelText: 'Password',
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: Validators.validatePassword,
                ),
                const SizedBox(height: 14),

                // Confirm Password
                CosmicTextField(
                  controller: _confirmPasswordController,
                  labelText: 'Confirm Password',
                  hintText: 'Confirm Password',
                  prefixIcon: Icons.lock_reset_rounded,
                  isPassword: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Please confirm password';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Submit Button (Instagram Blue)
                CosmicButton(
                  text: 'Sign up',
                  isLoading: authRepo.isLoading || _isUploadingPhoto,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 24),

                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Have an account? ',
                      style: TextStyle(color: AppColors.igMutedGrey, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: AppColors.igBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
