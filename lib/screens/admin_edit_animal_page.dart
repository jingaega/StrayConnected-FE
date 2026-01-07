import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:strayconnected/screens/update_health_page.dart';
import 'package:strayconnected/screens/user_home_page.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);
const Color _accent = Color(0xFF0ACF83);
const String _animalImageBucket = 'animal-images';
const String _animalFilesBucket = 'animal-files';

class AdminEditAnimalPage extends StatefulWidget {
  const AdminEditAnimalPage({super.key, required this.pet});

  final Pet pet;

  @override
  State<AdminEditAnimalPage> createState() => _AdminEditAnimalPageState();
}

class _AdminEditAnimalPageState extends State<AdminEditAnimalPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<String> _speciesOptions = ['Cat', 'Dog', 'Other'];
  final List<String> _breedOptions = ['Calico', 'Mixed', 'Husky', 'Unknown'];

  String _selectedSpecies = 'Cat';
  String _selectedBreed = 'Mixed';
  bool _loading = true;
  bool _saving = false;
  bool _deleting = false;
  String? _error;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _currentImageUrl;
  List<String> _currentImageUrls = const [];

  @override
  void initState() {
    super.initState();
    _hydrateFields(widget.pet);
    _loading = false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _hydrateFields(Pet pet) {
    _nameCtrl.text = pet.name;
    _descriptionCtrl.text = pet.description ?? '';
    _ageCtrl.text = pet.age == null ? '' : pet.age.toString();
    _currentImageUrl = pet.primaryImageUrl;
    _currentImageUrls = pet.imageUrls;

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
    if (_saving) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _saving = true);
    try {
      final userId = _supabase.auth.currentUser?.id ?? 'admin';
      List<String> imageUrls = _currentImageUrls;
      if (_selectedImage != null && _selectedImageBytes != null) {
        final uploaded = await _uploadSelectedImage(userId);
        imageUrls = uploaded == null ? [] : [uploaded];
      }
      final encodedImages =
          imageUrls.isNotEmpty ? jsonEncode(imageUrls) : null;

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
        'link_picture': encodedImages,
      };

      final updatedRows = await _supabase
          .from('animal')
          .update(payload)
          .eq('animal_id', widget.pet.animalId)
          .select(
            'animal_id, name, age, breed, species, description, health_status, known_diseases, vaccination_certificate_url, shelter_id, rescuer_id, link_picture',
          );
      final updatedList =
          updatedRows is List
              ? updatedRows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList()
              : const <Map<String, dynamic>>[];
      final updated = updatedList.isNotEmpty ? updatedList.first : null;

      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No changes saved. Check permissions or filters.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Animal updated.'),
          backgroundColor: _accent,
        ),
      );
      Navigator.of(context).maybePop(Pet.fromMap(updated));
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

  Future<void> _delete() async {
    if (_deleting) return;
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

    setState(() => _deleting = true);
    try {
      await _supabase
          .from('animal')
          .delete()
          .eq('animal_id', widget.pet.animalId);
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
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImage = picked;
        _selectedImageBytes = bytes;
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

  Future<String?> _uploadSelectedImage(String userId) async {
    if (_selectedImage == null || _selectedImageBytes == null) return null;
    final extension = _extensionFromPath(_selectedImage!.path);
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final path = 'admin/$userId/$timestamp.$extension';

    await _supabase.storage.from(_animalImageBucket).uploadBinary(
      path,
      _selectedImageBytes!,
      fileOptions: FileOptions(
        contentType: _contentTypeForExtension(extension),
        upsert: true,
      ),
    );

    return _supabase.storage.from(_animalImageBucket).getPublicUrl(path);
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
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _approveHealth() async {
    await _supabase
        .from('animal')
        .update({'health_status': 'Verified by admin'})
        .eq('animal_id', widget.pet.animalId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Health info approved'),
        backgroundColor: _accent,
      ),
    );
  }

  Future<void> _rejectHealth() async {
    await _supabase
        .from('animal')
        .update({'health_status': 'Rejected by admin'})
        .eq('animal_id', widget.pet.animalId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Health info rejected'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Edit Animal (Admin)',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(
                label: 'Animal Name',
                hint: 'Name',
                controller: _nameCtrl,
                validator: _required,
              ),
              const SizedBox(height: 12),
              _ImageSection(
                imageBytes: _selectedImageBytes,
                imageUrl: _currentImageUrl,
                onChange: _pickImage,
              ),
              const SizedBox(height: 12),
              _DropdownField<String>(
                label: 'Breed',
                value: _selectedBreed,
                options: _breedOptions,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBreed = val);
                },
              ),
              const SizedBox(height: 12),
              _AgeField(
                controller: _ageCtrl,
                validator: _validateAge,
              ),
              const SizedBox(height: 12),
              _DropdownField<String>(
                label: 'Species',
                value: _selectedSpecies,
                options: _speciesOptions,
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSpecies = val);
                },
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Description',
                hint: 'Story, temperament, notes',
                controller: _descriptionCtrl,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              _HealthRow(
                pet: widget.pet,
                onEdit: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UpdateHealthPage(
                        pet: widget.pet,
                        saveToDatabase: true,
                      ),
                    ),
                  );
                },
                onApprove: _approveHealth,
                onReject: _rejectHealth,
                onViewCertificate: _viewCertificate,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Update listing'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _deleting ? null : _delete,
                  child: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.red),
                          ),
                        )
                      : const Text(
                          'Delete animal profile',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _viewCertificate() async {
    final url = widget.pet.vaccinationCertificateUrl;
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No vaccination file'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final secureUrl = await _buildSignedCertificateUrl(url);
    final pdfUrl = secureUrl ?? url;
    final uri = Uri.tryParse(pdfUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid vaccination file link'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PdfViewerPage(
          url: pdfUrl,
          downloadUrl: pdfUrl,
        ),
      ),
    );
  }

  Future<String?> _buildSignedCertificateUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_animalFilesBucket);
    if (bucketIndex == -1 || bucketIndex >= segments.length - 1) return null;
    final path = segments.sublist(bucketIndex + 1).join('/');
    try {
      final signed = await _supabase.storage
          .from(_animalFilesBucket)
          .createSignedUrl(path, 300);
      return signed;
    } catch (_) {
      return null;
    }
  }
}

class _PdfViewerPage extends StatelessWidget {
  const _PdfViewerPage({required this.url, required this.downloadUrl});

  final String url;
  final String downloadUrl;

  @override
  Widget build(BuildContext context) {
    return _PdfViewerStateful(url: url, downloadUrl: downloadUrl);
  }
}

class _PdfViewerStateful extends StatefulWidget {
  const _PdfViewerStateful({required this.url, required this.downloadUrl});

  final String url;
  final String downloadUrl;

  @override
  State<_PdfViewerStateful> createState() => _PdfViewerStatefulState();
}

class _PdfViewerStatefulState extends State<_PdfViewerStateful> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDoc();
  }

  Future<void> _loadDoc() async {
    try {
      final uri = Uri.parse(widget.url);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        setState(() {
          _error = 'Failed to load file (status ${response.statusCode})';
          _loading = false;
        });
        return;
      }
      final doc = PdfDocument.openData(response.bodyBytes);
      setState(() {
        _controller = PdfControllerPinch(document: doc);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaccination File'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                )
              : PdfViewPinch(
                  controller: _controller!,
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: () async {
            final uri = Uri.tryParse(widget.downloadUrl);
            if (uri == null) return;
            final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not open PDF externally'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          icon: const Icon(Icons.download),
          label: const Text('Open in external PDF app'),
        ),
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
            color: _primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _stroke),
            color: Colors.white,
          ),
          child: TextFormField(
            controller: controller,
            validator: validator,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
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
    if (safeOptions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke),
              color: Colors.white,
            ),
            child: const Text(
              'No options',
              style: TextStyle(color: _muted),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _stroke),
            color: Colors.white,
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            onChanged: onChanged,
            items: safeOptions
                .map(
                  (opt) => DropdownMenuItem<T>(
                    value: opt,
                    child: Text(opt.toString()),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _AgeField extends StatelessWidget {
  const _AgeField({required this.controller, this.validator});

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return _Field(
      label: 'Age (months)',
      hint: 'Ex: 12',
      controller: controller,
      validator: validator,
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.pet,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
    required this.onViewCertificate,
  });

  final Pet pet;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewCertificate;

  @override
  Widget build(BuildContext context) {
    final health = pet.displayHealthLabel ?? 'Health info pending';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          const Icon(Icons.health_and_safety_outlined, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              health,
              style: const TextStyle(color: _muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: onEdit,
                child: const Text('Edit'),
              ),
              TextButton(
                onPressed: onViewCertificate,
                child: const Text('View file'),
              ),
              TextButton(
                onPressed: onApprove,
                child: const Text(
                  'Approve',
                  style: TextStyle(color: _accent),
                ),
              ),
              TextButton(
                onPressed: onReject,
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.imageBytes,
    required this.imageUrl,
    required this.onChange,
  });

  final Uint8List? imageBytes;
  final String? imageUrl;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (imageBytes != null) {
      preview = Image.memory(imageBytes!, width: 140, height: 140, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      preview = Image.network(imageUrl!, width: 140, height: 140, fit: BoxFit.cover);
    } else {
      preview = Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: _stroke.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _stroke),
        ),
        child: const Icon(Icons.pets, size: 48, color: _muted),
      );
    }

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: preview,
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _primary,
            side: const BorderSide(color: _stroke),
          ),
          onPressed: onChange,
          icon: const Icon(Icons.image_outlined),
          label: const Text('Change image'),
        ),
      ],
    );
  }
}
