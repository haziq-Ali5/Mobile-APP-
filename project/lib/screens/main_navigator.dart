// lib/screens/main_navigator.dart
import 'package:flutter/material.dart';
import 'package:project/screens/home_screen.dart';
import 'package:project/screens/job_history_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({Key? key}) : super(key: key);

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    JobHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.lightBlue,
        currentIndex: _selectedIndex,
         selectedItemColor: Colors.black, // Active color
        unselectedItemColor: Colors.white,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
