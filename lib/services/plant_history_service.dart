import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

/// One saved diagnosis result from the গাছের ডাক্তার screen.
class PlantHistoryEntry {
  const PlantHistoryEntry({
    required this.id,
    required this.createdAt,
    required this.resultText,
    required this.thumbnailBase64,
    this.model = '',
  });

  factory PlantHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PlantHistoryEntry(
      id: json['id'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      resultText: json['resultText'] as String? ?? '',
      thumbnailBase64: json['thumb'] as String? ?? '',
      model: json['model'] as String? ?? '',
    );
  }

  final String id;
  final DateTime createdAt;
  final String resultText;
  final String thumbnailBase64;
  final String model;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'resultText': resultText,
        'thumb': thumbnailBase64,
        'model': model,
      };
}

/// Background-isolate worker: downscales the picked photo to a tiny JPEG
/// thumbnail so history entries stay light (a few KB, not MBs).
Uint8List _makeThumbnail(Uint8List bytes) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final img.Image resized = img.copyResize(
    decoded,
    width: decoded.width > decoded.height ? 480 : 320,
  );
  return img.encodeJpg(resized, quality: 55);
}

/// Persists গাছের ডাক্তার diagnosis results in shared_preferences,
/// newest first, capped at [maxEntries].
class PlantHistoryService {
  static const String _key = 'plant_history_entries';
  static const int maxEntries = 20;

  const PlantHistoryService();

  Future<List<PlantHistoryEntry>> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? <String>[];
    return raw
        .map((String s) {
          try {
            return PlantHistoryEntry.fromJson(
              jsonDecode(s) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<PlantHistoryEntry>()
        .toList();
  }

  /// Saves a new result with a compact thumbnail derived from the photo
  /// the user picked. Returns the saved entry, or null if saving failed.
  Future<PlantHistoryEntry?> save({
    required Uint8List photoBytes,
    required String resultText,
    required String model,
  }) async {
    try {
      final Uint8List thumb = kIsWeb
          ? _makeThumbnail(photoBytes)
          : await compute(_makeThumbnail, photoBytes);
      final PlantHistoryEntry entry = PlantHistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        resultText: resultText,
        thumbnailBase64: base64Encode(thumb),
        model: model,
      );

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String> raw = prefs.getStringList(_key) ?? <String>[];
      raw.insert(0, jsonEncode(entry.toJson()));
      if (raw.length > maxEntries) {
        raw.removeRange(maxEntries, raw.length);
      }
      await prefs.setStringList(_key, raw);
      return entry;
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? <String>[];
    final List<PlantHistoryEntry> entries = raw.map(_decode).toList();
    entries.removeWhere((PlantHistoryEntry e) => e.id == id);
    await prefs.setStringList(_key, entries.map(_encodeRaw).toList());
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static PlantHistoryEntry _decode(String s) {
    try {
      return PlantHistoryEntry.fromJson(
        jsonDecode(s) as Map<String, dynamic>,
      );
    } catch (_) {
      return PlantHistoryEntry(
        id: '',
        createdAt: DateTime.now(),
        resultText: '',
        thumbnailBase64: '',
      );
    }
  }

  static String _encodeRaw(PlantHistoryEntry e) => jsonEncode(e.toJson());
}

/// Bengali date-time label used in history cards, e.g. "২৪/৯, সকাল ১০:৩০" —
/// kept simple: "২০২༥-০৯-২৪ ১০:৩০".
String bengaliTimestamp(DateTime time) {
  const List<String> bengaliDigits = <String>[
    '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯',
  ];

  String toB(String value) {
    final StringBuffer out = StringBuffer();
    for (final int code in value.codeUnits) {
      if (code >= 0x30 && code <= 0x39) {
        out.write(bengaliDigits[code - 0x30]);
      } else {
        out.writeCharCode(code);
      }
    }
    return out.toString();
  }

  String two(int n) => n.toString().padLeft(2, '0');

  return toB('${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}');
}
