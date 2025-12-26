import 'package:flutter/material.dart';
import 'package:strayconnected/data/auth_repository.dart';

const Color _muted = Color(0xFF9586A8);

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.presetRole, this.lockRole = false});

  final String? presetRole;
  final bool lockRole;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Set<String> _allowedRoles = {'adopter', 'rescuer', 'shelter'};
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
  String _selectedRole = 'adopter'; // adopter, rescuer, shelter

  @override
  void initState() {
    super.initState();
    final preset = widget.presetRole?.trim().toLowerCase();
    if (preset != null && _allowedRoles.contains(preset)) {
      _selectedRole = preset;
    }
  }

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
      if (_selectedRole == 'shelter') {
        Navigator.pushReplacementNamed(
          context,
          '/manageShelter',
          arguments: {
            'email': cleanEmail(_emailController.text),
            'password': _passwordController.text.trim(),
          },
        );
        return;
      }

      await _auth.signUp(
        email: cleanEmail(_emailController.text), // <- use cleaned email
        password: _passwordController.text.trim(),
        name: _usernameController.text.trim(),
        role: _allowedRoles.contains(_selectedRole)
            ? _selectedRole
            : 'adopter',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        if (_selectedRole == 'shelter') {
          Navigator.pushReplacementNamed(context, '/manageShelter');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      if (!mounted) return;
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
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    '/registerRole',
                  ),
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            // Logo
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  const BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.15),
                    blurRadius: 4,
                    spreadRadius: -76,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.asset(
                  'assets/images/LOGO.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.lockRole
                  ? 'Create shelter account'
                  : 'Create your account',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
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

                      if (!widget.lockRole) ...[
                        const Text('Username',
                            style: TextStyle(
                                fontSize: 16, color: Color(0xFF9586A8))),
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
                      ],

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

                      // Account type
                      const Text('Account Type',
                          style:
                              TextStyle(fontSize: 16, color: Color(0xFF9586A8))),
                      const SizedBox(height: 8),
                      if (widget.lockRole)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD9D0E3)),
                          ),
                          child: const Text(
                            'Shelter (organization)',
                            style: TextStyle(
                              color: Color(0xFF2D0C57),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
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
                                value: 'adopter', child: Text('Adopter')),
                            DropdownMenuItem(
                                value: 'rescuer',
                                child: Text('Rescuer (can post animals)')),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedRole = val ?? 'adopter');
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
                          child: Text(
                            widget.lockRole
                                ? 'CREATE & SETUP SHELTER'
                                : 'CREATE ACCOUNT',
                            style: const TextStyle(
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
