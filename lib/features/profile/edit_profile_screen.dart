import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:universal_io/io.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/storage_repository.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/avatar_widget.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserRepository _userRepository = UserRepository();
  final StorageRepository _storageRepository = StorageRepository();

  late TextEditingController _displayNameController;
  late TextEditingController _bioController;
  late TextEditingController _phoneController;

  File? _newImageFile;
  Uint8List? _newImageBytes;
  String? _newImageExtension;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthRepository>(context, listen: false).currentUser!;
    _displayNameController = TextEditingController(text: user.displayName);
    _bioController = TextEditingController(text: user.bio);
    _phoneController = TextEditingController(text: user.phone);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
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
          _newImageBytes = bytes;
          _newImageExtension = ext;
          if (!kIsWeb) {
            _newImageFile = File(picked.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error choosing photo: $e')),
        );
      }
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFF4A4A4A), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              title: const Text('Take a Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authRepo = Provider.of<AuthRepository>(context, listen: false);
    final user = authRepo.currentUser!;

    setState(() => _isSaving = true);
    try {
      String? photoUrl;
      if (_newImageBytes != null || _newImageFile != null) {
        photoUrl = await _storageRepository.uploadProfilePhoto(
          userId: user.uid,
          imageBytes: _newImageBytes,
          imageFile: _newImageFile,
          fileExtension: _newImageExtension,
        );
      }

      await _userRepository.updateUserProfile(
        uid: user.uid,
        name: _displayNameController.text,
        displayName: _displayNameController.text,
        bio: _bioController.text,
        phone: _phoneController.text,
        photoURL: photoUrl,
        profilePhoto: photoUrl,
      );

      await authRepo.fetchCurrentUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.callRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthRepository>(context).currentUser!;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: false,
        actions: [
          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.igBlue),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check_rounded, color: AppColors.igBlue, size: 28),
                  onPressed: _saveProfile,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar Change
              Center(
                child: GestureDetector(
                  onTap: _showImagePickerSheet,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.instagramStoryGradient,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                          ),
                          child: _newImageBytes != null
                              ? ClipOval(
                                  child: Image.memory(_newImageBytes!, width: 92, height: 92, fit: BoxFit.cover),
                                )
                              : (_newImageFile != null
                                  ? ClipOval(
                                      child: Image.file(_newImageFile!, width: 92, height: 92, fit: BoxFit.cover),
                                    )
                                  : AvatarWidget(
                                      name: user.displayName,
                                      photoUrl: user.profilePhoto,
                                      radius: 46,
                                    )),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _showImagePickerSheet,
                  child: const Text(
                    'Edit picture or avatar',
                    style: TextStyle(
                      color: AppColors.igBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Fields in Instagram style
              _buildFieldLabel('Name'),
              _buildTextInput(
                controller: _displayNameController,
                hint: 'Name',
                validator: Validators.validateDisplayName,
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Username'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF262626)),
                ),
                child: Row(
                  children: [
                    const Text('@', style: TextStyle(color: Color(0xFF8E8E8E), fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(
                      user.username,
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    const Icon(Icons.lock_outline_rounded, color: Color(0xFF8E8E8E), size: 16),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Bio'),
              _buildTextInput(
                controller: _bioController,
                hint: 'Write a bio...',
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Phone number'),
              _buildTextInput(
                controller: _phoneController,
                hint: '+91 98765 43210',
                keyboardType: TextInputType.phone,
                validator: Validators.validatePhone,
              ),
              const SizedBox(height: 32),

              // Blue Instagram Submit Button
              GestureDetector(
                onTap: _isSaving ? null : _saveProfile,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.igBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Done',
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
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, left: 2.0),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8E8E8E),
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
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
    );
  }
}
