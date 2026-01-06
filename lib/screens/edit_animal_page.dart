import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/update_health_page.dart';
import 'package:strayconnected/screens/user_home_page.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);
const Color _accent = Color(0xFF0ACF83);

class EditAnimalPage extends StatefulWidget {
  const EditAnimalPage({super.key, required this.pet});

  final Pet pet;

  @override
  State<EditAnimalPage> createState() => _EditAnimalPageState();
}

class _EditAnimalPageState extends State<EditAnimalPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();

  final List<String> _speciesOptions = ['Cat', 'Dog', 'Other'];
  final List<String> _breedOptions = ['Calico', 'Mixed', 'Husky', 'Unknown'];

  String _selectedSpecies = 'Cat';
  String _selectedBreed = 'Mixed';
  bool _loading = true;
  bool _saving = false;
  bool _canEdit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _error = 'Not logged in';
        _loading = false;
      });
      return;
    }

    String role = 'user';
    try {
      final data =
          await _supabase.from('user').select('role').eq('id', uid).maybeSingle();
      role = (data?['role'] as String?) ?? 'user';
    } catch (_) {}

    final isOwner =
        (widget.pet.shelterId != null && widget.pet.shelterId == uid) ||
        (widget.pet.rescuerId != null && widget.pet.rescuerId == uid);
    final canEdit = isOwner || role == 'admin';

    _hydrateFields(widget.pet);
    setState(() {
      _canEdit = canEdit;
      _loading = false;
      _error = canEdit ? null : 'You do not have access to edit this animal.';
    });
  }

  void _hydrateFields(Pet pet) {
    _nameCtrl.text = pet.name;
    _descriptionCtrl.text = pet.description ?? '';
    _ageCtrl.text = pet.age == null ? '' : pet.age.toString();

    if (pet.species != null && pet.species!.trim().isNotEmpty) {
      final species = pet.species!.trim();
      if (!_speciesOptions.contains(species)) {
        _speciesOptions.add(species);
      }
      _selectedSpecies = species;
    }

    if (pet.breed != null && pet.breed!.trim().isNotEmpty) {
      final breed = pet.breed!.trim();
      if (!_breedOptions.contains(breed)) {
        _breedOptions.add(breed);
      }
      _selectedBreed = breed;
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter months';
    if (parsed < 0 || parsed > 240) return 'Max 240 months';
    return null;
  }

  Future<void> _save() async {
    if (_saving || !_canEdit) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _saving = true);
    try {
      final ageValue = _ageCtrl.text.trim();
      final payload = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'age': ageValue.isEmpty ? null : int.parse(ageValue),
        'breed': _selectedBreed,
        'species': _selectedSpecies,
        'description':
            _descriptionCtrl.text.trim().isEmpty
                ? null
                : _descriptionCtrl.text.trim(),
      };

      await _supabase
          .from('animal')
          .update(payload)
          .eq('animal_id', widget.pet.animalId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Animal updated.'),
          backgroundColor: _accent,
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openHealthEdit() async {
    if (!_canEdit) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UpdateHealthPage(pet: widget.pet)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back, color: _primary),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Edit Animal',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Field(
                        label: 'Name',
                        controller: _nameCtrl,
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Age (months)',
                        controller: _ageCtrl,
                        validator: _validateAge,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _DropdownField(
                        label: 'Species',
                        value: _selectedSpecies,
                        options: _speciesOptions,
                        onChanged:
                            (value) => setState(() => _selectedSpecies = value),
                      ),
                      const SizedBox(height: 12),
                      _DropdownField(
                        label: 'Breed',
                        value: _selectedBreed,
                        options: _breedOptions,
                        onChanged:
                            (value) => setState(() => _selectedBreed = value),
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        label: 'Description',
                        controller: _descriptionCtrl,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: const BorderSide(color: _stroke, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          onPressed: _openHealthEdit,
                          child: const Text(
                            'Update health info',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.01,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _saving ? null : _save,
                          child:
                              _saving
                                  ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                  : const Text(
                                    'SAVE CHANGES',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.01,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _stroke),
            color: Colors.white,
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _stroke),
            color: Colors.white,
          ),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items:
                options
                    .map(
                      (opt) => DropdownMenuItem<String>(
                        value: opt,
                        child: Text(opt),
                      ),
                    )
                    .toList(),
            onChanged: (value) {
              if (value == null) return;
              onChanged(value);
            },
          ),
        ),
      ],
    );
  }
}
