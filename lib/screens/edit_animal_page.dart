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
  final List<String> _extraBreeds = [];
  static const List<String> _catBreeds = [
    'Domestic Shorthair',
    'Domestic Longhair',
    'Domestic Mediumhair',
    'American Shorthair',
    'British Shorthair',
    'Maine Coon',
    'Siamese',
    'Persian',
    'Ragdoll',
    'Bengal',
    'Sphynx',
    'Scottish Fold',
    'Abyssinian',
    'Russian Blue',
    'Norwegian Forest',
    'Birman',
    'Oriental Shorthair',
    'Savannah',
    'Himalayan',
    'Manx',
    'Turkish Angora',
    'British Longhair',
    'American Curl',
    'Devon Rex',
    'Cornish Rex',
    'Bombay',
    'Burmese',
    'Chartreux',
    'Tonkinese',
    'Balinese',
    'Ocicat',
    'Exotic Shorthair',
    'Ragamuffin',
    'Selkirk Rex',
    'Snowshoe',
    'Somali',
    'Turkish Van',
    'Egyptian Mau',
    'Singapura',
    'American Bobtail',
    'American Wirehair',
    'LaPerm',
    'Korat',
    'Pixiebob',
    'Japanese Bobtail',
    'Munchkin',
    'Lykoi',
    'Oriental Longhair',
    'Chausie',
    'Nebelung',
    'Havana Brown',
    'Bicolor',
    'Tabby',
    'Tortoiseshell',
    'Calico',
    'Mixed',
    'Unknown',
  ];
  static const List<String> _dogBreeds = [
    'Labrador Retriever',
    'German Shepherd',
    'Golden Retriever',
    'French Bulldog',
    'Bulldog',
    'Poodle',
    'Beagle',
    'Rottweiler',
    'German Shorthaired Pointer',
    'Dachshund',
    'Pembroke Welsh Corgi',
    'Australian Shepherd',
    'Yorkshire Terrier',
    'Boxer',
    'Cavalier King Charles Spaniel',
    'Great Dane',
    'Siberian Husky',
    'Doberman Pinscher',
    'Shih Tzu',
    'Boston Terrier',
    'Pug',
    'Chihuahua',
    'Border Collie',
    'Basset Hound',
    'Maltese',
    'Cocker Spaniel',
    'Weimaraner',
    'Shetland Sheepdog',
    'Havanese',
    'Pomeranian',
    'Bernese Mountain Dog',
    'Mastiff',
    'Akita',
    'Bichon Frise',
    'Bull Terrier',
    'Chow Chow',
    'Collie',
    'Dalmatian',
    'Jack Russell Terrier',
    'Miniature Schnauzer',
    'Newfoundland',
    'Saint Bernard',
    'Shar Pei',
    'Vizsla',
    'Whippet',
    'Great Pyrenees',
    'Papillon',
    'Bloodhound',
    'Staffordshire Bull Terrier',
    'American Pit Bull Terrier',
    'Pit Bull',
    'Mixed',
    'Unknown',
  ];
  static const List<String> _genericBreeds = [
    'Mixed',
    'Unknown',
  ];

  String _selectedSpecies = 'Cat';
  String _selectedBreed = _catBreeds.first;
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
      if (!_extraBreeds.contains(breed)) {
        _extraBreeds.add(breed);
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

  List<String> _breedOptionsForSpecies(String species) {
    final base =
        species == 'Dog'
            ? _dogBreeds
            : (species == 'Cat' ? _catBreeds : _genericBreeds);
    final options = <String>[...base];
    for (final extra in _extraBreeds) {
      if (!options.contains(extra)) {
        options.insert(0, extra);
      }
    }
    return options;
  }

  void _setSpecies(String species) {
    setState(() {
      _selectedSpecies = species;
      final options = _breedOptionsForSpecies(species);
      if (!options.contains(_selectedBreed)) {
        _selectedBreed = options.first;
      }
    });
  }

  Future<void> _pickBreed() async {
    final options = _breedOptionsForSpecies(_selectedSpecies);
    final controller = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final sheetHeight = MediaQuery.of(context).size.height * 0.75;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final query = controller.text.trim().toLowerCase();
            final filtered =
                query.isEmpty
                    ? options
                    : options
                        .where(
                          (breed) => breed.toLowerCase().contains(query),
                        )
                        .toList();
            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SizedBox(
                  height: sheetHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      children: [
                        TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'Search breed',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child:
                              filtered.isEmpty
                                  ? const Center(child: Text('No breeds found.'))
                                  : ListView.separated(
                                      itemCount: filtered.length,
                                      separatorBuilder:
                                          (_, __) => const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final breed = filtered[index];
                                        return ListTile(
                                          title: Text(breed),
                                          onTap: () =>
                                              Navigator.pop(context, breed),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();
    if (selected == null) return;
    setState(() => _selectedBreed = selected);
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
                        onChanged: _setSpecies,
                      ),
                      const SizedBox(height: 12),
                      _PickerField(
                        label: 'Breed',
                        value: _selectedBreed,
                        onTap: _pickBreed,
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
    final List<String> safeOptions =
        options.contains(value) ? options : [value, ...options];
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
                safeOptions
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

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
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _stroke),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(color: _primary),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: _muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
