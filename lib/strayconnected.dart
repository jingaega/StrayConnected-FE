import 'package:flutter/material.dart';
import 'package:strayconnected/screens/login_page.dart';
import 'package:strayconnected/screens/register_role_page.dart';
import 'package:strayconnected/screens/register_page.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/screens/create_animal_page.dart';
import 'package:strayconnected/screens/chat_list_page.dart';
import 'package:strayconnected/screens/chat_thread_page.dart';
import 'package:strayconnected/models/chat_preview_item.dart';
import 'package:strayconnected/screens/manage_shelter_page.dart';
import 'package:strayconnected/screens/shelter_profile_page.dart';
import 'package:strayconnected/screens/shelter_profile_edit_page.dart';
import 'package:strayconnected/screens/profile_page.dart';
import 'package:strayconnected/screens/meeting_requests_page.dart';
import 'package:strayconnected/screens/my_animals_page.dart';
import 'package:strayconnected/screens/location_page.dart';
import 'package:strayconnected/screens/admin_page.dart';

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
        '/register': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          String? presetRole;
          bool lockRole = false;
          if (args is Map<String, dynamic>) {
            presetRole = args['presetRole'] as String?;
            lockRole = args['lockRole'] == true;
          }
          return BackgroundWrapper(
            child: RegisterPage(
              presetRole: presetRole,
              lockRole: lockRole,
            ),
          );
        },
        '/registerRole':
            (_) => const BackgroundWrapper(child: RegisterRolePage()),
        '/home': (_) => const PlainWrapper(child: UserHomePage()),
        '/createAnimal': (_) => const PlainWrapper(child: CreateAnimalPage()),
        '/chats': (_) => const PlainWrapper(child: ChatListPage()),
        '/profile': (_) => const ProfileWrapper(child: ProfilePage()),
        '/meetings': (_) => const PlainWrapper(child: MeetingRequestsPage()),
        '/myAnimals': (_) => const PlainWrapper(child: MyAnimalsPage()),
        '/location': (_) => const PlainWrapper(child: LocationPage()),
        '/chatThread': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final item =
              args is ChatPreviewItem
                  ? args
                  : ChatPreviewItem(
                    userId: 'unknown',
                    name: '',
                    lastMessage: '',
                    lastAt: DateTime.now(),
                    unreadCount: 0,
                    avatarUrl: 'https://placehold.co/42x42',
                  );
          return PlainWrapper(child: ChatThreadPage(item: item));
        },
        '/manageShelter': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return PlainWrapper(
            child: ManageShelterPage(
              pendingRegistration:
                  args is Map<String, dynamic> ? args : null,
            ),
          );
        },
        '/shelterProfile':
            (_) => const PlainWrapper(child: ShelterProfilePage()),
        '/shelterProfileEdit':
            (_) => const PlainWrapper(child: ShelterProfileEditPage()),
        '/admin': (_) => const PlainWrapper(child: AdminPage()),
      },
      onUnknownRoute:
          (settings) => MaterialPageRoute(
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

class PlainWrapper extends StatelessWidget {
  final Widget child;
  const PlainWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const bg = Color.fromARGB(255, 246, 245, 245);
    return ColoredBox(
      color: bg,
      child: Material(
        color: bg,
        child: SafeArea(child: child),
      ),
    );
  }
}

class ProfileWrapper extends StatelessWidget {
  final Widget child;
  const ProfileWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    const bg = Color.fromARGB(255, 246, 245, 245);
    return ColoredBox(
      color: bg,
      child: Material(
        color: bg,
        child: SafeArea(child: child),
      ),
    );
  }
}
