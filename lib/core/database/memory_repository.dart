import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single unit of the user's knowledge bank: one chat turn, or one
/// directly-taught fact.
class MemoryEntry {
  final String id;
  final String role; // 'user' | 'assistant' | 'fact'
  final String content;
  final DateTime createdAt;

  const MemoryEntry({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    return MemoryEntry(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Format expected by QwenService / the Dashscope chat-completions
  /// contract: {"role": ..., "content": ...}.
  Map<String, dynamic> toApiMessage() => {'role': role, 'content': content};
}

/// Persists the user's growing knowledge bank to on-device storage.
///
/// This is deliberately local-only (no account, no server-side database):
/// on Flutter Web, `shared_preferences` is backed by the browser's
/// localStorage, so the conversation survives a page refresh / new tab in
/// the *same browser on the same device*. It is intentionally NOT synced
/// across devices or browsers - that would require a real backend + auth
/// (Firestore + Firebase Auth is the natural next step if/when that's
/// needed again; see README.md).
///
/// Every method fails soft: if local storage errors for any reason, methods
/// log and return an empty/no-op result rather than throwing, so a storage
/// hiccup degrades the app to "chat works, nothing is saved this session"
/// instead of crashing it.
class MemoryRepository {
  static const _storageKey = 'memory_agent_entries_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Generates a new unique entry ID. Timestamp + a small random suffix is
  /// enough uniqueness for a single-device, single-user local store.
  String newId() {
    final now = DateTime.now();
    final suffix = (now.microsecond % 10000).toString().padLeft(4, '0');
    return '${now.microsecondsSinceEpoch}-$suffix';
  }

  Future<List<MemoryEntry>> _readAll() async {
    final prefs = await _ensurePrefs();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => MemoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeAll(List<MemoryEntry> entries) async {
    final prefs = await _ensurePrefs();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  /// One-shot fetch of the most recent [limit] entries, oldest-first (the
  /// order a chat transcript / LLM context window expects).
  Future<List<MemoryEntry>> loadRecentHistory({int limit = 50}) async {
    try {
      final all = await _readAll();
      all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (all.length <= limit) return all;
      return all.sublist(all.length - limit);
    } catch (e) {
      debugPrint('MemoryRepository.loadRecentHistory failed: $e');
      return [];
    }
  }

  /// Appends several entries (used after a chat turn, to write the user's
  /// message and the assistant's reply together).
  Future<void> addEntries(List<MemoryEntry> entries) async {
    if (entries.isEmpty) return;
    try {
      final all = await _readAll();
      all.addAll(entries);
      await _writeAll(all);
    } catch (e) {
      debugPrint('MemoryRepository.addEntries failed: $e');
      // Intentionally swallowed: the caller already has the entry in its
      // in-memory state for this session; a failed write means it just
      // won't survive a refresh, which is a soft degradation, not a crash.
    }
  }

  /// Permanently deletes this device's entire knowledge bank ("forget
  /// everything").
  Future<void> clearHistory() async {
    try {
      final prefs = await _ensurePrefs();
      await prefs.remove(_storageKey);
    } catch (e) {
      debugPrint('MemoryRepository.clearHistory failed: $e');
    }
  }
}
