import 'chat_message.dart';

class ChatUser {
  const ChatUser({
    required this.id,
    required this.name,
    required this.lastSeen,
    required this.messages,
  });

  final String id;
  final String name;
  final DateTime lastSeen;
  final List<ChatMessage> messages;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  ChatUser copyWith({
    String? id,
    String? name,
    DateTime? lastSeen,
    List<ChatMessage>? messages,
  }) {
    return ChatUser(
      id: id ?? this.id,
      name: name ?? this.name,
      lastSeen: lastSeen ?? this.lastSeen,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'lastSeen': lastSeen.toIso8601String(),
      'messages': messages.map((ChatMessage item) => item.toJson()).toList(),
    };
  }

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
              .whereType<Map>()
              .map(
                (Map item) =>
                    ChatMessage.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : <ChatMessage>[];

    return ChatUser(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      lastSeen:
          DateTime.tryParse(json['lastSeen'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      messages: messages,
    );
  }
}
