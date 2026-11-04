class Validators {
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (trimmed.length > 24) {
      return 'Username cannot exceed 24 characters';
    }
    final regex = RegExp(r'^[a-zA-Z0-9_.]+$');
    if (!regex.hasMatch(trimmed)) {
      return 'Only letters, numbers, underscores, and dots are allowed';
    }
    return null;
  }

  static String? validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length > 50) {
      return 'Name cannot exceed 50 characters';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  /// Indian mobile number validator (10 digits starting with 6, 7, 8, or 9)
  static String? validateIndianPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Mobile number is required';
    }
    final clean = value.trim().replaceAll(' ', '').replaceAll('-', '');
    final regex = RegExp(r'^[6-9]\d{9}$');
    if (!regex.hasMatch(clean)) {
      return 'Enter a valid 10-digit Indian mobile number (starts with 6-9)';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional in general contexts
    }
    final clean = value.trim().replaceAll(' ', '').replaceAll('-', '');
    final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
    if (!phoneRegex.hasMatch(clean)) {
      return 'Enter a valid phone number (e.g. +91 9876543210)';
    }
    return null;
  }
}
