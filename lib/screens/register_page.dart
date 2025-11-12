import 'package:flutter/material.dart';
import 'package:strayconnected/data/auth_repository.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ===== Form + Controllers =====
  String cleanEmail(String input) {
  return input
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '')                  // remove whitespace
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), ''); // remove zero-width chars/BOM
}
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthRepository();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agree = false;
  String _selectedRole = 'user'; // user or shelter

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ===== Validation =====
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter your email';
    final emailReg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailReg.hasMatch(v.trim())) return 'Please enter a valid email';
    return null;
  }

  // ===== Submit =====
  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Privacy Policy'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await _auth.signUp(
        email: cleanEmail(_emailController.text), // <- use cleaned email
        password: _passwordController.text.trim(),
        name: _usernameController.text.trim(),
        role: _selectedRole,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height - media.padding.top;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Column(
          children: [
            const SizedBox(height: 28),
            // Logo
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(55),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(55),
                child: Image.asset(
                  'assets/images/catlogo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Create your account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 22),

            // Form container
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      const Text(
                        'Join StrayConnected',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2D0C57),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Username
                      const Text('Username',
                          style:
                              TextStyle(fontSize: 16, color: Color(0xFF9586A8))),
                      const SizedBox(height: 8),
                      _buildInput(
                        controller: _usernameController,
                        hint: 'Choose a username',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Please enter a username';
                          }
                          if (v.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Email
                      const Text('Email',
                          style:
                              TextStyle(fontSize: 16, color: Color(0xFF9586A8))),
                      const SizedBox(height: 8),
                      _buildInput(
                        controller: _emailController,
                        hint: 'you@example.com',
                        validator: _validateEmail,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 18),

                      // Password
                      const Text('Password',
                          style:
                              TextStyle(fontSize: 16, color: Color(0xFF9586A8))),
                      const SizedBox(height: 8),
                      _buildInput(
                        controller: _passwordController,
                        hint: 'Create a password',
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF9586A8),
                          ),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Confirm Password
                      const Text('Confirm password',
                          style:
                              TextStyle(fontSize: 16, color: Color(0xFF9586A8))),
                      const SizedBox(height: 8),
                      _buildInput(
                        controller: _confirmController,
                        hint: 'Re-enter your password',
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF9586A8),
                          ),
                          onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      // Role dropdown
                      const Text('Account Type',
                          style:
                              TextStyle(fontSize: 16, color: Color(0xFF9586A8))),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedRole,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFD9D0E3)),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'user', child: Text('User')),
                          DropdownMenuItem(
                              value: 'shelter', child: Text('Shelter')),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedRole = val ?? 'user');
                        },
                      ),

                      const SizedBox(height: 16),

                      // Terms
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agree,
                            activeColor: const Color(0xFF0BCE83),
                            onChanged: (v) =>
                                setState(() => _agree = v ?? false),
                          ),
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'I agree to the Terms of Service and Privacy Policy.',
                                style: TextStyle(
                                    fontSize: 14, color: Color(0xFF6E6E6E)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Register button
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0BCE83),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Already have an account?
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF9586A8)),
                          ),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushReplacementNamed(context, '/login'),
                            child: const Text(
                              'LOGIN',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF2D0C57),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ===== Helper widget for text fields =====
  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    FormFieldValidator<String>? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9D0E3), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 16, color: Color(0xFFB7AFC3)),
          suffixIcon: suffixIcon,
        ),
        style: const TextStyle(fontSize: 16, color: Color(0xFF2D0C57)),
        validator: validator,
      ),
    );
  }
}
