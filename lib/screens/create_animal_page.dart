import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/screens/update_health_page.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF3F0C7A);
const Color _accent = Color(0xFF0BCE83);
const Color _label = Color(0xFF7C7693);
const Color _stroke = Color(0xFFD8D0E3);
const String _animalImageBucket = 'animal-images';

class CreateAnimalPage extends StatefulWidget {
  const CreateAnimalPage({super.key, this.petToEdit});

  final Pet? petToEdit;

  @override
  State<CreateAnimalPage> createState() => _CreateAnimalPageState();
}

enum _AgeType { exact, estimated, unknown }

class _AgeRangeOption {
  const _AgeRangeOption({
    required this.label,
    required this.minMonths,
    this.maxMonths,
  });

  final String label;
  final int minMonths;
  final int? maxMonths;

  int representativeMonths() {
    if (maxMonths == null) return minMonths;
    return ((minMonths + maxMonths!) / 2).round();
  }
}

class _CreateAnimalPageState extends State<CreateAnimalPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _ageMonthsCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

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
  _AgeType _ageType = _AgeType.estimated;
  _AgeRangeOption _estimatedRange = const _AgeRangeOption(
    label: 'Young (3–12 months)',
    minMonths: 3,
    maxMonths: 12,
  );
  String? _role; // adopter | rescuer | shelter | admin
  final List<XFile> _selectedImages = [];
  final List<Uint8List> _selectedImageBytes = [];
  HealthDraft? _healthDraft;

  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  List<String> _prefilledImageUrls = const [];

  bool get _isEditing => widget.petToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.petToEdit != null) {
      _prefillFromPet(widget.petToEdit!);
    }
    _loadRole();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _ageMonthsCtrl.dispose();
    super.dispose();
  }

  void _prefillFromPet(Pet pet) {
    _nameCtrl.text = pet.name;
    _descriptionCtrl.text = pet.description ?? '';
    _prefilledImageUrls = pet.imageUrls;

    if (pet.age != null) {
      _ageType = _AgeType.exact;
      _ageMonthsCtrl.text = pet.age.toString();
    } else {
      _ageType = _AgeType.unknown;
    }

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

    _healthDraft = HealthDraft(
      knownDiseases: pet.knownDiseases,
      isNeutered: _healthDraft?.isNeutered,
    );
  }

  Future<bool> _submit() async {
    if (_isSubmitting) return false;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return false;

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }
    if (_role != 'rescuer' && _role != 'shelter' && _role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only rescuers, shelters, or admins can add animals.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return false;
    }

    setState(() => _isSubmitting = true);

    bool success = false;
    try {
      final certificateUrl =
          await _uploadDraftCertificate(userId) ??
              widget.petToEdit?.vaccinationCertificateUrl;
      final existingImages = widget.petToEdit?.imageUrls ?? [];
      final imageUrls =
          _selectedImages.isEmpty
              ? existingImages
              : await _uploadSelectedImages(userId);
      final knownDiseases =
          _healthDraft?.knownDiseases ?? widget.petToEdit?.knownDiseases;
      final hasKnownDisease =
          knownDiseases != null && knownDiseases.trim().isNotEmpty;
      final hasCertificate =
          certificateUrl != null && certificateUrl.trim().isNotEmpty;
      final healthStatus = _computeHealthStatus(
        hasCertificate: hasCertificate,
        hasKnownDisease: hasKnownDisease,
      );

      final Map<String, dynamic> payload = {
        'name': _nameCtrl.text.trim(),
        'age': _resolvedAgeMonths(),
        'breed': _selectedBreed,
        'species': _selectedSpecies,
        'description': _descriptionCtrl.text.trim(),
        'health_status': healthStatus,
        'link_picture': imageUrls.isNotEmpty ? jsonEncode(imageUrls) : '',
        'known_diseases': knownDiseases,
        'is_neutered': _healthDraft?.isNeutered,
        'vaccination_certificate_url': certificateUrl,
      };

      // Tag ownership based on role when creating
      if (!_isEditing) {
        if (_role == 'rescuer') {
          payload['rescuer_id'] = userId;
        } else if (_role == 'shelter') {
          payload['shelter_id'] = userId;
        } else if (_role == 'admin') {
          payload['shelter_id'] = userId;
        }
      }

      if (_isEditing) {
        await _supabase
            .from('animal')
            .update(payload)
            .eq('animal_id', widget.petToEdit!.animalId);
        success = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing updated'),
              backgroundColor: _accent,
            ),
          );
        }
      } else {
        await _supabase
            .from('animal')
            .insert(payload)
            .select(
              'animal_id, name, age, breed, species, description, health_status, known_diseases, vaccination_certificate_url, shelter_id, rescuer_id, link_picture',
            )
            .single();
        success = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Listing created!'),
              backgroundColor: _accent,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return false;
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
    return success;
  }

  Future<void> _openHealthDraft() async {
    final tempPet = Pet(
      animalId: -1,
      name: _nameCtrl.text.trim().isEmpty ? 'New Animal' : _nameCtrl.text.trim(),
      age: _resolvedAgeMonths(),
      breed: _selectedBreed,
      species: _selectedSpecies,
      description: _descriptionCtrl.text.trim(),
      healthStatus: null,
      knownDiseases: _healthDraft?.knownDiseases,
      vaccinationCertificateUrl: null,
      shelterId: null,
      rescuerId: null,
      linkPicture: '',
    );

    final draft = await Navigator.of(context).push<HealthDraft>(
      MaterialPageRoute(
        builder:
            (_) => UpdateHealthPage(
              pet: tempPet,
              initialDraft: _healthDraft,
              saveToDatabase: false,
            ),
      ),
    );

    if (draft == null || !mounted) return;
    setState(() => _healthDraft = draft);
  }

  Future<void> _deleteListing() async {
    if (!_isEditing || _isDeleting) return;
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete animal?'),
            content: const Text(
              'This will permanently delete the animal profile and its listing.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;

    setState(() => _isDeleting = true);
    try {
      await _supabase
          .from('animal')
          .delete()
          .eq('animal_id', widget.petToEdit!.animalId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Animal profile deleted'),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _pickImages() async {
    final remaining = 3 - _selectedImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload up to 3 photos.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked.isEmpty) return;

      final toAdd = picked.take(remaining).toList();
      final bytes = await Future.wait(toAdd.map((img) => img.readAsBytes()));
      if (!mounted) return;
      setState(() {
        _selectedImages.addAll(toAdd);
        _selectedImageBytes.addAll(bytes);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick image: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<List<String>> _uploadSelectedImages(String userId) async {
    if (_selectedImages.isEmpty) return [];

    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final List<String> urls = [];

    for (var i = 0; i < _selectedImages.length; i++) {
      final image = _selectedImages[i];
      final bytes =
          i < _selectedImageBytes.length
              ? _selectedImageBytes[i]
              : await image.readAsBytes();
      final extension = _extensionFromPath(image.path);
      final path = 'animals/$userId/${timestamp}_$i.$extension';

      await _supabase.storage.from(_animalImageBucket).uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: _contentTypeForExtension(extension),
          upsert: true,
        ),
      );

      urls.add(_supabase.storage.from(_animalImageBucket).getPublicUrl(path));
    }

    return urls;
  }

  String _extensionFromPath(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return 'jpg';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'pdf':
        return 'application/pdf';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  String? _computeHealthStatus({
    required bool hasCertificate,
    required bool hasKnownDisease,
  }) {
    if (hasCertificate && !hasKnownDisease) {
      return 'Vaccinated and Healthy';
    }
    if (hasCertificate && hasKnownDisease) {
      return 'Vaccinated';
    }
    if (!hasCertificate && !hasKnownDisease) {
      return 'Healthy';
    }
    return null;
  }

  Future<String?> _uploadDraftCertificate(String userId) async {
    final draft = _healthDraft;
    final file = draft?.certificateFile;
    final bytes = draft?.certificateBytes;
    if (file == null || bytes == null) return null;

    final extension = (file.extension ?? 'pdf').toLowerCase();
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final path = 'certificates/$userId/draft_$timestamp.$extension';

    await _supabase.storage.from('animal-files').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: _contentTypeForExtension(extension),
        upsert: true,
      ),
    );

    return _supabase.storage.from('animal-files').getPublicUrl(path);
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _validateExactAge(String? value) {
    if (_ageType != _AgeType.exact) return null;
    if (value == null || value.trim().isEmpty) return 'Required';
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return 'Enter months';
    if (parsed < 0 || parsed > 240) return 'Max 240 months';
    return null;
  }

  int? _resolvedAgeMonths() {
    switch (_ageType) {
      case _AgeType.exact:
        final parsed = int.tryParse(_ageMonthsCtrl.text.trim());
        return parsed;
      case _AgeType.estimated:
        return _estimatedRange.representativeMonths();
      case _AgeType.unknown:
        return null;
    }
  }

  void _removeImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() {
      _selectedImages.removeAt(index);
      if (index < _selectedImageBytes.length) {
        _selectedImageBytes.removeAt(index);
      }
    });
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
                          (breed) =>
                              breed.toLowerCase().contains(query),
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
    final String heading =
        _isEditing ? 'Review Animal Listing' : 'Post Your Animal';

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
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
                Text(
                  heading,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.37,
                    letterSpacing: 0.41,
                  ),
                ),
                const SizedBox(height: 20),
                _PhotoCard(
                  imageBytes: _selectedImageBytes,
                  existingImageUrls: _prefilledImageUrls,
                  onAdd: _pickImages,
                  onRemove: _removeImageAt,
                  isEditing: _isEditing,
                ),
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
                        right: _PickerField(
                          label: 'Breed',
                          value: _selectedBreed,
                          onTap: _pickBreed,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _AgeSection(
                        ageType: _ageType,
                        exactAgeController: _ageMonthsCtrl,
                        estimatedRange: _estimatedRange,
                        onAgeTypeChanged: (value) {
                          setState(() => _ageType = value);
                        },
                        onEstimatedRangeChanged: (value) {
                          setState(() => _estimatedRange = value);
                        },
                        exactAgeValidator: _validateExactAge,
                      ),
                      const SizedBox(height: 14),
                      _DropdownField<String>(
                        label: 'Species',
                        value: _selectedSpecies,
                        options: _speciesOptions,
                        onChanged: (v) {
                          if (v == null) return;
                          _setSpecies(v);
                        },
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 40,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: const BorderSide(
                                color: _stroke,
                                width: 1.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            onPressed:
                                _isSubmitting ? null : _openHealthDraft,
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
                      ),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 20),
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0ACF83),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : () async {
                                      final ok = await _submit();
                                      if (!mounted || !ok) return;
                                      if (_isEditing) {
                                        Navigator.of(context).maybePop();
                                      } else {
                                        Navigator.of(context, rootNavigator: true)
                                            .pushNamedAndRemoveUntil(
                                          '/home',
                                          (route) => false,
                                        );
                                      }
                                    },
                              child: _isSubmitting
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isEditing ? 'UPDATE LISTING' : 'CONFIRM',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: -0.01,
                                      ),
                                    ),
                            ),
                          ),
                          if (_isEditing) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: _isDeleting ? null : _deleteListing,
                                child: _isDeleting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation(Colors.red),
                                        ),
                                      )
                                    : const Text(
                                        'DELETE ANIMAL PROFILE',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
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
  const _PhotoCard({
    required this.onAdd,
    required this.onRemove,
    required this.imageBytes,
    this.existingImageUrls = const [],
    this.isEditing = false,
  });

  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final List<Uint8List> imageBytes;
  final List<String> existingImageUrls;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final hasNewImages = imageBytes.isNotEmpty;
    final hasExistingImages = existingImageUrls.isNotEmpty;
    final hasImages = hasNewImages || hasExistingImages;
    return Container(
      width: double.infinity,
      height: 228,
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9B9B9B)),
      ),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          if (hasImages)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: List.generate(
                  hasNewImages ? imageBytes.length : existingImageUrls.length,
                  (index) {
                    final bytes =
                        hasNewImages ? imageBytes[index] : null;
                    final url =
                        hasNewImages ? null : existingImageUrls[index];
                    return _PhotoThumb(
                      bytes: bytes,
                      networkUrl: url,
                      onRemove: hasNewImages ? () => onRemove(index) : null,
                    );
                  },
                ),
              ),
            ),
          Positioned(
            bottom: 18,
            child: SizedBox(
              width: 133,
              height: 38,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF8A8A8A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onAdd,
                child: Text(
                  isEditing
                      ? 'change image'
                      : hasImages
                          ? 'add photos'
                          : 'upload photos',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.41,
                  ),
                ),
              ),
            ),
          ),
          if (hasImages)
            Positioned(
              top: 12,
              right: 14,
              child: Text(
                '${hasNewImages ? imageBytes.length : existingImageUrls.length}/3',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({
    this.bytes,
    this.networkUrl,
    this.onRemove,
  });

  final Uint8List? bytes;
  final String? networkUrl;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final imageWidget = bytes != null
        ? Image.memory(bytes!, width: 86, height: 86, fit: BoxFit.cover)
        : networkUrl != null
            ? Image.network(
                networkUrl!,
                width: 86,
                height: 86,
                fit: BoxFit.cover,
              )
            : const SizedBox.shrink();
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageWidget,
        ),
        if (onRemove != null)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _AgeSection extends StatelessWidget {
  const _AgeSection({
    required this.ageType,
    required this.exactAgeController,
    required this.estimatedRange,
    required this.onAgeTypeChanged,
    required this.onEstimatedRangeChanged,
    this.exactAgeValidator,
  });

  final _AgeType ageType;
  final TextEditingController exactAgeController;
  final _AgeRangeOption estimatedRange;
  final ValueChanged<_AgeType> onAgeTypeChanged;
  final ValueChanged<_AgeRangeOption> onEstimatedRangeChanged;
  final FormFieldValidator<String>? exactAgeValidator;

  static const List<_AgeRangeOption> _rangeOptions = [
    _AgeRangeOption(label: 'Baby (0-3 months)', minMonths: 0, maxMonths: 3),
    _AgeRangeOption(label: 'Young (3-12 months)', minMonths: 3, maxMonths: 12),
    _AgeRangeOption(label: 'Adult (1-7 years)', minMonths: 12, maxMonths: 84),
    _AgeRangeOption(label: 'Senior (7+ years)', minMonths: 84),
  ];

  String _labelForType(_AgeType type) {
    switch (type) {
      case _AgeType.exact:
        return 'Exact age known';
      case _AgeType.estimated:
        return 'Estimated age';
      case _AgeType.unknown:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Age Type',
          style: TextStyle(
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
            child: Column(
              children:
                  const [
                    _AgeType.estimated,
                    _AgeType.exact,
                    _AgeType.unknown,
                  ].map((type) {
                    return RadioListTile<_AgeType>(
                      value: type,
                      groupValue: ageType,
                      onChanged: (value) {
                        if (value != null) onAgeTypeChanged(value);
                      },
                      dense: true,
                      title: Text(_labelForType(type)),
                    );
                  }).toList(),
            ),
        ),
        if (ageType == _AgeType.exact) ...[
          const SizedBox(height: 10),
          const Text(
            'Exact Age (months)',
            style: TextStyle(
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
              controller: exactAgeController,
              validator: exactAgeValidator,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                hintText: 'e.g., 8',
                hintStyle: TextStyle(color: Color(0xFFB7AFC3)),
                border: InputBorder.none,
                suffixText: 'months',
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter months only (0-240).',
            style: TextStyle(
              color: _label,
              fontSize: 11,
            ),
          ),
        ],
        if (ageType == _AgeType.estimated) ...[
          const SizedBox(height: 10),
          const Text(
            'Estimated age range',
            style: TextStyle(
              color: _label,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _rangeOptions.map((opt) {
                  final selected = opt.label == estimatedRange.label;
                  return ChoiceChip(
                    label: Text(opt.label),
                    selected: selected,
                    onSelected: (_) => onEstimatedRangeChanged(opt),
                  );
                }).toList(),
          ),
          const SizedBox(height: 6),
          const Text(
            'Estimated age is totally okay for rescued animals.',
            style: TextStyle(
              color: _label,
              fontSize: 11,
            ),
          ),
        ],
      ],
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
    final List<T> safeOptions =
        options.contains(value) ? options : [value, ...options];
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
                safeOptions
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
            color: _label,
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke, width: 1.2),
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
                const Icon(Icons.arrow_drop_down, color: _label),
              ],
            ),
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
