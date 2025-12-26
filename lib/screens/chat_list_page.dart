import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/models/chat_preview_item.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  static const _bgColor = Color(0xFFF6F5F5);
  static const _titleColor = Color(0xFF2D0C57);
  static const _subtitleColor = Color(0xFF9A9BB1);
  static const _dividerColor = Color(0xFFD8D0E3);
  static const _badgeColor = Color(0xFFA17ECE);

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  List<ChatPreviewItem> _items = const [];
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _items = const [];
        _loading = false;
        _error = 'Not logged in.';
      });
      return;
    }
    try {
      final response =
          await _supabase
              .from('inquiry')
              .select(
                'inquiry_id, message, date, sender_id, receiver_id, rescuer_id, shelter_id, '
                'sender:sender_id(name, email), '
                'receiver:receiver_id(name, email)',
              )
              .or('sender_id.eq.$uid,receiver_id.eq.$uid')
              .order('date', ascending: false)
              .limit(200);

      final List<dynamic> rows = response as List<dynamic>;
      final Map<String, ChatPreviewItem> grouped = {};

      for (final raw in rows) {
        final map = Map<String, dynamic>.from(raw as Map);
        final senderId = map['sender_id'] as String?;
        final receiverId = map['receiver_id'] as String?;
        final createdAt = DateTime.tryParse(map['date'] as String? ?? '');
        final content = (map['message'] as String?) ?? '';
        final rescuerId = map['rescuer_id'] as String?;
        final shelterId = map['shelter_id'] as String?;

        if (senderId == null || receiverId == null || createdAt == null) {
          continue;
        }

        final otherId = senderId == uid ? receiverId : senderId;
        final otherProfile =
            senderId == uid ? map['receiver'] as Map? : map['sender'] as Map?;
        final otherName =
            ((otherProfile?['name'] as String?)?.trim().isNotEmpty ?? false)
                ? (otherProfile?['name'] as String).trim()
                : ((otherProfile?['email'] as String?)?.trim().isNotEmpty ??
                        false)
                    ? (otherProfile?['email'] as String).trim()
                    : 'User';

        // Only attach rescuer/shelter ids if they refer to the other participant.
        final otherRescuer = (rescuerId != null && rescuerId == otherId)
            ? rescuerId
            : null;
        final otherShelter = (shelterId != null && shelterId == otherId)
            ? shelterId
            : null;

        final existing = grouped[otherId];
        if (existing == null || createdAt.isAfter(existing.lastAt)) {
          grouped[otherId] = ChatPreviewItem(
            userId: otherId,
            name: otherName,
            lastMessage: content,
            lastAt: createdAt,
            unreadCount: 0, // simple placeholder; could be computed later
            avatarUrl: 'https://placehold.co/42x42',
            rescuerId: otherRescuer,
            shelterId: otherShelter,
          );
        }
      }

      final items = grouped.values.toList()
        ..sort((a, b) => b.lastAt.compareTo(a.lastAt));

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      _resolveNames();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<ChatPreviewItem> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where((i) => i.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    const double navHeight = 86;
    return Stack(
      children: [
        Container(
          color: ChatListPage._bgColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChatAppBar(
                controller: _searchCtrl,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadChats,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              Text(
                                'Could not load chats:\n$_error',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ],
                          )
                          : _filtered.isEmpty
                              ? ListView(
                                padding: const EdgeInsets.all(20),
                                children: const [
                                  Text(
                                    'No chats yet.',
                                    style: TextStyle(color: ChatListPage._subtitleColor),
                                  ),
                                ],
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  navHeight + 16,
                                ),
                                itemBuilder: (context, index) {
                                  final item = _filtered[index];
                                  return _ChatTile(
                                    item: item,
                                    onTap: () => Navigator.pushNamed(
                                      context,
                                      '/chatThread',
                                      arguments: item,
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemCount: _filtered.length,
                              ),
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
            onCreateAllowed: () => Navigator.pushNamed(context, '/createAnimal'),
            onHome: () => Navigator.pushReplacementNamed(context, '/home'),
            onMessages: () => Navigator.pushReplacementNamed(context, '/chats'),
            onMeetings: () =>
                Navigator.pushReplacementNamed(context, '/meetings'),
            onProfile: () =>
                Navigator.pushReplacementNamed(context, '/profile'),
            onShelterProfile: () =>
                Navigator.pushReplacementNamed(context, '/shelterProfile'),
            activeTab: BottomNavTab.messages,
          ),
        ),
      ],
    );
  }

  Future<void> _resolveNames() async {
    final List<ChatPreviewItem> updated = [];
    for (final item in _items) {
      if (item.name != 'User') continue;
      final resolved = await _fetchDisplayName(item);
      if (resolved != null && resolved != item.name) {
        updated.add(
          ChatPreviewItem(
            userId: item.userId,
            name: resolved,
            lastMessage: item.lastMessage,
            lastAt: item.lastAt,
            unreadCount: item.unreadCount,
            avatarUrl: item.avatarUrl,
            rescuerId: item.rescuerId,
            shelterId: item.shelterId,
          ),
        );
      }
    }
    if (updated.isEmpty || !mounted) return;
    setState(() {
      final map = {for (var i in _items) i.userId: i};
      for (final u in updated) {
        map[u.userId] = u;
      }
      _items = map.values.toList()
        ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    });
  }

  Future<String?> _fetchDisplayName(ChatPreviewItem item) async {
    final userId = item.userId;
    if (_nameCache.containsKey(userId)) return _nameCache[userId];
    try {
      // Use rescuer/shelter tables when IDs are available
      if (item.rescuerId != null && item.rescuerId!.isNotEmpty) {
        final resc =
            await _supabase.from('rescuer').select('rescuer_name').eq('rescuer_id', item.rescuerId!).maybeSingle();
        if (resc != null &&
            (resc['rescuer_name'] as String?)?.trim().isNotEmpty == true) {
          final name = (resc['rescuer_name'] as String).trim();
          _nameCache[userId] = name;
          return name;
        }
      }
      if (item.shelterId != null && item.shelterId!.isNotEmpty) {
        final shel =
            await _supabase.from('shelter').select('shelter_name').eq('shelter_id', item.shelterId!).maybeSingle();
        if (shel != null &&
            (shel['shelter_name'] as String?)?.trim().isNotEmpty == true) {
          final name = (shel['shelter_name'] as String).trim();
          _nameCache[userId] = name;
          return name;
        }
      }

      final profile =
          await _supabase.from('user').select('name, email, role').eq('id', userId).maybeSingle();
      if (profile == null) return null;
      final role = profile['role'] as String? ?? 'user';
      String name =
          ((profile['name'] as String?)?.trim().isNotEmpty ?? false)
              ? (profile['name'] as String).trim()
              : ((profile['email'] as String?)?.trim().isNotEmpty ?? false)
                  ? (profile['email'] as String).trim()
                  : 'User';

      if (role == 'rescuer') {
        final resc =
            await _supabase.from('rescuer').select('rescuer_name').eq('rescuer_id', userId).maybeSingle();
        if (resc != null &&
            (resc['rescuer_name'] as String?)?.trim().isNotEmpty == true) {
          name = (resc['rescuer_name'] as String).trim();
        }
      } else if (role == 'shelter') {
        final shel =
            await _supabase.from('shelter').select('shelter_name').eq('shelter_id', userId).maybeSingle();
        if (shel != null &&
            (shel['shelter_name'] as String?)?.trim().isNotEmpty == true) {
          name = (shel['shelter_name'] as String).trim();
        }
      }
      _nameCache[userId] = name;
      return name;
    } catch (_) {
      return null;
    }
  }
}

class _ChatAppBar extends StatelessWidget {
  const _ChatAppBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ChatListPage._bgColor,
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chats',
            style: TextStyle(
              color: ChatListPage._titleColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search, color: ChatListPage._subtitleColor),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(27),
                borderSide: const BorderSide(color: ChatListPage._dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(27),
                borderSide: const BorderSide(color: ChatListPage._titleColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.item, required this.onTap});

  final ChatPreviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                width: 42,
                height: 42,
                child:
                    (item.avatarUrl != null && item.avatarUrl!.isNotEmpty)
                        ? FadeInImage.assetNetwork(
                          placeholder: 'assets/images/catlogo.png',
                          image: item.avatarUrl!,
                          fit: BoxFit.cover,
                          imageErrorBuilder:
                              (_, __, ___) => Image.asset(
                                'assets/images/catlogo.png',
                                fit: BoxFit.cover,
                              ),
                        )
                        : Image.asset('assets/images/catlogo.png'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: Color(0xFF2C2D3A),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.lastMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ChatListPage._subtitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(item.lastAt),
                  style: const TextStyle(
                    color: Color(0xFF686A8A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (item.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: ChatListPage._badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _timeLabel(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
