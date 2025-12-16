import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/models/chat_preview_item.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

class ChatThreadPage extends StatefulWidget {
  const ChatThreadPage({super.key, required this.item});

  final ChatPreviewItem item;

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<_ChatMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;
  String? _otherName;
  String? _otherRole;

  @override
  void initState() {
    super.initState();
    _otherName = widget.item.name.isNotEmpty ? widget.item.name : null;
    _loadOtherNameIfNeeded();
    _loadMessages();
    _subscribe();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadOtherNameIfNeeded() async {
    if (_otherName != null &&
        _otherName!.trim().isNotEmpty &&
        _otherName != 'User') return;

    // Prefer rescuer/shelter names if IDs are provided
    if (widget.item.rescuerId != null && widget.item.rescuerId!.isNotEmpty) {
      final resc =
          await _supabase
              .from('rescuer')
              .select('rescuer_name')
              .eq('rescuer_id', widget.item.rescuerId!)
              .maybeSingle();
      if (resc != null &&
          (resc['rescuer_name'] as String?)?.trim().isNotEmpty == true) {
        setState(() => _otherName = (resc['rescuer_name'] as String).trim());
        return;
      }
    }
    if (widget.item.shelterId != null && widget.item.shelterId!.isNotEmpty) {
      final shel =
          await _supabase
              .from('shelter')
              .select('shelter_name')
              .eq('shelter_id', widget.item.shelterId!)
              .maybeSingle();
      if (shel != null &&
          (shel['shelter_name'] as String?)?.trim().isNotEmpty == true) {
        setState(() => _otherName = (shel['shelter_name'] as String).trim());
        return;
      }
    }

    final profile =
        await _supabase.from('user').select('name, email, role').eq('id', widget.item.userId).maybeSingle();
    if (!mounted) return;
    _otherRole = profile?['role'] as String?;
    final fetched =
        ((profile?['name'] as String?)?.trim().isNotEmpty ?? false)
            ? (profile?['name'] as String).trim()
            : ((profile?['email'] as String?)?.trim().isNotEmpty ?? false)
                ? (profile?['email'] as String).trim()
                : (widget.item.name.isNotEmpty ? widget.item.name : 'User');

    // Try rescuer/shelter tables if applicable
    if (_otherRole == 'rescuer') {
      final resc =
          await _supabase.from('rescuer').select('rescuer_name').eq('rescuer_id', widget.item.userId).maybeSingle();
      if (resc != null &&
          (resc['rescuer_name'] as String?)?.trim().isNotEmpty == true) {
        setState(() => _otherName = (resc['rescuer_name'] as String).trim());
        return;
      }
    } else if (_otherRole == 'shelter') {
      final shel =
          await _supabase.from('shelter').select('shelter_name').eq('shelter_id', widget.item.userId).maybeSingle();
      if (shel != null &&
          (shel['shelter_name'] as String?)?.trim().isNotEmpty == true) {
        setState(() => _otherName = (shel['shelter_name'] as String).trim());
        return;
      }
    }

    setState(() {
      _otherName = fetched;
    });
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
    });
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _messages = const [];
        _loading = false;
      });
      return;
    }
    final other = widget.item.userId;
    try {
      final response =
          await _supabase
              .from('inquiry')
              .select('inquiry_id, message, date, sender_id, receiver_id')
              .or(
                'and(sender_id.eq.$uid,receiver_id.eq.$other),and(sender_id.eq.$other,receiver_id.eq.$uid)',
              )
              .order('date', ascending: true)
              .limit(400);

      final list = (response as List)
          .map((raw) => _ChatMessage.fromMap(Map<String, dynamic>.from(raw)))
          .toList();

      if (!mounted) return;
      setState(() {
        _messages = list;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load messages: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _subscribe() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    final other = widget.item.userId;
    _channel = _supabase.channel(
      'inquiry-${uid.substring(0, 6)}-${other.substring(0, 6)}',
      opts: const RealtimeChannelConfig(),
    )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'inquiry',
        callback: (payload) {
          final newRecord = payload.newRecord;
          if (newRecord == null) return;
          final senderId = newRecord['sender_id'] as String?;
          final receiverId = newRecord['receiver_id'] as String?;
          final isMine = senderId == uid && receiverId == other;
          final isTheirs = senderId == other && receiverId == uid;
          if (!isMine && !isTheirs) return;
          final msg =
              _ChatMessage.fromMap(Map<String, dynamic>.from(newRecord));
          if (!mounted) return;
          setState(() => _messages = [..._messages, msg]);
          _scrollToBottom();
        },
      )
      ..subscribe();
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to send messages.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final bool hasRescuer =
          widget.item.rescuerId != null && widget.item.rescuerId!.isNotEmpty;
      final bool hasShelter =
          widget.item.shelterId != null && widget.item.shelterId!.isNotEmpty;

      final payload = <String, dynamic>{
        'message': text,
        'sender_id': uid,
        'receiver_id': widget.item.userId,
        if (hasRescuer) 'rescuer_id': widget.item.rescuerId,
        if (hasShelter) 'shelter_id': widget.item.shelterId,
        // Fallback to satisfy NOT NULL if neither provided
        if (!hasRescuer && !hasShelter) 'shelter_id': widget.item.userId,
      };

      final inserted =
          await _supabase
              .from('inquiry')
              .insert(payload)
              .select('inquiry_id, message, date, sender_id, receiver_id')
              .maybeSingle();

      if (inserted != null) {
        final msg =
            _ChatMessage.fromMap(Map<String, dynamic>.from(inserted));
        if (mounted) {
          setState(() => _messages = [..._messages, msg]);
          _scrollToBottom();
        }
      }

      _inputCtrl.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = _otherName ?? widget.item.name;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _Header(name: name),
            const Divider(height: 1, color: Color(0xFFD8D0E3)),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMine =
                            msg.senderId == _supabase.auth.currentUser?.id;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: isMine
                              ? _OutgoingBubble(
                                  text: msg.content,
                                  time: msg.displayTime,
                                )
                              : _IncomingBubble(
                                  text: msg.content,
                                  time: msg.displayTime,
                                ),
                        );
                      },
                    ),
            ),
            _MessageInputBar(
              controller: _inputCtrl,
              sending: _sending,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
      bottomNavigationBar: RoleAwareBottomNav(
        onCreateAllowed: () => Navigator.pushNamed(context, '/createAnimal'),
        onHome: () => Navigator.pushReplacementNamed(context, '/home'),
        onMessages: () => Navigator.pushReplacementNamed(context, '/chats'),
        onMeetings: () => Navigator.pushReplacementNamed(context, '/meetings'),
        onProfile: () => Navigator.pushReplacementNamed(context, '/profile'),
        activeTab: BottomNavTab.messages,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F5F5),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF2D0C57)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF0D1217),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.call_outlined, color: Color(0xFF2D0C57)),
          ),
        ],
      ),
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  const _OutgoingBubble({required this.text, required this.time});

  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFA17ECE),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(color: Color(0xFFE9EAEB), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomingBubble extends StatelessWidget {
  const _IncomingBubble({required this.text, required this.time});

  final String text;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(color: Color(0xFF2C2D3A), fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(color: Color(0xFFD0D1DB), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.add, color: Color(0xFF2D0C57)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F3),
                borderRadius: BorderRadius.circular(10),
              ),
              height: 56,
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Type a message ...',
                  border: InputBorder.none,
                ),
                minLines: 1,
                maxLines: 3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFA17ECE),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F0D0A2C),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : IconButton(
                    onPressed: onSend,
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final int id;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime createdAt;

  _ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
  });

  factory _ChatMessage.fromMap(Map<String, dynamic> map) {
    return _ChatMessage(
      id: (map['inquiry_id'] as num?)?.toInt() ??
          (map['id'] as num?)?.toInt() ??
          0,
      senderId: (map['sender_id'] as String?) ?? '',
      receiverId: (map['receiver_id'] as String?) ?? '',
      content: (map['message'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get displayTime =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
}
