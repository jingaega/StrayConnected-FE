import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Set<int> _selectedMessageIds = {};
  final Set<int> _hiddenMessageIds = {};

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
        _otherName != 'User') {
      return;
    }

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
      List<dynamic> response;
      try {
        response =
            await _supabase
                .from('inquiry')
                .select('inquiry_id, message, date, sender_id, receiver_id, edited_at, deleted_at')
                .or(
                  'and(sender_id.eq.$uid,receiver_id.eq.$other),and(sender_id.eq.$other,receiver_id.eq.$uid)',
                )
                .order('date', ascending: true)
                .limit(400) as List<dynamic>;
      } catch (_) {
        response =
            await _supabase
                .from('inquiry')
                .select('inquiry_id, message, date, sender_id, receiver_id')
                .or(
                  'and(sender_id.eq.$uid,receiver_id.eq.$other),and(sender_id.eq.$other,receiver_id.eq.$uid)',
                )
                .order('date', ascending: true)
                .limit(400) as List<dynamic>;
      }

      final list = response
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
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
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
          final updated =
              _ChatMessage.fromMap(Map<String, dynamic>.from(newRecord));
          if (!mounted) return;
          setState(() => _replaceMessage(updated));
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

      bool includeShelter = false;
      if (hasShelter) {
        includeShelter = await _shelterExists(widget.item.shelterId!);
      }

      final payload = <String, dynamic>{
        'message': text,
        'sender_id': uid,
        'receiver_id': widget.item.userId,
        if (hasRescuer) 'rescuer_id': widget.item.rescuerId,
        if (includeShelter) 'shelter_id': widget.item.shelterId,
      };

      Map<String, dynamic>? inserted;
      try {
        inserted =
            await _supabase
                .from('inquiry')
                .insert(payload)
                .select('inquiry_id, message, date, sender_id, receiver_id, edited_at, deleted_at')
                .maybeSingle() as Map<String, dynamic>?;
      } catch (_) {
        inserted =
            await _supabase
                .from('inquiry')
                .insert(payload)
                .select('inquiry_id, message, date, sender_id, receiver_id')
                .maybeSingle() as Map<String, dynamic>?;
      }

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

  Future<void> _showMessageActions(_ChatMessage message) async {
    // Deprecated: UI now uses the header menu for actions after selecting a message.
  }

  void _selectMessage(_ChatMessage message) {
    setState(() => _selectedMessageIds.add(message.id));
  }

  void _toggleSelection(_ChatMessage message) {
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  void _clearSelection() => setState(() => _selectedMessageIds.clear());

  List<_ChatMessage> _selectedOwnedMessages() {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null || _selectedMessageIds.isEmpty) return [];
    return _messages
        .where((m) =>
            _selectedMessageIds.contains(m.id) &&
            m.senderId == uid &&
            !m.isDeleted)
        .toList();
  }

  void _handleMenuAction(String action) {
    final selected = _selectedOwnedMessages();
    switch (action) {
      case 'edit':
        if (selected.length != 1) {
          _promptSelectMessage(
            message: 'Select exactly one of your messages to edit.',
          );
          return;
        }
        _editMessage(selected.first);
        _clearSelection();
        break;
      case 'delete':
        if (selected.isEmpty) {
          _promptSelectMessage(
            message: 'Select at least one of your messages to delete.',
          );
          return;
        }
        _confirmDelete(selected);
        break;
      case 'info':
        _showProfileInfo();
        break;
      case 'view_shelter':
        _handleViewShelter();
        break;
      default:
        break;
    }
  }

  void _handleViewShelter() {
    final shelterId =
        (widget.item.shelterId != null && widget.item.shelterId!.isNotEmpty)
            ? widget.item.shelterId
            : (_otherRole == 'shelter' ? widget.item.userId : null);
    if (shelterId == null || shelterId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No shelter profile available for this chat.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      '/shelterProfile',
      arguments: {'shelterId': shelterId},
    );
  }

  void _promptSelectMessage({String message = 'Long-press a message, then use the menu.'}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _confirmDelete(List<_ChatMessage> messages) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: const Text('Delete for me'),
              onTap: () => Navigator.pop(context, 'me'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
              title: const Text('Delete for everyone'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'me') {
      setState(() {
        for (final msg in messages) {
          _hiddenMessageIds.add(msg.id);
          _selectedMessageIds.remove(msg.id);
        }
      });
    } else if (choice == 'all') {
      for (final msg in messages) {
        await _deleteMessage(msg);
      }
      _clearSelection();
    }
  }

  void _showProfileInfo() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _otherName ?? 'User',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Profile details not available.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editMessage(_ChatMessage message) async {
    final controller = TextEditingController(text: message.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Update your message',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (newText == null || newText.isEmpty || newText == message.content) {
      return;
    }

    try {
      Map<String, dynamic>? updated;
      try {
        updated =
            await _supabase
                .from('inquiry')
                .update({
                  'message': newText,
                  'edited_at': DateTime.now().toIso8601String(),
                })
                .eq('inquiry_id', message.id)
                .select('inquiry_id, message, date, sender_id, receiver_id, edited_at, deleted_at')
                .maybeSingle() as Map<String, dynamic>?;
      } catch (_) {
        // Fallback if edited_at column is missing
        updated =
            await _supabase
                .from('inquiry')
                .update({'message': newText})
                .eq('inquiry_id', message.id)
                .select('inquiry_id, message, date, sender_id, receiver_id')
                .maybeSingle() as Map<String, dynamic>?;
      }

      if (updated == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not edit message (no row updated). Check permissions.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (updated != null && mounted) {
        final map = Map<String, dynamic>.from(updated);
        setState(
          () => _replaceMessage(
            _ChatMessage.fromMap(map),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not edit message: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _deleteMessage(_ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This will delete the message for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      Map<String, dynamic>? updated;
      try {
        updated =
            await _supabase
                .from('inquiry')
                .update({
                  'deleted_at': DateTime.now().toIso8601String(),
                })
                .eq('inquiry_id', message.id)
                .select('inquiry_id, message, date, sender_id, receiver_id, edited_at, deleted_at')
                .maybeSingle() as Map<String, dynamic>?;
      } catch (_) {
        // Fallback if deleted_at column is missing
        updated =
            await _supabase
                .from('inquiry')
                .update({})
                .eq('inquiry_id', message.id)
                .select('inquiry_id, message, date, sender_id, receiver_id')
                .maybeSingle() as Map<String, dynamic>?;
      }

      if (updated == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete message (no row updated). Check permissions.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      if (updated != null && mounted) {
        final map = Map<String, dynamic>.from(updated);
        setState(
          () => _replaceMessage(
            _ChatMessage.fromMap(map),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<bool> _shelterExists(String id) async {
    try {
      final row =
          await _supabase.from('shelter').select('shelter_id').eq('shelter_id', id).maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  void _replaceMessage(_ChatMessage updated) {
    final index = _messages.indexWhere((m) => m.id == updated.id);
    if (index == -1) {
      _messages = [..._messages, updated];
      return;
    }
    final copy = [..._messages];
    copy[index] = updated;
    _messages = copy;
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
    final canViewShelter =
        (widget.item.shelterId != null && widget.item.shelterId!.isNotEmpty) ||
        _otherRole == 'shelter';
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              name: name,
              onMenu: _handleMenuAction,
              hasSelection: _selectedOwnedMessages().isNotEmpty,
              canViewShelter: canViewShelter,
            ),
            const Divider(height: 1, color: Color(0xFFD8D0E3)),
            const SizedBox(height: 12),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _clearSelection,
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
                        if (_hiddenMessageIds.contains(msg.id)) {
                          return const SizedBox.shrink();
                        }
                        final isMine =
                            msg.senderId == _supabase.auth.currentUser?.id;
                        final isSelected = _selectedMessageIds.contains(msg.id);
                        final selectionMode = _selectedMessageIds.isNotEmpty;
                        final canSelect = isMine && !msg.isDeleted;
                        final checkbox = selectionMode && canSelect
                            ? Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF00C853)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF00C853)
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        size: 16, color: Colors.black)
                                    : null,
                              )
                            : const SizedBox.shrink();

                        final bubble = isMine
                            ? _OutgoingBubble(
                                text: msg.viewText(isMine: true),
                                time: msg.displayTime,
                                edited: msg.isEdited,
                                deleted: msg.isDeleted,
                                isSelected: isSelected,
                                selectionMode: selectionMode,
                                onTap: selectionMode && canSelect
                                    ? () {
                                        _toggleSelection(msg);
                                      }
                                    : null,
                                onLongPress: canSelect
                                    ? () {
                                        HapticFeedback.selectionClick();
                                        _toggleSelection(msg);
                                      }
                                    : null,
                              )
                            : _IncomingBubble(
                                text: msg.viewText(isMine: false),
                                time: msg.displayTime,
                                edited: msg.isEdited,
                                deleted: msg.isDeleted,
                              );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 8),
                              checkbox,
                              const SizedBox(width: 8),
                              Expanded(
                                child: Align(
                                  alignment: isMine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: bubble,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
        onShelterProfile: () =>
            Navigator.pushReplacementNamed(context, '/shelterProfile'),
        activeTab: BottomNavTab.messages,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.onMenu,
    required this.hasSelection,
    required this.canViewShelter,
  });

  final String name;
  final void Function(String action) onMenu;
  final bool hasSelection;
  final bool canViewShelter;

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
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Message actions',
            onSelected: onMenu,
            itemBuilder: (context) => hasSelection
                ? [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ]
                : [
                    const PopupMenuItem(
                      value: 'info',
                      child: Text('Profile info'),
                    ),
                    if (canViewShelter)
                      const PopupMenuItem(
                        value: 'view_shelter',
                        child: Text('View Shelter'),
                      ),
                  ],
            icon: const Icon(Icons.more_vert, color: Color(0xFF2D0C57)),
          ),
        ],
      ),
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  const _OutgoingBubble({
    required this.text,
    required this.time,
    this.edited = false,
    this.deleted = false,
    this.isSelected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
  });

  final String text;
  final String time;
  final bool edited;
  final bool deleted;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
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
            text.isEmpty ? 'Message deleted' : text,
            style: TextStyle(
              color: deleted ? Colors.white70 : Colors.white,
              fontSize: 16,
              fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (edited && !deleted)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text(
                    'edited',
                    style: TextStyle(
                      color: Color(0xFFE9EAEB),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              Text(
                time,
                style: const TextStyle(color: Color(0xFFE9EAEB), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: bubble,
          ),
        ),
      ),
    );
  }
}

class _IncomingBubble extends StatelessWidget {
  const _IncomingBubble({
    required this.text,
    required this.time,
    this.edited = false,
    this.deleted = false,
  });

  final String text;
  final String time;
  final bool edited;
  final bool deleted;

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
                text.isEmpty ? 'Message deleted' : text,
                style: TextStyle(
                  color: const Color(0xFF2C2D3A),
                  fontSize: 16,
                  fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (edited && !deleted)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text(
                        'edited',
                        style: TextStyle(
                          color: Color(0xFFD0D1DB),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  Text(
                    time,
                    style: const TextStyle(color: Color(0xFFD0D1DB), fontSize: 12),
                  ),
                ],
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
  final Future<void> Function() onSend;

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
                    onPressed: () {
                      onSend();
                    },
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
  final DateTime? editedAt;
  final DateTime? deletedAt;

  _ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
    this.editedAt,
    this.deletedAt,
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
      editedAt: DateTime.tryParse(map['edited_at'] as String? ?? ''),
      deletedAt: DateTime.tryParse(map['deleted_at'] as String? ?? ''),
    );
  }

  String get displayTime =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  bool get isEdited => editedAt != null;
  bool get isDeleted => deletedAt != null;
  String get displayContent => isDeleted ? 'Message deleted' : content;
  String viewText({required bool isMine}) =>
      isDeleted && !isMine ? 'Message deleted' : content;

  factory _ChatMessage.empty() => _ChatMessage(
        id: -1,
        senderId: '',
        receiverId: '',
        content: '',
        createdAt: DateTime.now(),
      );
}
