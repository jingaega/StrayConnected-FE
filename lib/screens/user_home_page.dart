// lib/screens/user_home_page.dart
import 'package:flutter/material.dart';

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Welcome, User!',
        style: TextStyle(fontSize: 22, color: Colors.white),
      ),
    );
  }
}
