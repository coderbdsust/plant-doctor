import 'dart:io';

import 'package:plant_doctor/data/guide_parser.dart';

Future<void> main() async {
  final String raw = await File('assets/guideline.md').readAsString();
  final doc = GuideParser().parse(raw);

  print('Chapters: ${doc.chapters.length}');
  print('Total steps: ${doc.stepCount}');
  print('');
  for (final c in doc.chapters) {
    print('== অধ্যায় ${c.number}: ${c.title} (${c.steps.length} ধাপ)');
    for (var i = 0; i < c.steps.length; i++) {
      final s = c.steps[i];
      final types = s.blocks.map((b) => b.type.name).toList();
      print('   ${i + 1}. ${s.title}  [$types]');
      for (final b in s.blocks) {
        if (b.type.name == 'table') {
          print('      table headers=${b.headers} rows=${b.rows.length} first=${b.rows.isEmpty ? "-" : b.rows.first}');
        }
        if (b.type.name == 'bullets' || b.type.name == 'numbered') {
          print('      ${b.type.name} items=${b.items.length}');
          for (final it in b.items) {
            print('        - ${it.text.length > 70 ? "${it.text.substring(0, 70)}…" : it.text} (children: ${it.children.length})');
            for (final ch in it.children) {
              print('            * ${ch.text.length > 70 ? "${ch.text.substring(0, 70)}…" : ch.text}');
            }
          }
        }
        if (b.type.name == 'quote') {
          print('      quote: ${b.text.length > 70 ? "${b.text.substring(0, 70)}…" : b.text}');
        }
      }
    }
  }
}
