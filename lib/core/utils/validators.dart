import '../constants/app_constants.dart';

class Validators {
  Validators._();

  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(AppConstants.phoneRegex).hasMatch(cleaned)) {
      return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (!RegExp(AppConstants.emailRegex).hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? amount(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Amount'} is required';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed < 0) {
      return 'Enter a valid amount';
    }
    return null;
  }

  static String? positiveAmount(String? value, [String? fieldName]) {
    final error = Validators.amount(value, fieldName);
    if (error != null) return error;
    final parsed = double.tryParse(value!.trim());
    if (parsed != null && parsed <= 0) {
      return 'Amount must be greater than zero';
    }
    return null;
  }

  static String? gstNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    if (!RegExp(AppConstants.gstRegex).hasMatch(value.trim().toUpperCase())) {
      return 'Enter a valid GST number';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? confirmPassword(String? value, String pwd) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != pwd) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? number(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Number'} is required';
    }
    if (double.tryParse(value.trim()) == null) {
      return 'Enter a valid number';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String? fieldName]) {
    final error = number(value, fieldName);
    if (error != null) return error;
    final numVal = double.tryParse(value!.trim());
    if (numVal != null && numVal <= 0) {
      return 'Number must be greater than zero';
    }
    return null;
  }
}
