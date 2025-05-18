import 'package:flutter/material.dart';

class CustomScarffold extends StatelessWidget {
  const CustomScarffold({super.key,this.child,this.floatingActionButton});
  final Widget? child;
  final Widget? floatingActionButton;
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white, // Change the color of the back button
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
            height: double.infinity,
            width: double.infinity,
          ),
         SafeArea(
          child: child!,
          ),
        ],
      ),floatingActionButton: floatingActionButton,
    );
  }
}