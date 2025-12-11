import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF3F0C7A);
const Color _accent = Color(0xFF0BCE83);
const Color _label = Color(0xFF7C7693);
const Color _stroke = Color(0xFFD8D0E3);

class CreateAnimalPage extends StatefulWidget {
  const CreateAnimalPage({super.key});

  @override
  State<CreateAnimalPage> createState() => _CreateAnimalPageState();
}

class _CreateAnimalPageState extends State<CreateAnimalPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _healthCtrl = TextEditingController(text: 'Vaccinated and Healthy');
  final _descriptionCtrl = TextEditingController();

  final List<String> _speciesOptions = const ['Cat', 'Dog', 'Other'];
  final List<String> _breedOptions = const [
    'Calico',
    'Mixed',
    'Husky',
    'Unknown',
  ];
  final List<int> _ageOptions = List<int>.generate(
    20,
    (i) => i + 1,
  ); // 1..20 months

  String _selectedSpecies = 'Cat';
  String _selectedBreed = 'Calico';
  int _selectedAge = 3;
  String? _role; // adopter | rescuer | shelter

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _healthCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_role != 'rescuer' && _role != 'shelter') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only rescuers or shelters can add animals.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Match exactly with public.animal schema
      await _supabase.from('animal').insert({
        'name': _nameCtrl.text.trim(),
        'age': _selectedAge,
        'breed': _selectedBreed,
        'species': _selectedSpecies,
        'description': _descriptionCtrl.text.trim(),
        'health_status': _healthCtrl.text.trim(),
        'link_picture': '', // can be updated later with real image URL
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Listing created!'),
          backgroundColor: _accent,
        ),
      );
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save listing: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  Future<void> _loadRole() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _role = 'adopter');
      return;
    }
    try {
      final data =
          await _supabase
              .from('user')
              .select('role')
              .eq('id', uid)
              .maybeSingle();
      setState(() {
        _role = data?['role'] as String? ?? 'adopter';
      });
    } catch (_) {
      setState(() => _role = 'adopter');
    }
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const double navHeight = 86;

    return Container(
      color: _bg,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              navHeight + 140 + paddingBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _TopBar(),
                const SizedBox(height: 4),
                const Text(
                  'Post Your Animal',
                  style: TextStyle(
                    color: _primary,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.37,
                    letterSpacing: 0.41,
                  ),
                ),
                const SizedBox(height: 20),
                const _PhotoCard(),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _TwoUpRow(
                        left: _Field(
                          label: 'Insert Name',
                          hint: 'Wahyu',
                          controller: _nameCtrl,
                          validator: _required,
                        ),
                        right: _DropdownField<String>(
                          label: 'Breed',
                          value: _selectedBreed,
                          options: _breedOptions,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedBreed = v);
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _TwoUpRow(
                        left: _DropdownField<int>(
                          label: 'Insert Age (months)',
                          value: _selectedAge,
                          options: _ageOptions,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedAge = v);
                          },
                        ),
                        right: _DropdownField<String>(
                          label: 'Species',
                          value: _selectedSpecies,
                          options: _speciesOptions,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedSpecies = v);
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Field(
                        label: 'Insert Description',
                        hint:
                            'Share their story, temperament, and what they need in a home.',
                        controller: _descriptionCtrl,
                        maxLines: 4,
                        validator: _required,
                      ),
                      const SizedBox(height: 10),
                      const Align(
                        alignment: Alignment.center,
                        child: Text(
                          'Health certificate can be updated later',
                          style: TextStyle(
                            color: _label,
                            fontSize: 9,
                            fontWeight: FontWeight.w400,
                            height: 2.2,
                            letterSpacing: -0.41,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: navHeight + 20 + paddingBottom,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child:
                    _isSubmitting
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                        : const Text(
                          'CONFIRM',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.01,
                          ),
                        ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RoleAwareBottomNav(
              onCreateAllowed: _submit,
              onHome: () => Navigator.pushReplacementNamed(context, '/home'),
              onProfile: () =>
                  Navigator.pushReplacementNamed(context, '/profile'),
              activeTab: BottomNavTab.home,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
          alignment: Alignment.topLeft,
          child: _CircleIconButton(
            icon: Icons.arrow_back,
            onTap: () => Navigator.maybePop(context),
          ),
        ),
      ),
    );
  }
}

class _TwoUpRow extends StatelessWidget {
  const _TwoUpRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 228,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9B9B9B)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 18,
            child: Container(
              width: 133,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8A8A8A)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'upload photos',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.41,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.maxLines = 1,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _label,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke, width: 1.2),
            color: Colors.white,
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            maxLines: maxLines,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              hintText: '',
              hintStyle: TextStyle(color: Color(0xFFB7AFC3)),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> options;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _label,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke, width: 1.2),
            color: Colors.white,
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items:
                options
                    .map(
                      (opt) =>
                          DropdownMenuItem<T>(value: opt, child: Text('$opt')),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color.fromRGBO(0, 0, 0, 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
