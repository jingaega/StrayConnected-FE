import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/admin_edit_animal_page.dart';
import 'package:strayconnected/screens/shelter_profile_edit_page.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/strayconnected.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _purple = Color(0xFF5B30B5);
const Color _stroke = Color(0xFFD8D0E3);

class AdminConsolePage extends StatefulWidget {
  const AdminConsolePage({super.key});

  @override
  State<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends State<AdminConsolePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Pet> _animals = const [];
  List<Map<String, dynamic>> _shelters = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final animalsRaw = await _supabase
          .from('animal')
          .select(
            'animal_id, name, age, breed, species, description, health_status, known_diseases, vaccination_certificate_url, shelter_id, rescuer_id, link_picture',
          )
          .order('animal_id', ascending: false)
          .limit(50);

      final sheltersRaw = await _supabase
          .from('shelter')
          .select(
            'shelter_id, shelter_name, location, contact_info, status, credentials_url, shelter_photo_url',
          )
          .order('opened_on', ascending: false)
          .limit(50);

      if (!mounted) return;
      setState(() {
        _animals =
            (animalsRaw as List)
                .map((row) => Pet.fromMap(Map<String, dynamic>.from(row)))
                .toList();
        _shelters = _toList(sheltersRaw);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _toList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  Future<void> _openAnimalEditor(Pet pet) async {
    final updated = await Navigator.of(context).push<Pet>(
      MaterialPageRoute(
        builder: (_) => PlainWrapper(child: AdminEditAnimalPage(pet: pet)),
      ),
    );
    if (!mounted) return;
    if (updated != null) {
      await _load();
    }
  }

  void _openShelterProfile(Map<String, dynamic> shelter) {
    final shelterId = shelter['shelter_id']?.toString();
    if (shelterId == null || shelterId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ShelterProfileEditPage(),
        settings: RouteSettings(arguments: shelterId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Admin Console',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: _purple),
              )
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _SectionHeader(
                        title: 'Animals',
                        subtitle:
                            'Review and edit listings using the create-animal form with prefilled data.',
                        trailing: Text(
                          '${_animals.length}',
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_animals.isEmpty)
                        const _EmptyState(message: 'No animals found to review')
                      else
                        ..._animals
                            .map(
                              (pet) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AnimalCard(
                                  pet: pet,
                                  onTap: () => _openAnimalEditor(pet),
                                ),
                              ),
                            )
                            .toList(),
                      const SizedBox(height: 20),
                      _SectionHeader(
                        title: 'Shelters',
                        subtitle: 'Open shelter profiles to validate uploads.',
                        trailing: Text(
                          '${_shelters.length}',
                          style: const TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_shelters.isEmpty)
                        const _EmptyState(message: 'No shelters found')
                      else
                        ..._shelters
                            .map(
                              (shelter) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ShelterCard(
                                  shelter: shelter,
                                  onTap: () => _openShelterProfile(shelter),
                                ),
                              ),
                            )
                            .toList(),
                    ],
                  ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = pet.primaryImageUrl;
    final detailLine = [
      if ((pet.species ?? '').isNotEmpty) pet.species!.trim(),
      if ((pet.breed ?? '').isNotEmpty) pet.breed!.trim(),
    ].where((e) => e.isNotEmpty).join(' • ');

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imageUrl == null
                    ? Container(
                        width: 64,
                        height: 64,
                        color: _purple.withOpacity(0.08),
                        child: const Icon(Icons.pets, color: _purple),
                      )
                    : Image.network(
                        imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pet.name,
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detailLine.isEmpty ? 'No details' : detailLine,
                      style: const TextStyle(color: _muted, fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _purple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            pet.ageLabelShort,
                            style: const TextStyle(
                              color: _purple,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (pet.displayHealthLabel != null)
                          Text(
                            pet.displayHealthLabel!,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShelterCard extends StatelessWidget {
  const _ShelterCard({required this.shelter, required this.onTap});

  final Map<String, dynamic> shelter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = (shelter['shelter_name'] ?? 'Unnamed Shelter').toString();
    final location = (shelter['location'] ?? '').toString();
    final contact = (shelter['contact_info'] ?? '').toString();
    final status = (shelter['status'] ?? '').toString();

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.house_rounded, color: _purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (contact.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        contact,
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                    if (status.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inbox_outlined, color: _purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _muted),
            ),
          ),
        ],
      ),
    );
  }
}
