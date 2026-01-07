import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _emailCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (_sending) return;
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid email.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      if (!mounted) return;
      Navigator.pushNamed(context, '/resetPassword');
    } finally {
      if (mounted) setState(() => _sending = false);
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
                      color: Color.fromARGB(255, 57, 31, 63),
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
                    padding: const EdgeInsets.fromLTRB(24, 50, 24, 32),
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
                          'Forgot password?',
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
                          "No worries, we'll send you reset instructions",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFADA2BB),
                            fontSize: 12,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 38),
                        const Text(
                          'Insert Registered Email',
                          style: TextStyle(
                            color: Color(0xFF9586A8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD8D0E3)),
                          ),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Insert Registered Email',
                              hintStyle: TextStyle(
                                color: Color.fromARGB(255, 167, 167, 167),
                                fontSize: 16,
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF2D0C57),
                              fontSize: 16,
                            ),
                          ),
                        ),
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
                            onPressed: _sending ? null : _sendReset,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0BCE83),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _sending
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
                                    'SEND VERIFICATION',
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
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
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
