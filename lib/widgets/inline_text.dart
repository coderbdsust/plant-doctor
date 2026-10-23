import 'package:flutter/material.dart';

/// Renders inline markdown-ish syntax (`**bold**`, `*italic*`, `` `code` ``)
/// as styled text spans.
class InlineText extends StatelessWidget {
  const InlineText(
    this.text, {
    super.key,
    this.style,
    this.baseColor,
  });

  final String text;
  final TextStyle? style;
  final Color? baseColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = style ?? DefaultTextStyle.of(context).style;
    final Color color = baseColor ?? base.color ?? Colors.black;

    return Text.rich(
      TextSpan(children: _parse(text, base, color)),
      style: base,
    );
  }

  static List<TextSpan> _parse(String input, TextStyle base, Color color) {
    final List<TextSpan> spans = <TextSpan>[];
    final RegExp token = RegExp(
      r'(\*\*[^*]+\*\*)|(\*[^*\n]+\*)|(`[^`]+`)',
    );

    int last = 0;
    for (final match in token.allMatches(input)) {
      if (match.start > last) {
        spans.add(TextSpan(text: input.substring(last, match.start)));
      }
      final String raw = match.group(0)!;
      if (raw.startsWith('**')) {
        spans.add(TextSpan(
          text: raw.substring(2, raw.length - 2),
          style: base.copyWith(fontWeight: FontWeight.w700, color: color),
        ));
      } else if (raw.startsWith('`')) {
        spans.add(TextSpan(
          text: raw.substring(1, raw.length - 1),
          style: base.copyWith(
            fontFamily: 'monospace',
            backgroundColor: color.withValues(alpha: 0.08),
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: raw.substring(1, raw.length - 1),
          style: base.copyWith(fontStyle: FontStyle.italic, color: color),
        ));
      }
      last = match.end;
    }
    if (last < input.length) {
      spans.add(TextSpan(text: input.substring(last)));
    }
    return spans;
  }
}
