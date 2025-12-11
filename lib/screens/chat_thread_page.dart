import 'package:flutter/material.dart';
import 'package:strayconnected/models/chat_preview_item.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

class ChatThreadPage extends StatelessWidget {
  const ChatThreadPage({super.key, required this.item});

  final ChatPreviewItem item;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _Header(item: item),
            const Divider(height: 1, color: Color(0xFFD8D0E3)),
            const SizedBox(height: 12),
            const Expanded(child: _MessageList()),
            const _MessageInputBar(),
          ],
        ),
      ),
      bottomNavigationBar: RoleAwareBottomNav(
        onCreateAllowed: () => Navigator.pushNamed(context, '/createAnimal'),
        onHome: () => Navigator.pushReplacementNamed(context, '/home'),
        onProfile: () =>
            Navigator.pushReplacementNamed(context, '/profile'),
        activeTab: BottomNavTab.profile,
      ),
    );
  }
}

void _noop() {}

class _Header extends StatelessWidget {
  const _Header({required this.item});

  final ChatPreviewItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Color(0xFF2D0C57),
            ),
          ),
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              width: 42,
              height: 42,
              child: FadeInImage.assetNetwork(
                placeholder: 'assets/images/catlogo.png',
                image: item.avatarUrl,
                fit: BoxFit.cover,
                imageErrorBuilder:
                    (_, __, ___) => Image.asset(
                      'assets/images/catlogo.png',
                      fit: BoxFit.cover,
                    ),
              ),
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
                    color: Color(0xFF0D1217),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Shelter',
                  style: const TextStyle(
                    color: Color(0xFF686A8A),
                    fontSize: 12,
                  ),
                ),
              ],
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

class _MessageList extends StatelessWidget {
  const _MessageList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _OutgoingBubble(text: 'Hey there! 👋 ', time: '10:10'),
          SizedBox(height: 10),
          _OutgoingBubble(
            text:
                'He seems amazing! can’t wait to meet him tomorrow. When will I be able to pick him up?',
            time: '10:11',
          ),
          SizedBox(height: 10),
          _IncomingBubble(text: 'Hi!', time: '10:10'),
          SizedBox(height: 10),
          _IncomingBubble(
            text:
                'Awesome, thanks for adopting him! He can be picked up at 14:00. 🎉',
            time: '10:10',
          ),
          SizedBox(height: 10),
          _OutgoingBubble(
            text: 'No problem at all! \nI’ll be sure to update you.',
            time: '10:12',
          ),
          SizedBox(height: 10),
          _IncomingBubble(text: 'You’re Welcome!!', time: '10:11'),
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
  const _MessageInputBar();

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
              child: const Text(
                'Type a message ...',
                style: TextStyle(
                  color: Color(0xFF0D1217),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
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
            child: const Icon(Icons.send, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}
