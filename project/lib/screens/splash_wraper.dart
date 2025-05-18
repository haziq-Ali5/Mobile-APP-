import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project/screens/welcome_screen.dart';
import 'package:project/screens/auth_wrapper.dart';

class SplashWrapper extends StatefulWidget {
  const SplashWrapper({super.key});

  @override
  State<SplashWrapper> createState() => _SplashWrapperState();
}

class _SplashWrapperState extends State<SplashWrapper> {
  bool? _seenWelcome;

  @override
  void initState() {
    super.initState();
    _checkWelcomeSeen();
  }

  Future<void> _checkWelcomeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_welcome') ?? false;

    if (!seen) {
      await prefs.setBool('seen_welcome', true);
    }

    setState(() {
      _seenWelcome = seen;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_seenWelcome == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _seenWelcome! ?  AuthWrapper() :  WelcomeScreen();
  }
}
