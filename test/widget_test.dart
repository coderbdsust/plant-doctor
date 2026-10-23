import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plant_doctor/data/guide_parser.dart';
import 'package:plant_doctor/widgets/inline_text.dart';

const String _sample = '''
## ১. অনুখাদ্য ব্যবহার

কোকোপিট মাটির সাথে মেশালে ভালো হয়।

### উপকারিতা:
* গাছের বৃদ্ধি বাড়ে।
* পাতা সবুজ থাকে।

### ব্যবহার পদ্ধতি:
* **হাফ ড্রাম:** ৪ মুঠ ২৫ দিন পর পর।

> **বিঃদ্রঃ** মাটিতে ঢেকে দিতে হবে।
''';

void main() {
  group('GuideParser', () {
    test('parses chapters, steps and blocks', () {
      final document = GuideParser().parse(_sample);

      expect(document.chapters.length, 1);
      final chapter = document.chapters.first;
      expect(chapter.number, '১');
      expect(chapter.title, 'অনুখাদ্য ব্যবহার');
      expect(chapter.steps.length, 3);

      expect(chapter.steps[0].title, 'সম্পূর্ণ বিবরণ');
      expect(chapter.steps[1].title, 'উপকারিতা');
      expect(chapter.steps[2].title, 'ব্যবহার পদ্ধতি');
    });

    test('extracts bullet lists and quotes', () {
      final document = GuideParser().parse(_sample);
      final steps = document.chapters.first.steps;

      final bullets = steps[1].blocks.firstWhere(
        (block) => block.type.name == 'bullets',
      );
      expect(bullets.items.length, 2);
      expect(bullets.items.first.text, contains('বৃদ্ধি'));

      final quote = steps[2].blocks.firstWhere(
        (block) => block.type.name == 'quote',
      );
      expect(quote.text, contains('বিঃদ্রঃ'));
    });
  });

  testWidgets('InlineText renders bold markup', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InlineText('সাধারণ **গাঢ়** লেখা'),
        ),
      ),
    );

    expect(find.textContaining('গাঢ়'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
