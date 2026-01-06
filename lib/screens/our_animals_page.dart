import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/pet_profile_page.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);

class OurAnimalsPage extends StatefulWidget {
  const OurAnimalsPage({super.key, required this.shelterId});

  final String shelterId;

  @override
  State<OurAnimalsPage> createState() => _OurAnimalsPageState();
}

class _OurAnimalsPageState extends State<OurAnimalsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Pet> _animals = const [];

  @override
  void initState() {
    super.initState();
    _loadAnimals();
  }

  Future<void> _loadAnimals() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await _supabase
              .from('animal')
              .select(
                'animal_id, name, age, breed, species, description, health_status, shelter_id, rescuer_id, link_picture',
              )
              .eq('shelter_id', widget.shelterId)
              .order('animal_id', ascending: false);

      final list = (response as List)
          .map((raw) => Pet.fromMap(Map<String, dynamic>.from(raw)))
          .toList();

      if (!mounted) return;
      setState(() {
        _animals = list;
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

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const double navHeight = 86;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadAnimals,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  navHeight + 24 + paddingBottom,
                ),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back, color: _primary),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Our Animals',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Could not load animals:\n$_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  else if (_animals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No animals found.',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  else
                    _AnimalGrid(animals: _animals),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RoleAwareBottomNav(
                onCreateAllowed: () =>
                    Navigator.pushNamed(context, '/createAnimal'),
                onHome: () => Navigator.pushReplacementNamed(context, '/home'),
                onMessages: () =>
                    Navigator.pushReplacementNamed(context, '/chats'),
                onMeetings: () =>
                    Navigator.pushReplacementNamed(context, '/meetings'),
                onProfile: () =>
                    Navigator.pushReplacementNamed(context, '/profile'),
                onShelterProfile: () =>
                    Navigator.pushReplacementNamed(context, '/shelterProfile'),
                activeTab: BottomNavTab.home,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalGrid extends StatelessWidget {
  const _AnimalGrid({required this.animals});
  final List<Pet> animals;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: animals.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.84,
      ),
      itemBuilder: (context, index) {
        final pet = animals[index];
        return _AnimalCard(pet: pet);
      },
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PetProfilePage(pet: pet)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _stroke),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Container(
                height: 140,
                width: double.infinity,
                color: Colors.grey.shade200,
                child:
                    (pet.primaryImageUrl != null &&
                            pet.primaryImageUrl!.isNotEmpty)
                        ? Image.network(pet.primaryImageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.pets, size: 40, color: _muted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Text(
                pet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                _animalMeta(pet),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _animalMeta(Pet pet) {
    final parts = <String>[];
    if (pet.breed != null && pet.breed!.isNotEmpty) {
      parts.add(pet.breed!.trim());
    } else if (pet.species != null && pet.species!.isNotEmpty) {
      parts.add(pet.species!.trim());
    }
    if (pet.age != null) {
      parts.add(pet.ageLabelShort);
    }
    return parts.isEmpty ? 'Unknown' : parts.join(' - ');
  }
}
