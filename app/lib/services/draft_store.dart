import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/session.dart';

abstract class DraftStore {
  Future<List<StudioSession>> read();
  Future<void> write(List<StudioSession> sessions);
}

class PreferenceDraftStore implements DraftStore {
  final prefs = SharedPreferencesAsync();
  static const key = 'matsuri.sessions.v1';
  @override
  Future<List<StudioSession>> read() async {
    final raw = await prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((item) =>
            StudioSession.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<void> write(List<StudioSession> sessions) => prefs.setString(
      key, jsonEncode(sessions.map((s) => s.toJson()).toList()));
}
