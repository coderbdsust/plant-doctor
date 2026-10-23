import '../models/guide.dart';

/// A list entry found on a raw markdown line.
class _ListLine {
  _ListLine({
    required this.indent,
    required this.ordered,
    required this.order,
    required this.text,
  });

  final int indent;
  final bool ordered;
  final String order;
  final String text;
}

class _StackEntry {
  _StackEntry(this.indent, this.item);
  final int indent;
  final GuideListItem item;
}

/// Parses the rooftop-garden guide markdown into a structured
/// [GuideDocument] of chapters -> steps -> blocks.
class GuideParser {
  /// Minimum number of list entries before a section is split into
  /// individual steps.
  static const int _minItemsToSplit = 4;

  /// Minimum average entry length for a list without bold labels to be
  /// split into individual steps.
  static const int _minAverageLengthToSplit = 60;

  /// Title used for the opening text of a chapter.
  static const String _chapterIntroTitle = 'সম্পূর্ণ বিবরণ';

  GuideDocument parse(String markdown) {
    final lines = markdown.split('\n');

    final List<_RawChapter> rawChapters = <_RawChapter>[];
    _RawChapter? currentChapter;
    _RawStep? currentStep;

    for (final String line in lines) {
      final String trimmed = line.trim();

      // Horizontal rule -> ignore (used as section separator in the source).
      if (trimmed == '---' || trimmed == '***' || trimmed == '___') {
        continue;
      }

      // Chapter heading: "## ১. Title"
      if (line.startsWith('## ')) {
        currentStep = null;
        final String body = line.substring(3).trim();
        final _TitleParts parts = _splitTitle(body);
        currentChapter = _RawChapter(number: parts.number, title: parts.title);
        rawChapters.add(currentChapter);
        continue;
      }

      // Step heading: "### Something:"
      if (line.startsWith('### ')) {
        final String body = line.substring(4).trim();
        currentStep = _RawStep(title: _cleanTitle(body));
        currentChapter?.steps.add(currentStep);
        continue;
      }

      if (trimmed.isEmpty) {
        continue;
      }

      // Content directly under a chapter (no ### step) -> implicit step.
      if (currentStep == null) {
        if (currentChapter == null) continue;
        currentStep = _RawStep(title: '');
        currentChapter.steps.add(currentStep);
      }

      currentStep.lines.add(line);
    }

    final chapters = <GuideChapter>[];
    for (int c = 0; c < rawChapters.length; c++) {
      final _RawChapter raw = rawChapters[c];
      final List<GuideStep> steps = <GuideStep>[];
      for (final _RawStep rawStep in raw.steps) {
        final List<GuideBlock> blocks = _parseBlocks(rawStep.lines);
        final bool isChapterLevel = rawStep.title.isEmpty;
        final String group = isChapterLevel ? raw.title : rawStep.title;
        final List<GuideStep> produced = _splitIntoSteps(
          group: group,
          isChapterLevel: isChapterLevel,
          blocks: blocks,
        );
        for (final GuideStep step in produced) {
          steps.add(GuideStep(
            chapterIndex: c,
            stepIndex: steps.length,
            title: step.title,
            group: step.group,
            blocks: step.blocks,
          ));
        }
      }
      chapters.add(GuideChapter(
        index: c,
        number: raw.number,
        title: raw.title,
        steps: steps,
        searchTerms: _deriveSearchTerms(raw),
      ));
    }

    return GuideDocument(chapters: chapters);
  }

  /// Turns the raw lines of a step into renderable blocks.
  List<GuideBlock> _parseBlocks(List<String> lines) {
    final blocks = <GuideBlock>[];
    final buffer = <String>[];
    List<List<String>>? tableRows;
    List<String>? tableHeader;
    List<_ListLine>? listLines;

    void flushParagraph() {
      if (buffer.isEmpty) return;
      final String text = buffer.join(' ').trim();
      buffer.clear();
      if (text.isEmpty) return;
      blocks.add(GuideBlock(type: BlockType.paragraph, text: text));
    }

    void flushTable() {
      if (tableRows == null || tableRows!.isEmpty) {
        tableRows = null;
        tableHeader = null;
        return;
      }
      blocks.add(GuideBlock(
        type: BlockType.table,
        headers: tableHeader ?? const <String>[],
        rows: tableRows!,
      ));
      tableRows = null;
      tableHeader = null;
    }

    void flushList() {
      if (listLines == null || listLines!.isEmpty) {
        listLines = null;
        return;
      }
      blocks.addAll(_buildListBlocks(listLines!));
      listLines = null;
    }

    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      final int indent = rawLine.length - rawLine.trimLeft().length;

      // Table row.
      if (line.startsWith('|')) {
        flushParagraph();
        flushList();
        final List<String> cells = line
            .replaceAll(RegExp(r'^\|'), '')
            .replaceAll(RegExp(r'\|$'), '')
            .split('|')
            .map((c) => c.trim())
            .toList();
        // Skip the markdown alignment separator row.
        if (cells.every((c) => c.isEmpty || RegExp(r'^:?-{2,}:?$').hasMatch(c))) {
          continue;
        }
        if (tableHeader == null && tableRows == null && _looksLikeHeader(cells)) {
          tableHeader = cells;
        } else {
          tableRows ??= <List<String>>[];
          tableRows!.add(cells);
        }
        continue;
      }
      flushTable();

      // Blockquote / callout.
      if (line.startsWith('>')) {
        flushParagraph();
        flushList();
        final String quote = line.replaceFirst(RegExp(r'^>\s?'), '').trim();
        if (quote.isEmpty) continue;
        if (quote.startsWith('* ')) {
          // Bullet inside a quote -> render as its own quote paragraph.
          blocks.add(GuideBlock(
            type: BlockType.quote,
            text: quote.substring(2).trim(),
          ));
        } else {
          blocks.add(GuideBlock(type: BlockType.quote, text: quote));
        }
        continue;
      }

      // Bullet list.
      final RegExp bulletRe = RegExp(r'^([*+-])\s+(.*)$');
      final Match? bullet = bulletRe.firstMatch(line);
      if (bullet != null) {
        flushParagraph();
        flushTable();
        (listLines ??= <_ListLine>[]).add(_ListLine(
          indent: indent,
          ordered: false,
          order: '',
          text: bullet.group(2)!.trim(),
        ));
        continue;
      }

      // Numbered list (ASCII or Bengali digits).
      final RegExp numRe = RegExp(r'^([০-৯0-9]+)[.)]\s+(.*)$');
      final Match? numbered = numRe.firstMatch(line);
      if (numbered != null) {
        flushParagraph();
        flushTable();
        (listLines ??= <_ListLine>[]).add(_ListLine(
          indent: indent,
          ordered: true,
          order: numbered.group(1)!,
          text: numbered.group(2)!.trim(),
        ));
        continue;
      }

      // Regular paragraph text.
      flushList();
      buffer.add(line);
    }

    flushList();
    flushTable();
    flushParagraph();
    return blocks;
  }

  /// Converts raw list lines into one or more list blocks, honouring
  /// indentation so that nested bullets become children of their parent.
  List<GuideBlock> _buildListBlocks(List<_ListLine> lines) {
    final int minIndent = lines
        .map((l) => l.indent)
        .reduce((a, b) => a < b ? a : b);

    // Split into runs of the same root marker type.
    final List<List<_ListLine>> runs = <List<_ListLine>>[];
    int start = 0;
    bool? runOrdered;
    for (int i = 0; i < lines.length; i++) {
      final _ListLine line = lines[i];
      if (line.indent != minIndent) continue;
      if (runOrdered == null) {
        runOrdered = line.ordered;
        continue;
      }
      if (line.ordered != runOrdered) {
        runs.add(lines.sublist(start, i));
        start = i;
        runOrdered = line.ordered;
      }
    }
    runs.add(lines.sublist(start));

    return <GuideBlock>[
      for (final List<_ListLine> run in runs) _buildListBlock(run, minIndent),
    ];
  }

  GuideBlock _buildListBlock(List<_ListLine> lines, int minIndent) {
    final List<GuideListItem> roots = <GuideListItem>[];
    final List<_StackEntry> stack = <_StackEntry>[];

    for (final _ListLine line in lines) {
      while (stack.isNotEmpty && stack.last.indent >= line.indent) {
        stack.removeLast();
      }
      final GuideListItem item = GuideListItem(
        text: line.text,
        order: line.ordered ? line.order : null,
      );
      if (stack.isEmpty) {
        roots.add(item);
      } else {
        stack.last.item.children.add(item);
      }
      stack.add(_StackEntry(line.indent, item));
    }

    return GuideBlock(
      type: lines.first.ordered ? BlockType.numbered : BlockType.bullets,
      items: roots,
    );
  }

  /// Splits a section into steps. Long lists become one step per entry, which
  /// keeps the reader granular and truly "step by step".
  List<GuideStep> _splitIntoSteps({
    required String group,
    required bool isChapterLevel,
    required List<GuideBlock> blocks,
  }) {
    int listIndex = -1;
    for (int i = 0; i < blocks.length; i++) {
      final GuideBlock block = blocks[i];
      if (block.type != BlockType.bullets && block.type != BlockType.numbered) {
        continue;
      }
      if (block.items.length < _minItemsToSplit) continue;
      final bool allLabelled =
          block.items.every((item) => _boldLead(item.text) != null);
      final int totalLength = block.items
          .fold<int>(0, (sum, item) => sum + item.text.length);
      final int average = totalLength ~/ block.items.length;
      if (!allLabelled && average < _minAverageLengthToSplit) continue;
      listIndex = i;
      break;
    }

    if (listIndex == -1) {
      final String title = _titleForBlock(blocks) ??
          (isChapterLevel ? _chapterIntroTitle : group);
      return <GuideStep>[
        GuideStep(
          chapterIndex: 0,
          stepIndex: 0,
          title: title.isEmpty ? 'বিস্তারিত' : title,
          group: group,
          blocks: blocks,
        ),
      ];
    }

    final steps = <GuideStep>[];

    // Content before the list becomes its own introductory step.
    if (listIndex > 0) {
      final List<GuideBlock> leading = blocks.sublist(0, listIndex);
      steps.add(GuideStep(
        chapterIndex: 0,
        stepIndex: steps.length,
        title: _titleForBlock(leading) ??
            (isChapterLevel ? _chapterIntroTitle : 'পরিচিতি'),
        group: group,
        blocks: leading,
      ));
    }

    final GuideBlock listBlock = blocks[listIndex];
    for (final GuideListItem item in listBlock.items) {
      final _Lead? lead = _boldLead(item.text);
      final List<GuideBlock> itemBlocks = <GuideBlock>[];
      String title;
      String body;
      if (lead != null) {
        title = lead.label;
        body = lead.rest;
      } else {
        final _Auto auto = _autoTitle(item.text);
        title = auto.title;
        body = auto.rest;
      }
      if (body.isNotEmpty) {
        itemBlocks.add(GuideBlock(type: BlockType.paragraph, text: body));
      }
      if (item.children.isNotEmpty) {
        itemBlocks.add(GuideBlock(
          type: BlockType.bullets,
          items: item.children,
        ));
      }
      steps.add(GuideStep(
        chapterIndex: 0,
        stepIndex: steps.length,
        title: title,
        group: group,
        blocks: itemBlocks,
      ));
    }

    // Anything after the list becomes a closing step.
    if (listIndex + 1 < blocks.length) {
      final List<GuideBlock> trailing = blocks.sublist(listIndex + 1);
      steps.add(GuideStep(
        chapterIndex: 0,
        stepIndex: steps.length,
        title: _titleForBlock(trailing) ?? 'আরও তথ্য',
        group: group,
        blocks: trailing,
      ));
    }

    return steps;
  }

  /// Derives a step title from the first block of a section.
  String? _titleForBlock(List<GuideBlock> blocks) {
    if (blocks.isEmpty) return null;
    final GuideBlock block = blocks.first;
    if (block.type == BlockType.paragraph || block.type == BlockType.quote) {
      return _boldLead(block.text)?.label;
    }
    if (block.type == BlockType.table) return 'সারণী';
    return null;
  }

  /// Builds a readable title from a plain list entry plus the remaining text.
  /// The returned `rest` always contains the text that was not used as the
  /// title, so no content is ever lost.
  _Auto _autoTitle(String text) {
    final String t = text.trim();
    final int stop = t.indexOf('।');
    if (stop >= 12 && stop + 1 <= 110) {
      return _Auto(
        title: t.substring(0, stop + 1).trim(),
        rest: t.substring(stop + 1).trim(),
      );
    }
    if (t.length <= 110) return _Auto(title: t, rest: '');
    // Very long entry without a usable sentence break: cut at a word
    // boundary and keep the remainder as the body.
    int cut = t.lastIndexOf(' ', 72);
    if (cut < 24) cut = 72;
    return _Auto(
      title: '${t.substring(0, cut).trimRight()}…',
      rest: t.substring(cut).trim(),
    );
  }

  /// Extracts a leading bold label such as `**নিম তেল:**` from a list item.
  _Lead? _boldLead(String text) {
    final RegExp re = RegExp(r'^\*\*([^*\n]{1,60}?)\*\*\s*[:।]?\s*');
    final Match? m = re.firstMatch(text);
    if (m == null) return null;
    String label = m.group(1)!.trim();
    while (label.endsWith(':') || label.endsWith('।')) {
      label = label.substring(0, label.length - 1).trim();
    }
    if (label.isEmpty) return null;
    return _Lead(label: label, rest: text.substring(m.end).trim());
  }

  bool _looksLikeHeader(List<String> cells) {
    // The guide only has one table (plant selection). Treat the first row
    // that contains a short label column as the header.
    if (cells.length < 2) return false;
    return cells.first.length <= 24 && !cells.first.contains(',');
  }

  _TitleParts _splitTitle(String body) {
    final RegExp re = RegExp(r'^([০-৯0-9]+)[.)]\s*(.*)$');
    final Match? m = re.firstMatch(body);
    if (m != null) {
      return _TitleParts(
        number: _toBengaliDigits(m.group(1)!),
        title: m.group(2)!.trim(),
      );
    }
    return _TitleParts(number: '', title: _cleanTitle(body));
  }

  String _cleanTitle(String title) {
    String t = title.trim();
    // Remove trailing colon used in the source headings.
    while (t.endsWith(':')) {
      t = t.substring(0, t.length - 1).trim();
    }
    return t;
  }

  List<String> _deriveSearchTerms(_RawChapter chapter) {
    final terms = <String>{};
    for (final step in chapter.steps) {
      final String body = step.lines.join(' ');
      for (final m in RegExp(r'\*\*([^*]{2,40})\*\*').allMatches(body)) {
        terms.add(m.group(1)!.trim());
      }
    }
    final list = terms.toList()..sort();
    return list.take(8).toList();
  }
}

class _Lead {
  _Lead({required this.label, required this.rest});
  final String label;
  final String rest;
}

class _Auto {
  _Auto({required this.title, required this.rest});
  final String title;
  final String rest;
}

class _TitleParts {
  _TitleParts({required this.number, required this.title});
  final String number;
  final String title;
}

class _RawChapter {
  _RawChapter({required this.number, required this.title});
  final String number;
  final String title;
  final List<_RawStep> steps = <_RawStep>[];
}

class _RawStep {
  _RawStep({required this.title});
  final String title;
  final List<String> lines = <String>[];
}

const Map<String, String> _bengaliDigits = <String, String>{
  '0': '০',
  '1': '১',
  '2': '২',
  '3': '৩',
  '4': '৪',
  '5': '৫',
  '6': '৬',
  '7': '৭',
  '8': '৮',
  '9': '৯',
};

String _toBengaliDigits(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_bengaliDigits[ch] ?? ch);
  }
  return buf.toString();
}
