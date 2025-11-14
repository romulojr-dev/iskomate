import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  final String id; // unique id (timestamp string)
  final String name;
  final String deviceName;
  final String deviceIp;
  final int createdAt; // epoch ms

  const Session({
    required this.id,
    required this.name,
    required this.deviceName,
    required this.deviceIp,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deviceName': deviceName,
        'deviceIp': deviceIp,
        'createdAt': createdAt,
      };

  static Session fromJson(Map<String, dynamic> j) => Session(
        id: j['id'] as String,
        name: j['name'] as String,
        deviceName: j['deviceName'] as String,
        deviceIp: j['deviceIp'] as String,
        createdAt: (j['createdAt'] as num).toInt(),
      );
}

class SessionStore {
  static const String _kKey = 'iskomate_sessions';

  SessionStore._internal() {
    sessions = ValueNotifier<List<Session>>([]);
    _loadFromPrefs();
  }
  static final SessionStore _instance = SessionStore._internal();
  factory SessionStore() => _instance;

  late final ValueNotifier<List<Session>> sessions;

  // load persisted sessions into the notifier
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kKey) ?? <String>[];
    final loaded = list.map((s) {
      try {
        final Map<String, dynamic> j = json.decode(s) as Map<String, dynamic>;
        return Session.fromJson(j);
      } catch (_) {
        return null;
      }
    }).whereType<Session>().toList();
    loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    sessions.value = loaded;
  }

  // instance API

  Future<void> add(Session s) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kKey) ?? <String>[];
    list.insert(0, json.encode(s.toJson()));
    await prefs.setStringList(_kKey, list);
    sessions.value = [s, ...sessions.value];
  }

  Future<void> removeById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kKey) ?? <String>[];
    final remaining = list.where((s) {
      try {
        final Map<String, dynamic> j = json.decode(s) as Map<String, dynamic>;
        return j['id'] != id;
      } catch (_) {
        return true;
      }
    }).toList();
    await prefs.setStringList(_kKey, remaining);
    sessions.value = sessions.value.where((s) => s.id != id).toList();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= sessions.value.length) return;
    final id = sessions.value[index].id;
    await removeById(id);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    sessions.value = [];
  }

  // static convenience wrappers for existing code that used static methods

  static Future<List<Session>> loadSessions() => _instance._getAll();

  Future<List<Session>> _getAll() async {
    await _loadFromPrefs();
    return sessions.value;
  }

  static Future<void> addSession(Session session) => _instance.add(session);

  static Future<void> deleteSession(String id) => _instance.removeById(id);

  static Future<void> clearSessions() => _instance.clearAll();
}