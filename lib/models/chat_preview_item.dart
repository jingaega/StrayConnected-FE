class ChatPreviewItem {
  final String userId;
  final String name;
  final String lastMessage;
  final DateTime lastAt;
  final int unreadCount;
  final String? avatarUrl;
  final String? rescuerId;
  final String? shelterId;

  const ChatPreviewItem({
    required this.userId,
    required this.name,
    required this.lastMessage,
    required this.lastAt,
    this.unreadCount = 0,
    this.avatarUrl,
    this.rescuerId,
    this.shelterId,
  });
}
