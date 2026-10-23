import 'dart:io';

import 'package:plant_doctor/data/guide_parser.dart';

Future<void> main() async {
  final raw = await File('assets/guideline.md').readAsString();
  final doc = GuideParser().parse(raw);
  print('Chapters: ${doc.chapters.length}  Steps: ${doc.stepCount}');
  for (final c in doc.chapters) {
    print('\nঅধ্যায় ${c.number} — ${c.title}  (${c.steps.length} ধাপ)');
    for (var i = 0; i < c.steps.length; i++) {
      final s = c.steps[i];
      print('  ${(i + 1).toString().padLeft(2)}. [${s.group.isEmpty ? '-' : s.group}] ${s.title}');
    }
  }
}
