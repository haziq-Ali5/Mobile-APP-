import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:project/services/database_helper.dart';
import 'package:project/providers/job_provider.dart';


class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final JobProvider? _jobProvider;
  
  bool _isOnline = true;
  bool _isCheckingConnectivity = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool get isOnline => _isOnline;
  bool get isCheckingConnectivity => _isCheckingConnectivity;
  
  ConnectivityService([this._jobProvider]) {
    _initConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  // Initialize connectivity state
  Future<void> _initConnectivity() async {
    try {
      _isCheckingConnectivity = true;
      notifyListeners();
      
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
    } catch (e) {
      debugPrint('Connectivity initialization error: $e');
      _isOnline = false; // Assume offline if we can't check
    } finally {
      _isCheckingConnectivity = false;
      notifyListeners();
    }
  }
  
  // Handle connectivity changes
  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    final wasOnline = _isOnline;
    
    // Update connectivity status
    _isOnline = (result == ConnectivityResult.mobile || 
                result == ConnectivityResult.wifi ||
                result == ConnectivityResult.ethernet);
    
    // If coming back online, retry pending jobs
    if (!wasOnline && _isOnline) {
      _retryPendingJobs();
    }
    
    notifyListeners();
  }
  
  // Retry pending jobs when coming back online
  Future<void> _retryPendingJobs() async {
    if (_jobProvider == null) return;
    
    try {
      final pendingJobs = await _databaseHelper.getPendingJobs();
      
      for (final job in pendingJobs) {
       if (job != null) {
        await _jobProvider.retryJob(job);
      }
      }
    } catch (e) {
      debugPrint('Error retrying pending jobs: $e');
    }
  }
  
  // Manual check for connectivity
  Future<bool> checkConnectivity() async {
    try {
      _isCheckingConnectivity = true;
      notifyListeners();
      
      final connectivityResult = await _connectivity.checkConnectivity();
      _updateConnectionStatus(connectivityResult);
      return _isOnline;
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      return false;
    } finally {
      _isCheckingConnectivity = false;
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}