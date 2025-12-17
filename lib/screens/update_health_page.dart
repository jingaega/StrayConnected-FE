import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/user_home_page.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);
const Color _accent = Color(0xFF0ACF83);
const String _animalFilesBucket = 'animal-files';

class HealthDraft {
  const HealthDraft({
    this.knownDiseases,
    this.isNeutered,
    this.certificateFile,
    this.certificateBytes,
  });

  final String? knownDiseases;
  final bool? isNeutered;
  final PlatformFile? certificateFile;
  final Uint8List? certificateBytes;
}

class UpdateHealthPage extends StatefulWidget {
  const UpdateHealthPage({
    super.key,
    this.pet,
    this.initialDraft,
    this.saveToDatabase = true,
  });

  final Pet? pet;
  final HealthDraft? initialDraft;
  final bool saveToDatabase;

  @override
  State<UpdateHealthPage> createState() => _UpdateHealthPageState();
}

class _UpdateHealthPageState extends State<UpdateHealthPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _diseaseCtrl = TextEditingController();

  String? _neuteredValue;
  PlatformFile? _certificateFile;
  Uint8List? _certificateBytes;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    if (draft != null) {
      _diseaseCtrl.text = draft.knownDiseases ?? '';
      _neuteredValue =
          draft.isNeutered == null ? null : (draft.isNeutered! ? 'Yes' : 'No');
      _certificateFile = draft.certificateFile;
      _certificateBytes = draft.certificateBytes;
    }
  }

  @override
  void dispose() {
    _diseaseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCertificate() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected file.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      setState(() {
        _certificateFile = file;
        _certificateBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick file: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<String?> _uploadCertificate(String userId) async {
    final file = _certificateFile;
    final bytes = _certificateBytes;
    if (file == null || bytes == null) return null;

    final extension = (file.extension ?? 'pdf').toLowerCase();
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final petId = widget.pet?.animalId;
    final suffix = petId == null ? 'draft' : 'animal_$petId';
    final path = 'certificates/$userId/${suffix}_$timestamp.$extension';

    await _supabase.storage.from(_animalFilesBucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: _contentTypeForExtension(extension),
        upsert: true,
      ),
    );

    return _supabase.storage.from(_animalFilesBucket).getPublicUrl(path);
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
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

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!widget.saveToDatabase) {
      final draft = HealthDraft(
        knownDiseases: _diseaseCtrl.text.trim().isEmpty
            ? null
            : _diseaseCtrl.text.trim(),
        isNeutered:
            _neuteredValue == null
                ? null
                : _neuteredValue == 'Yes',
        certificateFile: _certificateFile,
        certificateBytes: _certificateBytes,
      );
      Navigator.of(context).pop(draft);
      return;
    }

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

    setState(() => _isSubmitting = true);

    try {
      final uploadedCertificateUrl = await _uploadCertificate(userId);
      final existingCertificateUrl = widget.pet?.vaccinationCertificateUrl;
      final certificateUrl = uploadedCertificateUrl ?? existingCertificateUrl;
      final hasCertificate =
          certificateUrl != null && certificateUrl.trim().isNotEmpty;
      final knownDiseaseText = _diseaseCtrl.text.trim();
      final hasKnownDisease = knownDiseaseText.isNotEmpty;
      final healthStatus = _computeHealthStatus(
        hasCertificate: hasCertificate,
        hasKnownDisease: hasKnownDisease,
      );

      final Map<String, dynamic> payload = {
        'known_diseases': knownDiseaseText.isEmpty ? null : knownDiseaseText,
        'is_neutered':
            _neuteredValue == null
                ? null
                : _neuteredValue == 'Yes',
        'health_status': healthStatus,
      };
      if (uploadedCertificateUrl != null) {
        payload['vaccination_certificate_url'] = uploadedCertificateUrl;
      }

      final pet = widget.pet;
      if (pet == null) {
        throw Exception('Missing animal data for update.');
      }

      await _supabase
          .from('animal')
          .update(payload)
          .eq('animal_id', pet.animalId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Health updated successfully.'),
          backgroundColor: _accent,
        ),
      );
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update health: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    final imageUrl = pet?.primaryImageUrl;
    final ageLabel =
        pet?.age != null ? '${pet!.age} months old' : 'Age unknown';
    final name = pet?.name ?? 'New Animal';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TopBar(),
                  const SizedBox(height: 8),
                  const Text(
                    'Update Health',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.37,
                      letterSpacing: 0.41,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HeroImage(imageUrl: imageUrl),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.37,
                      letterSpacing: 0.41,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ageLabel,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _TwoUpRow(
                    left: _Field(
                      label: 'Known Diseases',
                      hint: 'None',
                      controller: _diseaseCtrl,
                    ),
                    right: _DropdownField(
                      label: 'Neutered/Spayed',
                      value: _neuteredValue,
                      options: const ['Yes', 'No'],
                      onChanged: (value) =>
                          setState(() => _neuteredValue = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _UploadField(
                    label: 'Vaccination Certificate',
                    fileName: _certificateFile?.name,
                    onTap: _pickCertificate,
                    helperText: 'PDF, PNG, JPG, or JPEG',
                  ),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
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
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: _CircleIconButton(
        icon: Icons.arrow_back,
        onTap: () => Navigator.maybePop(context),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade300,
        image:
            (imageUrl != null && imageUrl!.isNotEmpty)
                ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                )
                : null,
      ),
      alignment: Alignment.center,
      child:
          (imageUrl == null || imageUrl!.isEmpty)
              ? const Icon(Icons.pets, size: 52, color: _muted)
              : null,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

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
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
              hintText: hint,
              hintStyle: const TextStyle(color: _muted),
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
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

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
            hint: const Text('Yes/No', style: TextStyle(color: _muted)),
            items:
                options
                    .map(
                      (opt) =>
                          DropdownMenuItem<String>(value: opt, child: Text(opt)),
                    )
                    .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _UploadField extends StatelessWidget {
  const _UploadField({
    required this.label,
    required this.fileName,
    required this.onTap,
    required this.helperText,
  });

  final String label;
  final String? fileName;
  final VoidCallback onTap;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    final displayName = fileName ?? 'Insert Certificate';
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
        InkWell(
          onTap: onTap,
          child: Container(
            height: 48,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _stroke),
              color: Colors.white,
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.upload_file, color: _muted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          helperText,
          style: const TextStyle(color: _muted, fontSize: 11),
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
