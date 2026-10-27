import 'package:flutter/material.dart';

import '../models/guide.dart';
import 'inline_text.dart';

/// Renders a list of [GuideBlock]s.
///
/// Light theme strictly follows the Stitch "Disease & Remedies" directory
/// design: pine body copy (#20402E), emerald step numbers (#047857),
/// mint info boxes (#F5FBF7 / #D6EBD9) and hairline titles (#E2EFE7).
class GuideBlockView extends StatelessWidget {
  const GuideBlockView({
    super.key,
    required this.blocks,
    required this.fontScale,
  });

  final List<GuideBlock> blocks;
  final double fontScale;

  // Exact hexes from the light directory design.
  static const Color _body = Color(0xFF20402E);
  static const Color _marker = Color(0xFF047857);
  static const Color _hairline = Color(0xFFE2EFE7);
  static const Color _infoBg = Color(0xFFF5FBF7);
  static const Color _infoBorder = Color(0xFFD6EBD9);

  static const List<String> _bengaliDigits = <String>[
    '০',
    '১',
    '২',
    '৩',
    '৪',
    '৫',
    '৬',
    '৭',
    '৮',
    '৯',
  ];

  /// Western digits → Bengali digits ("12" → "১২").
  static String toBengali(int value) {
    return value
        .toString()
        .split('')
        .map((String d) => _bengaliDigits[int.parse(d)])
        .join();
  }

  /// Replaces every western digit inside [text] with its Bengali form.
  static String digitize(String text) {
    return text
        .split('')
        .map(
          (String d) => d.codeUnitAt(0) >= 0x30 && d.codeUnitAt(0) <= 0x39
              ? _bengaliDigits[d.codeUnitAt(0) - 0x30]
              : d,
        )
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == blocks.length - 1 ? 0 : 14),
            child: _buildBlock(context, blocks[i], scheme, isLight),
          ),
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    GuideBlock block,
    ColorScheme scheme,
    bool isLight,
  ) {
    switch (block.type) {
      case BlockType.paragraph:
        return InlineText(
          block.text,
          style: TextStyle(
            fontSize: 15 * fontScale,
            height: 1.75,
            color: isLight ? _body : scheme.onSurface,
          ),
        );

      case BlockType.quote:
        // Design: mint info panel with an icon lead — "লক্ষণ ও আক্রান্ত স্থান".
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isLight
                ? _infoBg
                : scheme.secondaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isLight ? _infoBorder : scheme.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.tips_and_updates_outlined,
                size: 16,
                color: isLight ? _marker : scheme.tertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InlineText(
                  block.text,
                  style: TextStyle(
                    fontSize: 13.5 * fontScale,
                    height: 1.68,
                    color: isLight ? _body : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );

      case BlockType.bullets:
        return _ListView(
          items: block.items,
          ordered: false,
          fontScale: fontScale,
          scheme: scheme,
          isLight: isLight,
        );

      case BlockType.numbered:
        return _ListView(
          items: block.items,
          ordered: true,
          fontScale: fontScale,
          scheme: scheme,
          isLight: isLight,
        );

      case BlockType.table:
        return _TableView(block: block, fontScale: fontScale, isLight: isLight);

      case BlockType.divider:
        return Divider(
          color: isLight
              ? _hairline
              : scheme.outlineVariant.withValues(alpha: 0.5),
          thickness: 1,
        );
    }
  }
}

class _ListView extends StatelessWidget {
  const _ListView({
    required this.items,
    required this.ordered,
    required this.fontScale,
    required this.scheme,
    required this.isLight,
  });

  final List<GuideListItem> items;
  final bool ordered;
  final double fontScale;
  final ColorScheme scheme;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
            child: _ListEntry(
              item: items[i],
              ordered: ordered,
              index: i,
              depth: 0,
              fontScale: fontScale,
              scheme: scheme,
              isLight: isLight,
            ),
          ),
      ],
    );
  }
}

/// One list entry together with its nested children.
class _ListEntry extends StatelessWidget {
  const _ListEntry({
    required this.item,
    required this.ordered,
    required this.index,
    required this.depth,
    required this.fontScale,
    required this.scheme,
    required this.isLight,
  });

  final GuideListItem item;
  final bool ordered;
  final int index;
  final int depth;
  final double fontScale;
  final ColorScheme scheme;
  final bool isLight;

  // Step boxes use bold emerald "১." markers, like the design's
  // "ধাপে ধাপে প্রয়োগবিধি" rows.
  static const Color _marker = Color(0xFF047857);
  static const Color _body = Color(0xFF20402E);

  @override
  Widget build(BuildContext context) {
    final Color marker = isLight
        ? (depth == 0 ? _marker : _marker.withValues(alpha: 0.65))
        : (depth == 0
              ? scheme.primary
              : scheme.primary.withValues(alpha: 0.65));
    final Color textColor = isLight ? _body : scheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 26,
              child: ordered
                  ? Text(
                      item.order == null
                          ? '${GuideBlockView.toBengali(index + 1)}.'
                          : '${GuideBlockView.digitize(item.order!)}.',
                      style: TextStyle(
                        fontSize: 13.5 * fontScale,
                        height: 1.68,
                        fontWeight: FontWeight.w700,
                        color: marker,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: Container(
                        width: depth == 0 ? 6 : 5,
                        height: depth == 0 ? 6 : 5,
                        decoration: BoxDecoration(
                          color: marker,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: InlineText(
                item.text,
                style: TextStyle(
                  fontSize: 14.5 * fontScale,
                  height: 1.7,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        if (item.children.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: 12 + 8.0 * depth, top: 6),
            child: _ListView(
              items: item.children,
              ordered: ordered,
              fontScale: fontScale * 0.96,
              scheme: scheme,
              isLight: isLight,
            ),
          ),
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({
    required this.block,
    required this.fontScale,
    required this.isLight,
  });

  final GuideBlock block;
  final double fontScale;
  final bool isLight;

  // Spec-metric look: white card, sage border, mint header,
  // gray labels and bold pine values.
  static const Color _cardBorder = Color(0xFFD1E7DD);
  static const Color _headerBg = Color(0xFFF5FBF7);
  static const Color _headerText = Color(0xFF047857);
  static const Color _label = Color(0xFF5D806A);
  static const Color _value = Color(0xFF0F2E1E);
  static const Color _line = Color(0xFFD6EBD9);

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : scheme.surfaceContainerLow,
        border: Border.all(color: isLight ? _cardBorder : scheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          if (block.headers.isNotEmpty)
            Container(
              color: isLight
                  ? _headerBg
                  : scheme.primary.withValues(alpha: 0.10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < block.headers.length; i++)
                    Expanded(
                      flex: i == 0 ? 1 : 3,
                      child: InlineText(
                        block.headers[i],
                        style: TextStyle(
                          fontSize: 12.5 * fontScale,
                          fontWeight: FontWeight.w700,
                          color: isLight ? _headerText : scheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          for (int r = 0; r < block.rows.length; r++)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isLight
                        ? _line
                        : scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int c = 0; c < block.rows[r].length; c++)
                    Expanded(
                      flex: c == 0 ? 1 : 3,
                      child: InlineText(
                        block.rows[r][c],
                        style: TextStyle(
                          // First column acts as the spec label (gray, small),
                          // value columns are bold pine, like the design's
                          // "ওষুধের নাম / অনুপাত মাত্রা / প্রয়োগ রুটিন" grid.
                          fontSize: (c == 0 ? 11.5 : 12.5) * fontScale,
                          height: 1.6,
                          color: isLight
                              ? (c == 0 ? _label : _value)
                              : (c == 0
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface),
                          fontWeight: c == 0
                              ? FontWeight.w600
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
