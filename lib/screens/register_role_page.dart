import 'package:flutter/material.dart';

class RegisterRolePage extends StatelessWidget {
  const RegisterRolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              ),
              const Spacer(),
              const Text(
                'Register',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 40),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(26),
                topRight: Radius.circular(26),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Register',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D0C57),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Are you an organization or an individual?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9586A8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _RoleCard(
                    title: 'Organization',
                    subtitle: 'Shelters or animal rescue groups',
                    icon: Icons.home_work_outlined,
                    accent: Color(0xFF5B30B5),
                    onTap: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/register',
                        arguments: const {
                          'presetRole': 'shelter',
                          'lockRole': true,
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _RoleCard(
                    title: 'Individual',
                    subtitle: 'Adopters or rescuers',
                    icon: Icons.person_outline,
                    accent: Color(0xFF0BCE83),
                    onTap: () {
                      Navigator.pushReplacementNamed(
                        context,
                        '/register',
                        arguments: const {
                          'presetRole': 'adopter',
                          'lockRole': false,
                        },
                      );
                    },
                  ),
                  const Spacer(),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(
                          color: Color(0xFF5B30B5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E3F1)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: accent, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D0C57),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9586A8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_right, color: accent),
            ),
          ],
        ),
      ),
    );
  }
}
