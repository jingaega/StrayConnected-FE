  import 'package:flutter/material.dart';
  import 'package:strayconnected/data/auth_repository.dart';

  class LoginPage extends StatefulWidget {
    const LoginPage({super.key});

    @override
    State<LoginPage> createState() => _LoginPageState();
  }

  class _LoginPageState extends State<LoginPage> {
    final _formKey = GlobalKey<FormState>();
    final _auth = AuthRepository();

    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    bool _obscurePassword = true;
    String? _errorMessage; // null initially -> show slogan

    @override
    void dispose() {
      _emailController.dispose();
      _passwordController.dispose();
      super.dispose();
    }

    Future<void> _submit() async {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        setState(() => _errorMessage = 'Please fill in all fields');
        return;
      }

      try {
        await _auth.signIn(email: email, password: password);

        if (mounted) {
          setState(() => _errorMessage = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
            ),
          );

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/home');
        }
      } catch (e) {
        setState(() => _errorMessage = 'Incorrect Password/Username');
      }
    }

    @override
    Widget build(BuildContext context) {
      return Column(
        children: [
          const SizedBox(height: 20),
          // Logo
        Container(
          width: 350,
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(200),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(0, 0, 0, 0.15),
                blurRadius: 4,
                spreadRadius: -105,
                offset: const Offset(-1, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(150),
            child: Image.asset('assets/Images/LOGO.png', fit: BoxFit.contain),
          ),
        ),
          const SizedBox(height: 0),

          // Main form container
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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
                      const Text(
                        'StrayConnected',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D0C57),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Email
                                    const Text(
                                      'Email',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF9586A8),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInput(
                                      controller: _emailController,
                                      hint: 'Enter your email',
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 20),

                                    // Password
                                    const Text(
                                      'Password',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF9586A8),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildInput(
                                      controller: _passwordController,
                                      hint: 'Enter your password',
                                      obscureText: _obscurePassword,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          color: const Color(0xFF9586A8),
                                        ),
                                        onPressed: () => setState(
                                          () =>
                                              _obscurePassword = !_obscurePassword,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // Status line: slogan or error
                                    Center(
                                      child: Text(
                                        _errorMessage ??
                                            'Bridging Hearts, Finding Homes.',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: _errorMessage == null
                                              ? const Color(0xFF9586A8)
                                              : Colors.red,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Login button
                                    SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _submit,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0BCE83),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          'LOGIN',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        GestureDetector(
                                          onTap:
                                              () => Navigator.pushReplacementNamed(
                                                context,
                                                '/register',
                                              ),
                                          child: const Text(
                                            'REGISTER',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF9586A8),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        GestureDetector(
                                          onTap: () {
                                            // TODO: implement forgot password
                                          },
                                          child: const Text(
                                            'FORGOT PASSWORD?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF9586A8),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ===== Helper text input =====
    Widget _buildInput({
      required TextEditingController controller,
      required String hint,
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
          onChanged: (_) {
            if (_errorMessage != null) setState(() => _errorMessage = null);
          },
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: InputBorder.none,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 16, color: Color(0xFFB7AFC3)),
            suffixIcon: suffixIcon,
          ),
          style: const TextStyle(fontSize: 16, color: Color(0xFF2D0C57)),
        ),
      );
    }
  }
