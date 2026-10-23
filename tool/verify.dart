// Verifies that every source line of the guide survives parsing.
//
// Usage: dart run tool/verify.dart
import 'dart:io';

import 'package:plant_doctor/data/guide_parser.dart';
import 'package:plant_doctor/models/guide.dart';

Future<void> main() async {
  final raw = await File('assets/guideline.md').readAsString();
  final document = GuideParser().parse(raw);

  final List<String> parsed = <String>[];
  void collectItems(List<GuideListItem> items) {
    for (final item in items) {
      parsed.add(item.text);
      collectItems(item.children);
    }
  }

  void collectBlocks(List<GuideBlock> blocks) {
    for (final block in blocks) {
      switch (block.type) {
        case BlockType.paragraph:
        case BlockType.quote:
          parsed.add(block.text);
        case BlockType.bullets:
        case BlockType.numbered:
          collectItems(block.items);
        case BlockType.table:
          parsed.addAll(block.headers);
          for (final row in block.rows) {
            parsed.addAll(row);
          }
        case BlockType.divider:
          break;
      }
    }
  }

  for (final chapter in document.chapters) {
    parsed.add(chapter.title);
    for (final step in chapter.steps) {
      parsed.add(step.group);
      parsed.add(step.title);
      collectBlocks(step.blocks);
    }
  }

  final String haystack = _normalise(parsed.join(' \n '));

  int checked = 0;
  int lost = 0;
  for (final String line in raw.split('\n')) {
    final List<String> parts = _segments(line);
    if (parts.isEmpty) continue;
    checked++;
    final List<String> missing = <String>[];
    for (final String part in parts) {
      if (_contains(haystack, part)) continue;
      missing.add(part);
    }
    if (missing.isNotEmpty) {
      lost++;
      if (lost <= 20) {
        print('LOST: ${missing.join('  ||  ')}');
      }
    }
  }

  print('Checked $checked source lines, $lost not found verbatim.');
}

/// Splits a source line into the pieces that must survive parsing.
List<String> _segments(String line) {
  String t = line.trim();
  if (t.isEmpty) return const <String>[];
  if (RegExp(r'^:?-{2,}:?$').hasMatch(t)) return const <String>[];
  if (RegExp(r'^[-:| ]+$').hasMatch(t)) return const <String>[];
  t = t.replaceAll(RegExp(r'^#{1,6}\s*'), '');
  t = t.replaceAll(RegExp(r'^>\s?'), '');
  t = t.replaceAll(RegExp(r'^[*+-]\s+'), '');
  t = t.replaceAll(RegExp(r'^[০-৯0-9]+[.)]\s+'), '');
  t = t.replaceAll('|', ' ');
  t = t.trim();
  while (t.endsWith(':')) {
    t = t.substring(0, t.length - 1).trim();
  }
  if (t.isEmpty) return const <String>[];

  // A bold label is split off from the body, so check both halves.
  final RegExp bold = RegExp(r'\*\*([^*\n]+?)\*\*\s*');
  final Match? m = bold.firstMatch(t);
  if (m != null) {
    String label = m.group(1)!.trim();
    while (label.endsWith(':')) {
      label = label.substring(0, label.length - 1).trim();
    }
    final List<String> parts = <String>[label];
    final String rest = t.replaceFirst(bold, '').trim();
    if (rest.isNotEmpty) parts.add(rest);
    return parts;
  }
  return <String>[t];
}

String _normalise(String input) {
  return input.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// True when [needle] appears verbatim in [haystack], or when all of its
/// words appear in order (the parser may have split the text into a
/// title and a body).
bool _contains(String haystack, String needle) {
  final String n = _normalise(needle);
  if (n.isEmpty) return true;
  if (haystack.contains(n)) return true;
  final List<String> words = n.split(' ');
  int index = 0;
  final List<String> haystackWords = haystack
      .split(' ')
      .map((String w) => w.endsWith('…') ? w.substring(0, w.length - 1) : w)
      .toList();
  for (final String word in words) {
    bool found = false;
    while (index < haystackWords.length) {
      if (haystackWords[index] == word) {
        found = true;
        index++;
        break;
      }
      index++;
    }
    if (!found) return false;
  }
  return true;
}
