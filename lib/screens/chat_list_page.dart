import 'package:flutter/material.dart';
import 'package:strayconnected/models/chat_preview_item.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  static const _bgColor = Color(0xFFF6F5F5);
  static const _titleColor = Color(0xFF2D0C57);
  static const _subtitleColor = Color(0xFF9A9BB1);
  static const _dividerColor = Color(0xFFD8D0E3);
  static const _badgeColor = Color(0xFFA17ECE);

  @override
  Widget build(BuildContext context) {
    const double navHeight = 86;
    return Stack(
      children: [
        Container(
          color: _bgColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ChatAppBar(),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SearchBar(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, navHeight + 16),
                  itemBuilder: (context, index) {
                    final item = _chatData[index];
                    return _ChatTile(
                      item: item,
                      onTap:
                          () => Navigator.pushNamed(
                            context,
                            '/chatThread',
                            arguments: item,
                          ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 24),
                  itemCount: _chatData.length,
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
            activeTab: BottomNavTab.messages,
          ),
        ),
      ],
    );
  }
}

class _ChatAppBar extends StatelessWidget {
  const _ChatAppBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
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
      child: const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'Chats',
            style: TextStyle(
              color: ChatListPage._titleColor,
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: ChatListPage._dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: ChatListPage._subtitleColor),
          const SizedBox(width: 12),
          Text(
            'Search',
            style: const TextStyle(
              color: ChatListPage._subtitleColor,
              fontSize: 16,
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
                      color: Color(0xFF2C2D3A),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.message,
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
                  item.time,
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

const _chatData = <ChatPreviewItem>[
  ChatPreviewItem(
    name: 'Jono',
    message: 'He is an amazing puppy!',
    time: '10:25',
    unreadCount: 5,
    avatarUrl: 'https://placehold.co/42x42',
  ),
  ChatPreviewItem(
    name: 'Jino',
    message: 'Great, thanks so much! 💫',
    time: '22:20  09/05',
    unreadCount: 12,
    avatarUrl: 'https://placehold.co/42x42',
  ),
  ChatPreviewItem(
    name: 'Juno',
    message: 'Appreciate it! See you soon! 🚀',
    time: '10:45  08/05',
    unreadCount: 1,
    avatarUrl: 'https://placehold.co/42x42',
  ),
  ChatPreviewItem(
    name: 'Juna',
    message: 'NO!',
    time: '20:10  05/05',
    unreadCount: 0,
    avatarUrl: 'https://placehold.co/42x42',
  ),
  ChatPreviewItem(
    name: 'Jonu',
    message: 'I’ll be there at 11',
    time: '17:02  05/05',
    unreadCount: 0,
    avatarUrl: 'https://placehold.co/42x42',
  ),
  ChatPreviewItem(
    name: 'Jana',
    message: 'Oh he seems calm and distinguished',
    time: '11:20  05/05',
    unreadCount: 0,
    avatarUrl: 'https://placehold.co/42x42',
  ),
  ChatPreviewItem(
    name: 'JIni',
    message: 'He is so excited!. 👍',
    time: '19:35  02/05',
    unreadCount: 0,
    avatarUrl: 'https://placehold.co/42x42',
  ),
  ChatPreviewItem(
    name: 'Rodolfo Walter',
    message: 'Appreciate it!',
    time: '07:55  01/05',
    unreadCount: 0,
    avatarUrl: 'https://placehold.co/42x42',
  ),
];
