import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/models.dart';

class AuthState with ChangeNotifier {
  String? _token;
  User? _user;
  bool _isLoading = false;
  String? _error;

  String? get token => _token;
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _user != null;

  static const String _tokenKey = 'token';
  static const String _baseUrl =
      'https://backend-for-app-main-hsw776.laravel.cloud/api';

  /// Initialize authentication state by restoring token from storage
  Future<void> initAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);

      if (_token != null) {
        // Verify token is still valid and fetch user data
        await _fetchCurrentUser();
      }
    } catch (e) {
      _clearAuth();
    }
  }

  /// Register new user
  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String studentId,
  }) async {
    _setLoading(true);
    _error = null;

    final requestBody = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      if (studentId.isNotEmpty) 'student_id': studentId,
    };

    print('🔵 [REGISTER] Starting registration...');
    print('🔵 [REGISTER] URL: $_baseUrl/auth/register');
    print('🔵 [REGISTER] Request Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('🔵 [REGISTER] Status Code: ${response.statusCode}');
      print('🔵 [REGISTER] Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ [REGISTER] Registration successful!');
        _setLoading(false);
        return true;
      } else {
        _error = data['message'] ?? 'Registration failed';
        print('❌ [REGISTER] Registration failed: $_error');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Network error: ${e.toString()}';
      print('❌ [REGISTER] Exception: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Verify email with 6-digit code
  Future<bool> verifyEmail({
    required String email,
    required String verificationCode,
  }) async {
    _setLoading(true);
    _error = null;

    final requestBody = {
      'email': email,
      'verification_code': verificationCode,
    };

    print('🟢 [VERIFY EMAIL] Starting verification...');
    print('🟢 [VERIFY EMAIL] URL: $_baseUrl/auth/verify-email');
    print('🟢 [VERIFY EMAIL] Request Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-email'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('🟢 [VERIFY EMAIL] Status Code: ${response.statusCode}');
      print('🟢 [VERIFY EMAIL] Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final success = data['success'] ?? false;
        if (success) {
          final user = data['data']?['user'];
          print('✅ [VERIFY EMAIL] Verification successful!');
          print('✅ [VERIFY EMAIL] User: ${user?['name']} (${user?['email']})');
          print('✅ [VERIFY EMAIL] Is Verified: ${user?['is_verified']}');
          _setLoading(false);
          return true;
        } else {
          _error = data['message'] ?? 'Verification failed';
          print('❌ [VERIFY EMAIL] Success flag is false: $_error');
          _setLoading(false);
          return false;
        }
      } else {
        _error = data['message'] ?? 'Verification failed';
        print('❌ [VERIFY EMAIL] HTTP Error ${response.statusCode}: $_error');
        if (data['errors'] != null) {
          print('❌ [VERIFY EMAIL] Validation errors: ${data['errors']}');
        }
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Network error: ${e.toString()}';
      print('❌ [VERIFY EMAIL] Exception: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Login user
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _error = null;

    final requestBody = {
      'email': email,
      'password': password,
    };

    print('🟡 [LOGIN] Starting login...');
    print('🟡 [LOGIN] URL: $_baseUrl/auth/login');
    print('🟡 [LOGIN] Request Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      print('🟡 [LOGIN] Status Code: ${response.statusCode}');
      print('🟡 [LOGIN] Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final success = data['success'] ?? false;
        if (success) {
          final responseData = data['data'];
          _token = responseData['token'];
          _user = User.fromJson(responseData['user']);
          print(
              '✅ [LOGIN] Login successful! Token: ${_token?.substring(0, 20)}...');
          print('✅ [LOGIN] User: ${_user?.name} (${_user?.email})');

          // Save token to storage
          await _saveToken(_token!);

          _setLoading(false);
          notifyListeners();
          return true;
        } else {
          _error = data['message'] ?? 'Login failed';
          print('❌ [LOGIN] Success flag is false: $_error');
          _setLoading(false);
          return false;
        }
      } else {
        _error = data['message'] ?? 'Login failed';
        print('❌ [LOGIN] Login failed: $_error');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Network error: ${e.toString()}';
      print('❌ [LOGIN] Exception: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Fetch current authenticated user
  Future<void> _fetchCurrentUser() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _user = User.fromJson(data);
        notifyListeners();
      } else {
        // Token is invalid, clear auth
        await _clearAuth();
      }
    } catch (e) {
      await _clearAuth();
    }
  }

  /// Logout user
  Future<void> logout() async {
    _setLoading(true);

    try {
      if (_token != null) {
        // Call backend logout endpoint
        await http.post(
          Uri.parse('$_baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        );
      }
    } catch (e) {
      // Continue with logout even if API call fails
    }

    await _clearAuth();
    _setLoading(false);
  }

  /// Resend email verification code
  Future<bool> resendVerificationCode({required String email}) async {
    _error = null;

    final requestBody = {'email': email};

    print('🔄 [RESEND CODE] Starting resend...');
    print('🔄 [RESEND CODE] URL: $_baseUrl/auth/resend-code');
    print('🔄 [RESEND CODE] Request Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/resend-code'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('🔄 [RESEND CODE] Status Code: ${response.statusCode}');
      print('🔄 [RESEND CODE] Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final success = data['success'] ?? false;
        if (success) {
          print('✅ [RESEND CODE] Code resent successfully!');
          print('✅ [RESEND CODE] Email: ${data['data']?['email']}');
          print('✅ [RESEND CODE] Email Sent: ${data['data']?['email_sent']}');
          return true;
        } else {
          _error = data['message'] ?? 'Failed to resend code';
          print('❌ [RESEND CODE] Success flag is false: $_error');
          return false;
        }
      } else {
        _error = data['message'] ?? 'Failed to resend code';
        print('❌ [RESEND CODE] Failed: $_error');
        return false;
      }
    } catch (e) {
      _error = 'Network error: ${e.toString()}';
      print('❌ [RESEND CODE] Exception: $e');
      return false;
    }
  }

  /// Forgot password - send reset code to email
  Future<bool> forgotPassword({required String email}) async {
    _setLoading(true);
    _error = null;

    final requestBody = {'email': email};

    print('🔵 [FORGOT PASSWORD] Starting forgot password request...');
    print('🔵 [FORGOT PASSWORD] URL: $_baseUrl/auth/forgot-password');
    print('🔵 [FORGOT PASSWORD] Request Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/forgot-password'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('🔵 [FORGOT PASSWORD] Status Code: ${response.statusCode}');
      print('🔵 [FORGOT PASSWORD] Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final success = data['success'] ?? false;
        if (success) {
          print('✅ [FORGOT PASSWORD] Reset code sent successfully!');
          print('✅ [FORGOT PASSWORD] Email: ${data['data']?['email']}');
          print(
              '✅ [FORGOT PASSWORD] Email Sent: ${data['data']?['email_sent']}');
          _setLoading(false);
          return true;
        } else {
          _error = data['message'] ?? 'Failed to send reset code';
          print('❌ [FORGOT PASSWORD] Success flag is false: $_error');
          _setLoading(false);
          return false;
        }
      } else {
        _error = data['message'] ?? 'Failed to send reset code';
        print('❌ [FORGOT PASSWORD] HTTP Error ${response.statusCode}: $_error');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Network error: ${e.toString()}';
      print('❌ [FORGOT PASSWORD] Exception: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Reset password with reset code
  Future<bool> resetPassword({
    required String email,
    required String resetCode,
    required String password,
    required String passwordConfirmation,
  }) async {
    _setLoading(true);
    _error = null;

    final requestBody = {
      'email': email,
      'reset_code': resetCode,
      'password': password,
      'password_confirmation': passwordConfirmation,
    };

    print('🟣 [RESET PASSWORD] Starting password reset...');
    print('🟣 [RESET PASSWORD] URL: $_baseUrl/auth/reset-password');
    print('🟣 [RESET PASSWORD] Request Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('🟣 [RESET PASSWORD] Status Code: ${response.statusCode}');
      print('🟣 [RESET PASSWORD] Response Body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final success = data['success'] ?? false;
        if (success) {
          final user = data['data']?['user'];
          print('✅ [RESET PASSWORD] Password reset successfully!');
          print(
              '✅ [RESET PASSWORD] User: ${user?['name']} (${user?['email']})');
          _setLoading(false);
          return true;
        } else {
          _error = data['message'] ?? 'Password reset failed';
          print('❌ [RESET PASSWORD] Success flag is false: $_error');
          _setLoading(false);
          return false;
        }
      } else {
        _error = data['message'] ?? 'Password reset failed';
        print('❌ [RESET PASSWORD] HTTP Error ${response.statusCode}: $_error');
        if (data['errors'] != null) {
          print('❌ [RESET PASSWORD] Validation errors: ${data['errors']}');
        }
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _error = 'Network error: ${e.toString()}';
      print('❌ [RESET PASSWORD] Exception: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Save token to SharedPreferences
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Clear authentication data
  Future<void> _clearAuth() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

/// User model for authentication
class User {
  final int id;
  final String name;
  final String email;
  final String? studentId;
  final String? phone;
  final String? emailVerifiedAt;
  final String? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.studentId,
    this.phone,
    this.emailVerifiedAt,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      studentId: json['student_id'],
      phone: json['phone'],
      emailVerifiedAt: json['email_verified_at'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'student_id': studentId,
      'phone': phone,
      'email_verified_at': emailVerifiedAt,
      'created_at': createdAt,
    };
  }
}
