import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/chat_user.dart';

class AirChatStorageService {
  AirChatStorageService._();

  static final AirChatStorageService instance = AirChatStorageService._();

  static const String userIdKey = 'airchat.user_id';
  static const String displayNameKey = 'airchat.display_name';
  static const String autoAcceptKey = 'airchat.pref.auto_accept';
  static const String autoConnectKey = 'airchat.pref.auto_connect';
  static const String autoAdvertiseKey = 'airchat.pref.auto_advertise';
  static const String autoDiscoverKey = 'airchat.pref.auto_discover';
  static const String hotspotSsidKey = 'airchat.hotspot.ssid';
  static const String hotspotPasswordKey = 'airchat.hotspot.password';
  static const String hotspotNoteKey = 'airchat.hotspot.note';
  static const String chatUserIdsKey = 'airchat.chat.user_ids';
  static const String chatUserPrefix = 'airchat.chat.user.';
  static const String chatMessagesPrefix = 'airchat.chat.messages.';
  static const int messageLimit = 200;

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    if (!prefs.containsKey(userIdKey)) {
      await prefs.setString(userIdKey, const Uuid().v4());
    }
  }

  SharedPreferences get _requirePrefs {
    final prefs = _prefs;
    if (prefs == null) {
      throw StateError('AirChatStorageService not initialized');
    }
    return prefs;
  }

  String get userId => _requirePrefs.getString(userIdKey) ?? '';

  String get displayName =>
      _requirePrefs.getString(displayNameKey)?.trim().isNotEmpty == true
      ? _requirePrefs.getString(displayNameKey)!.trim()
      : 'AirChatUser';

  Future<void> setDisplayName(String value) async {
    await _requirePrefs.setString(displayNameKey, value.trim());
  }

  bool get autoAccept => _requirePrefs.getBool(autoAcceptKey) ?? false;
  bool get autoConnect => _requirePrefs.getBool(autoConnectKey) ?? false;
  bool get autoAdvertise => _requirePrefs.getBool(autoAdvertiseKey) ?? false;
  bool get autoDiscover => _requirePrefs.getBool(autoDiscoverKey) ?? false;

  Future<void> setAutoAccept(bool value) =>
      _requirePrefs.setBool(autoAcceptKey, value);

  Future<void> setAutoConnect(bool value) =>
      _requirePrefs.setBool(autoConnectKey, value);

  Future<void> setAutoAdvertise(bool value) =>
      _requirePrefs.setBool(autoAdvertiseKey, value);

  Future<void> setAutoDiscover(bool value) =>
      _requirePrefs.setBool(autoDiscoverKey, value);

  String get hotspotSsid =>
      _requirePrefs.getString(hotspotSsidKey)?.trim() ?? '';

  String get hotspotPassword =>
      _requirePrefs.getString(hotspotPasswordKey)?.trim() ?? '';

  String get hotspotNote =>
      _requirePrefs.getString(hotspotNoteKey)?.trim() ?? '';

  Future<void> saveHotspotProfile({
    required String ssid,
    required String password,
    required String note,
  }) async {
    await _requirePrefs.setString(hotspotSsidKey, ssid.trim());
    await _requirePrefs.setString(hotspotPasswordKey, password.trim());
    await _requirePrefs.setString(hotspotNoteKey, note.trim());
  }

  Future<Map<String, ChatUser>> loadUsers() async {
    final ids = _requirePrefs.getStringList(chatUserIdsKey) ?? <String>[];
    final result = <String, ChatUser>{};
    for (final String id in ids) {
      final rawUser = _requirePrefs.getString('$chatUserPrefix$id');
      if (rawUser == null || rawUser.isEmpty) {
        continue;
      }
      final decoded = jsonDecode(rawUser);
      if (decoded is! Map<String, dynamic>) {
        continue;
      }
      final rawMessages = _requirePrefs.getString('$chatMessagesPrefix$id');
      final messages = _decodeMessages(rawMessages);
      final user = ChatUser.fromJson(decoded).copyWith(messages: messages);
      result[id] = user;
    }
    return result;
  }

  Future<void> saveConversation(ChatUser user) async {
    final prefs = _requirePrefs;
    final trimmedMessages = user.messages.length <= messageLimit
        ? user.messages
        : user.messages.sublist(user.messages.length - messageLimit);
    final normalizedUser = user.copyWith(messages: trimmedMessages);
    final userPayload = normalizedUser.copyWith(messages: <ChatMessage>[]);
    final userIds = prefs.getStringList(chatUserIdsKey) ?? <String>[];
    if (!userIds.contains(user.id)) {
      userIds.add(user.id);
      await prefs.setStringList(chatUserIdsKey, userIds);
    }
    await prefs.setString(
      '$chatUserPrefix${user.id}',
      jsonEncode(userPayload.toJson()),
    );
    await prefs.setString(
      '$chatMessagesPrefix${user.id}',
      jsonEncode(
        trimmedMessages.map((ChatMessage item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> deleteConversation(String userId) async {
    final prefs = _requirePrefs;
    final userIds = prefs.getStringList(chatUserIdsKey) ?? <String>[];
    userIds.remove(userId);
    await prefs.setStringList(chatUserIdsKey, userIds);
    await prefs.remove('$chatUserPrefix$userId');
    await prefs.remove('$chatMessagesPrefix$userId');
  }

  List<ChatMessage> _decodeMessages(String? rawMessages) {
    if (rawMessages == null || rawMessages.isEmpty) {
      return <ChatMessage>[];
    }
    final decoded = jsonDecode(rawMessages);
    if (decoded is! List) {
      return <ChatMessage>[];
    }
    return decoded
        .whereType<Map>()
        .map(
          (Map item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}
