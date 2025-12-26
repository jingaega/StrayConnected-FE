import 'package:flutter/material.dart';
import 'package:strayconnected/data/auth_repository.dart';
import 'package:strayconnected/services/push_notifications.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _bgColor = Colors.white;
  static const _subtitleColor = Color(0xFF9586A8);

  final AuthRepository _auth = AuthRepository();

  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadNotificationPref();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _auth.getMyProfile();
      setState(() {
        _profile = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleLogout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _loadNotificationPref() async {
    final enabled = await PushNotifications.isEnabled();
    if (!mounted) return;
    setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _toggleNotifications(bool value) async {
    final previous = _notificationsEnabled;
    setState(() => _notificationsEnabled = value);
    try {
      await PushNotifications.setEnabled(value);
      if (value) {
        await PushNotifications.startRealtimeListener();
      } else {
        await PushNotifications.stopRealtimeListener();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Notifications enabled' : 'Notifications disabled'),
          backgroundColor: value ? const Color(0xFF5B30B5) : Colors.grey.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _notificationsEnabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update notifications: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Feature coming soon: $label'),
        backgroundColor: const Color(0xFF5B30B5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double navHeight = 86;
    final name = (_profile?['name'] as String?)?.trim();
    final role = (_profile?['role'] as String?) ?? 'User';
    final email = (_profile?['email'] as String?) ?? '';
    final idText = (_profile?['id'] as String?) ?? 'Member ID unavailable';

    return Container(
      color: _bgColor,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadProfile,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, navHeight + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(
                    name: name ?? 'New User',
                    subtitle: email.isNotEmpty ? email : role,
                  memberId: idText,
                ),
                const SizedBox(height: 70),
                if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(
                          color: Color(0xFF5B30B5),
                        ),
                      ),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(height: 8),
                          const Text(
                            'Failed to load profile',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _error ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _subtitleColor),
                          ),
                          TextButton(
                            onPressed: _loadProfile,
                            child: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        _SettingsCard(
                          children: [
                        _SettingsTile(
                          icon: Icons.place_outlined,
                          iconColor: Colors.teal,
                          title: 'Location',
                          subtitle: 'View your map location',
                          onTap: () =>
                              Navigator.pushNamed(context, '/location'),
                        ),
                        const Divider(height: 1, color: Color(0xFFE4E2EE)),
                        _SettingsTile(
                          icon: Icons.badge_outlined,
                          iconColor: const Color(0xFF5B30B5),
                          title: 'Shelter Profile',
                          subtitle: 'View shelter info',
                          onTap: () =>
                              Navigator.pushNamed(context, '/shelterProfile'),
                        ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.lock_reset_rounded,
                              iconColor: const Color(0xFF5B30B5),
                              title: 'Change Password',
                              subtitle: 'Update your account access',
                              onTap: () => _showComingSoon('Change Password'),
                            ),
                            const Divider(height: 1, color: Color(0xFFE4E2EE)),
                            _SettingsTile(
                              icon: Icons.shield_outlined,
                              iconColor: const Color(0xFF0BCE83),
                              title: 'Security & Privacy',
                              subtitle: 'Control data and permissions',
                              onTap: () =>
                                  _showComingSoon('Security & Privacy'),
                            ),
                            const Divider(height: 1, color: Color(0xFFE4E2EE)),
                            _SettingsSwitchTile(
                              icon: Icons.notifications_none_rounded,
                              iconColor: const Color(0xFFFFB04C),
                              title: 'Notifications',
                              subtitle: 'Stay updated on rescues & adoptions',
                              value: _notificationsEnabled,
                              onChanged: _toggleNotifications,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _SettingsCard(
                          children: [
                            _SettingsTile(
                              icon: Icons.logout,
                              iconColor: Colors.redAccent,
                              title: 'Log Out',
                              subtitle: 'Sign out of this account',
                              showArrow: false,
                              onTap: _handleLogout,
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlobalBottomNav(
              canCreate: (_profile?['role'] == 'rescuer') ||
                  (_profile?['role'] == 'shelter'),
              onCreate: () => Navigator.pushNamed(context, '/createAnimal'),
              onHome: () => Navigator.pushReplacementNamed(context, '/home'),
              onMessages: () =>
                  Navigator.pushReplacementNamed(context, '/chats'),
              onMeetings: () =>
                  Navigator.pushReplacementNamed(context, '/meetings'),
              onProfile: () {},
              activeTab: BottomNavTab.profile,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.memberId,
  });

  final String name;
  final String subtitle;
  final String memberId;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5B30B5), Color(0xFF0BCE83)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.15),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.more_horiz, color: Colors.white),
              ],
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: -46,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 52, 18, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.08),
                    blurRadius: 16,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D0C57),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9586A8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    memberId,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB7AFC3),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.15),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFE5D4FF),
                  child: Icon(
                    Icons.person,
                    size: 42,
                    color: Color(0xFF5B30B5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showArrow = true,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconBadge(color: iconColor, icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D0C57),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9586A8),
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow)
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFB7AFC3),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _IconBadge(color: iconColor, icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D0C57),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9586A8),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => Colors.white,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFF5B30B5)
                  : const Color(0xFFE4E2EE),
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color),
    );
  }
}
