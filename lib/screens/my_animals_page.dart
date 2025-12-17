import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/screens/update_health_page.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);

class MyAnimalsPage extends StatefulWidget {
  const MyAnimalsPage({super.key});

  @override
  State<MyAnimalsPage> createState() => _MyAnimalsPageState();
}

class _MyAnimalsPageState extends State<MyAnimalsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  String _role = 'user';
  bool _loading = true;
  String? _error;
  List<Pet> _animals = const [];

  @override
  void initState() {
    super.initState();
    _loadRoleAndAnimals();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoleAndAnimals() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _role = 'user';
        _animals = const [];
        _loading = false;
      });
      return;
    }

    String role = 'user';
    try {
      final data =
          await _supabase.from('user').select('role').eq('id', uid).maybeSingle();
      role = (data?['role'] as String?) ?? 'user';
    } catch (_) {
      role = 'user';
    }

    if (role != 'rescuer' && role != 'shelter') {
      setState(() {
        _role = role;
        _animals = const [];
        _loading = false;
      });
      return;
    }

    try {
      final filterColumn = role == 'rescuer' ? 'rescuer_id' : 'shelter_id';
      final response =
          await _supabase
              .from('animal')
              .select(
                'animal_id, name, age, breed, species, description, health_status, shelter_id, rescuer_id, link_picture',
              )
              .eq(filterColumn, uid)
              .order('animal_id', ascending: false);

      final list = (response as List)
          .map((raw) => Pet.fromMap(Map<String, dynamic>.from(raw)))
          .toList();

      if (!mounted) return;
      setState(() {
        _role = role;
        _animals = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _role = role;
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Pet> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _animals;
    return _animals.where((p) {
      bool matches(String? s) => s != null && s.toLowerCase().contains(q);
      return matches(p.name) || matches(p.breed) || matches(p.species);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const double navHeight = 86;
    final isOwner = _role == 'rescuer' || _role == 'shelter';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadRoleAndAnimals,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 12, 20, navHeight + 24 + paddingBottom),
                children: [
                  const SizedBox(height: 4),
                  const Text(
                    'My Animals',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.21,
                      letterSpacing: 0.41,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SearchField(
                    controller: _searchCtrl,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 18),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (!isOwner)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'Only rescuers or shelters can view their animals.',
                        style: const TextStyle(color: _muted),
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
                  else if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        'No animals found.',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  else
                    _AnimalGrid(animals: _filtered),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RoleAwareBottomNav(
                onCreateAllowed: () => Navigator.pushNamed(context, '/createAnimal'),
                onHome: () => Navigator.pushReplacementNamed(context, '/home'),
                onMessages: () =>
                    Navigator.pushReplacementNamed(context, '/chats'),
                onMeetings: () =>
                    Navigator.pushReplacementNamed(context, '/meetings'),
                onProfile: () => Navigator.pushReplacementNamed(context, '/profile'),
                activeTab: BottomNavTab.home,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: 'Search',
        prefixIcon: const Icon(Icons.search, color: _muted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(27),
          borderSide: const BorderSide(color: _stroke, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(27),
          borderSide: const BorderSide(color: _primary, width: 1.3),
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
        MaterialPageRoute(builder: (_) => UpdateHealthPage(pet: pet)),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'edit',
                style: TextStyle(
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
}
