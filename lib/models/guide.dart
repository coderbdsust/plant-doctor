/// Data model for the parsed rooftop-garden guide.
library;

enum BlockType {
  paragraph,
  bullets,
  numbered,
  table,
  quote,
  divider,
}

/// A single list entry, possibly with nested children.
class GuideListItem {
  GuideListItem({
    required this.text,
    this.order,
    List<GuideListItem>? children,
  }) : children = children ?? <GuideListItem>[];

  final String text;

  /// Original marker of an ordered-list entry (null for bullet lists).
  final String? order;

  final List<GuideListItem> children;

  /// Plain-text flattening used for the search index.
  String get plainText => children.isEmpty
      ? text
      : '$text ${children.map((e) => e.plainText).join(' ')}';
}

class GuideBlock {
  GuideBlock({
    required this.type,
    this.text = '',
    this.items = const <GuideListItem>[],
    this.headers = const <String>[],
    this.rows = const <List<String>>[],
  });

  final BlockType type;
  final String text;
  final List<GuideListItem> items;
  final List<String> headers;
  final List<List<String>> rows;

  String get plainText {
    switch (type) {
      case BlockType.paragraph:
      case BlockType.quote:
        return text;
      case BlockType.bullets:
      case BlockType.numbered:
        return items.map((e) => e.plainText).join(' ');
      case BlockType.table:
        return <String>[
          ...headers,
          ...rows.expand((r) => r),
        ].join(' ');
      case BlockType.divider:
        return '';
    }
  }
}

/// A "step" inside a chapter. Each step is rendered on its own screen in the
/// step-by-step reader.
class GuideStep {
  GuideStep({
    required this.chapterIndex,
    required this.stepIndex,
    required this.title,
    required this.blocks,
    this.group = '',
  });

  final int chapterIndex;
  final int stepIndex;
  final String title;

  /// The section this step was derived from (e.g. "ব্যবহার পদ্ধতি").
  final String group;

  final List<GuideBlock> blocks;

  String get plainText =>
      '$title ${blocks.map((b) => b.plainText).join(' ')}'.trim();
}

class GuideChapter {
  GuideChapter({
    required this.index,
    required this.number,
    required this.title,
    required this.steps,
    required this.searchTerms,
  });

  final int index;
  final String number;
  final String title;
  final List<GuideStep> steps;

  /// Short keywords surfaced on the chapter card.
  final List<String> searchTerms;

  String get plainText =>
      '$title ${steps.map((s) => s.plainText).join(' ')}'.trim();
}

class GuideDocument {
  GuideDocument({required this.chapters});

  final List<GuideChapter> chapters;

  int get stepCount => chapters.fold(0, (sum, c) => sum + c.steps.length);

  /// Flat list of every step with its chapter attached, used by the reader.
  List<GuideStep> get allSteps {
    final List<GuideStep> list = <GuideStep>[];
    for (final chapter in chapters) {
      list.addAll(chapter.steps);
    }
    return list;
  }
}
