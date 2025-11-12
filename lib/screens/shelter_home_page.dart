// lib/screens/shelter_home_page.dart
import 'package:flutter/material.dart';

class ShelterHomePage extends StatelessWidget {
  const ShelterHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Welcome, Shelter!',
        style: TextStyle(fontSize: 22, color: Colors.white),
      ),
    );
  }
}
