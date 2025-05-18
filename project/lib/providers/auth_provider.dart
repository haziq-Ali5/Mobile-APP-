import 'package:flutter/foundation.dart';
import 'package:project/models/user.dart';
import 'package:project/services/auth_service.dart';
import 'package:project/services/storage_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final StorageService _storageService;
  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;
  AppUser? _user;

  AuthProvider(this._authService, this._storageService) {
    // Listen for auth state changes (e.g., auto-login)
    _authService.authStateChanges.listen((user) {
      _isInitializing = false;
      _user = user != null ? AppUser.fromFirebase(user) : null;
      notifyListeners();
    });
  }

  AppUser? get user => _user;

  // Store JWT token
  Future<void> _saveJwtToken(String token) async {
    await _storageService.saveToken(token); // Save the token securely
  }

  // Retrieve JWT token
  Future<String?> getJwtToken() async {
    return await _storageService.getToken(); // Retrieve the token
  }

  // Sign up method (new user registration)
  Future<void> signUp(String email, String password) async {
    try {
      final firebaseUser = await _authService.signUp(email, password);
      _user = AppUser.fromFirebase(firebaseUser!);
      final token = await firebaseUser.getIdToken();
      await _saveJwtToken(token!);  // Save token after successful sign up
      notifyListeners();
    } catch (e) {
      rethrow; // Propagate error to UI for handling
    }
  }

  // Login method (for existing users)
  Future<void> login(String email, String password) async {
    try {
      final firebaseUser = await _authService.signIn(email, password);
      _user = AppUser.fromFirebase(firebaseUser!);
      final token = await firebaseUser.getIdToken();
      await _saveJwtToken(token!);  // Save token after successful login
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Sign out method (clear user and token)
  Future<void> signOut() async {
    await _authService.signOut();
    await _storageService.deleteToken();  // Delete token when signing out
    _user = null;
    notifyListeners();
  }
}
