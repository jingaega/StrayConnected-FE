import 'package:flutter/material.dart';
import 'package:strayconnected/screens/login_page.dart';
import 'package:strayconnected/screens/register_page.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/screens/create_animal_page.dart';

class StrayConnectedApp extends StatelessWidget {
  const StrayConnectedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'StrayConnected',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const BackgroundWrapper(child: LoginPage()),
        '/register': (_) => const BackgroundWrapper(child: RegisterPage()),
        '/home': (_) => const BackgroundWrapper(child: UserHomePage()),
        '/createAnimal': (_) =>
            const BackgroundWrapper(child: CreateAnimalPage()),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => const BackgroundWrapper(child: LoginPage()),
      ),
    );
  }
}

class BackgroundWrapper extends StatelessWidget {
  final Widget child;
  const BackgroundWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          Container(color: const Color.fromRGBO(0, 0, 0, 0.15)),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
