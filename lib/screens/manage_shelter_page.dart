import 'package:flutter/material.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

class ManageShelterPage extends StatefulWidget {
  const ManageShelterPage({super.key});

  @override
  State<ManageShelterPage> createState() => _ManageShelterPageState();
}

class _ManageShelterPageState extends State<ManageShelterPage> {
  final _nameController = TextEditingController();
  final _openController = TextEditingController();
  final _statusController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _openController.dispose();
    _statusController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showPlaceholder(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label tapped (placeholder)')));
  }

  void _handleConfirm() {
    _showPlaceholder('Save shelter info');
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F5F5);
    const border = Color(0xFFD8D0E3);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              child: Container(
                height: 96,
                decoration: const BoxDecoration(
                  color: bg,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x02000000),
                      blurRadius: 18,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Manage Shelter',
                    style: const TextStyle(
                      color: Color(0xFF2D0C57),
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.41,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Upload photos box
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 344,
                          height: 228,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF9B9B9B)),
                          ),
                        ),
                        Positioned(
                          left: (344 - 133) / 2,
                          top: (228 - 38) / 2,
                          child: SizedBox(
                            width: 133,
                            height: 38,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: Color(0xFF8A8A8A),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed:
                                  () => _showPlaceholder('Upload photos'),
                              child: const Text(
                                'upload photos',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Row(
                    children: [
                      Expanded(
                        child: _LabeledBox(
                          label: 'Shelter Name',
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Shelter Name',
                              hintStyle: TextStyle(
                                color: Color(0xFF9586A8),
                                fontSize: 16,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledBox(
                          label: 'Time Opened',
                          child: TextField(
                            controller: _openController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Time Opened',
                              hintStyle: TextStyle(
                                color: Color(0xFF9586A8),
                                fontSize: 16,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledBox(
                          label: 'Status',
                          child: TextField(
                            controller: _statusController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Status',
                              hintStyle: TextStyle(
                                color: Color(0xFF9586A8),
                                fontSize: 16,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledBox(
                          label: 'Upload Credentials',
                          child: InkWell(
                            onTap: () => _showPlaceholder('Upload credentials'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              child: Text(
                                'Upload Credentials',
                                style: TextStyle(
                                  color: Color(0xFF9586A8),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _LabeledBox(
                    label: 'Insert Description',
                    height: 120,
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Insert Description',
                        hintStyle: TextStyle(
                          color: Color(0xFF9586A8),
                          fontSize: 16,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0ACF83),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _handleConfirm,
                      child: const Text(
                        'CONFIRM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          letterSpacing: -0.01,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RoleAwareBottomNav(
        onCreateAllowed: () => Navigator.pushNamed(context, '/createAnimal'),
        onHome: () => Navigator.pushReplacementNamed(context, '/home'),
        onMessages: () =>
            Navigator.pushReplacementNamed(context, '/chats'),
        onMeetings: () =>
            Navigator.pushReplacementNamed(context, '/meetings'),
        onProfile: () =>
            Navigator.pushReplacementNamed(context, '/profile'),
        activeTab: BottomNavTab.profile,
      ),
    );
  }
}

class _LabeledBox extends StatelessWidget {
  const _LabeledBox({
    required this.label,
    required this.child,
    this.height = 69,
  });

  final String label;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFD8D0E3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9586A8),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ],
    );
  }
}
