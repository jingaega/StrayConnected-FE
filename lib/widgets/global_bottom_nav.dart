import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum BottomNavTab { home, chat, profile }

/// Reusable bottom navigation bar for the app.
class GlobalBottomNav extends StatelessWidget {
  const GlobalBottomNav({
    super.key,
    required this.canCreate,
    required this.onCreate,
    required this.onHome,
    required this.onChat,
    required this.onProfile,
    this.activeTab = BottomNavTab.home,
  });

  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onHome;
  final VoidCallback onChat;
  final VoidCallback onProfile;
  final BottomNavTab activeTab;

  @override
  Widget build(BuildContext context) {
    const Color barBg = Colors.white;
    const Color iconColor = Color(0xFF9586A8);
    const Color activeColor = Color(0xFF2D0C57);
    const Color accent = Color(0xFF0ACF83);

    Color colorFor(BottomNavTab tab) =>
        tab == activeTab ? activeColor : iconColor;

    return Container(
      height: 86,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: barBg,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
            icon: Icons.home_filled,
            label: 'Home',
            color: colorFor(BottomNavTab.home),
            onTap: onHome,
          ),
          _NavItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            color: colorFor(BottomNavTab.chat),
            onTap: onChat,
          ),
          GestureDetector(
            onTap: canCreate ? onCreate : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: canCreate ? accent : const Color(0xFFE0E0E0),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(0, 0, 0, 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            color: colorFor(BottomNavTab.profile),
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

/// Role-aware wrapper that auto-checks if the user is a rescuer/shelter to
/// enable the create (+) button.
class RoleAwareBottomNav extends StatefulWidget {
  const RoleAwareBottomNav({
    super.key,
    required this.activeTab,
    required this.onCreateAllowed,
    required this.onHome,
    required this.onChat,
    required this.onProfile,
  });

  final BottomNavTab activeTab;
  final VoidCallback onCreateAllowed;
  final VoidCallback onHome;
  final VoidCallback onChat;
  final VoidCallback onProfile;

  @override
  State<RoleAwareBottomNav> createState() => _RoleAwareBottomNavState();
}

class _RoleAwareBottomNavState extends State<RoleAwareBottomNav> {
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _canCreate = false);
      return;
    }
    try {
      final data =
          await client.from('user').select('role').eq('id', uid).maybeSingle();
      final role = data?['role'] as String?;
      setState(() {
        _canCreate = role == 'rescuer' || role == 'shelter';
      });
    } catch (_) {
      setState(() => _canCreate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlobalBottomNav(
      canCreate: _canCreate,
      onCreate: _canCreate ? widget.onCreateAllowed : () {},
      onHome: widget.onHome,
      onChat: widget.onChat,
      onProfile: widget.onProfile,
      activeTab: widget.activeTab,
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
