import 'package:flutter/material.dart';

class MeetingConfirmationPage extends StatelessWidget {
  const MeetingConfirmationPage({
    super.key,
    required this.onEdit,
    required this.onConfirm,
  });

  final VoidCallback onEdit;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 56),
        Image.asset(
          'assets/Images/LOGO.png',
          width: 500,
          height: 250,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 16),
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
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Column(
              children: [
                const Text(
                  'Meeting Request Sent',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF2D0C57),
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 2.5,
                    letterSpacing: 0.41,
                  ),
                ),
                const SizedBox(height: 30),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 239,
                      height: 239,
                      decoration: const ShapeDecoration(
                        color: Color(0xFF0ACF83),
                        shape: OvalBorder(),
                      ),
                    ),
                    Image.asset(
                      'assets/Images/check.png',
                      width: 117,
                      height: 117,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0ACF83),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: onEdit,
                          child: const Text(
                            'EDIT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                              letterSpacing: -0.01,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0ACF83),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: onConfirm,
                          child: const Text(
                            'CONFIRM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                              letterSpacing: -0.01,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
