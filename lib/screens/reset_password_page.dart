import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePassword() async {
    if (_saving) return;
    final password = _passwordCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (password.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      if (_supabase.auth.currentSession == null) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      await _supabase.auth.updateUser(UserAttributes(password: password));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated.'),
          backgroundColor: Color(0xFF0BCE83),
        ),
      );
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update password: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          Container(color: const Color.fromRGBO(0, 0, 0, 0.15)),
          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: 12,
                  top: 6,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 60,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCCFFB5),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33270058),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 7,
                  top: 51,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: Image.asset(
                      'assets/images/catlogo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.lock_outline,
                          size: 38,
                          color: Color(0xFF2D0C57),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          'Create new password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF2D0C57),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Reset your password, create a new one different from the previous one',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFADA2BB),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 38),
                        const Text(
                          'Insert new password',
                          style: TextStyle(
                            color: Color(0xFF9586A8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(controller: _passwordCtrl),
                        const SizedBox(height: 34),
                        const Text(
                          'Re-enter password',
                          style: TextStyle(
                            color: Color(0xFF9586A8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _PasswordField(controller: _confirmCtrl),
                        const SizedBox(height: 34),
                        const Text(
                          'Bridging Hearts, Finding Homes.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF9586A8),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _savePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0BCE83),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'VERIFY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.01,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'CANCEL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF9586A8),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8D0E3)),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        obscureText: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: 'Insert new password',
          hintStyle: TextStyle(
            color: Color.fromARGB(255, 141, 141, 141),
            fontSize: 16,
          ),
        ),
        style: const TextStyle(
          color: Color(0xFF2D0C57),
          fontSize: 16,
        ),
      ),
    );
  }
}
