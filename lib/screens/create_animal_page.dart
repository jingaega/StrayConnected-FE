import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/screens/update_health_page.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF3F0C7A);
const Color _accent = Color(0xFF0BCE83);
const Color _label = Color(0xFF7C7693);
const Color _stroke = Color(0xFFD8D0E3);
const String _animalImageBucket = 'animal-images';

class CreateAnimalPage extends StatefulWidget {
  const CreateAnimalPage({super.key});

  @override
  State<CreateAnimalPage> createState() => _CreateAnimalPageState();
}

class _CreateAnimalPageState extends State<CreateAnimalPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

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
  final List<XFile> _selectedImages = [];
  final List<Uint8List> _selectedImageBytes = [];
  HealthDraft? _healthDraft;

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
      final certificateUrl = await _uploadDraftCertificate(userId);
      final imageUrls = await _uploadSelectedImages(userId);
      final hasKnownDisease =
          _healthDraft?.knownDiseases != null &&
          _healthDraft!.knownDiseases!.trim().isNotEmpty;
      final hasCertificate =
          certificateUrl != null && certificateUrl.trim().isNotEmpty;
      final healthStatus = _computeHealthStatus(
        hasCertificate: hasCertificate,
        hasKnownDisease: hasKnownDisease,
      );

      final Map<String, dynamic> payload = {
        'name': _nameCtrl.text.trim(),
        'age': _selectedAge,
        'breed': _selectedBreed,
        'species': _selectedSpecies,
        'description': _descriptionCtrl.text.trim(),
        'health_status': healthStatus,
        'link_picture': imageUrls.isNotEmpty ? jsonEncode(imageUrls) : '',
        'known_diseases': _healthDraft?.knownDiseases,
        'is_neutered': _healthDraft?.isNeutered,
        'vaccination_certificate_url': certificateUrl,
      };

      // Tag ownership based on role
      if (_role == 'rescuer') {
        payload['rescuer_id'] = userId;
      } else if (_role == 'shelter') {
        payload['shelter_id'] = userId;
      }

      final created =
          await _supabase
              .from('animal')
              .insert(payload)
              .select(
                'animal_id, name, age, breed, species, description, health_status, known_diseases, vaccination_certificate_url, shelter_id, rescuer_id, link_picture',
              )
              .single();

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

  Future<void> _openHealthDraft() async {
    final tempPet = Pet(
      animalId: -1,
      name: _nameCtrl.text.trim().isEmpty ? 'New Animal' : _nameCtrl.text.trim(),
      age: _selectedAge,
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

  void _removeImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    setState(() {
      _selectedImages.removeAt(index);
      if (index < _selectedImageBytes.length) {
        _selectedImageBytes.removeAt(index);
      }
    });
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
                _PhotoCard(
                  imageBytes: _selectedImageBytes,
                  onAdd: _pickImages,
                  onRemove: _removeImageAt,
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
                          onPressed:
                              _isSubmitting ? null : _submit,
                          child:
                              _isSubmitting
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
                                    'CONFIRM',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RoleAwareBottomNav(
              onCreateAllowed: _submit,
              onHome: () => Navigator.pushReplacementNamed(context, '/home'),
              onMessages: () =>
                  Navigator.pushReplacementNamed(context, '/chats'),
              onMeetings: () =>
                  Navigator.pushReplacementNamed(context, '/meetings'),
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
  const _PhotoCard({
    required this.onAdd,
    required this.onRemove,
    required this.imageBytes,
  });

  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final List<Uint8List> imageBytes;

  @override
  Widget build(BuildContext context) {
    final hasImages = imageBytes.isNotEmpty;
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
                  imageBytes.length,
                  (index) => _PhotoThumb(
                    bytes: imageBytes[index],
                    onRemove: () => onRemove(index),
                  ),
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
                  hasImages ? 'add photos' : 'upload photos',
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
                '${imageBytes.length}/3',
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
  const _PhotoThumb({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(bytes, width: 86, height: 86, fit: BoxFit.cover),
        ),
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
