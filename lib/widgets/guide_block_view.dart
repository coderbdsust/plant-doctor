import 'package:flutter/material.dart';

import '../models/guide.dart';
import 'inline_text.dart';

/// Renders a list of [GuideBlock]s.
class GuideBlockView extends StatelessWidget {
  const GuideBlockView({
    super.key,
    required this.blocks,
    required this.fontScale,
  });

  final List<GuideBlock> blocks;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == blocks.length - 1 ? 0 : 14,
            ),
            child: _buildBlock(context, blocks[i], scheme),
          ),
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    GuideBlock block,
    ColorScheme scheme,
  ) {
    switch (block.type) {
      case BlockType.paragraph:
        return InlineText(
          block.text,
          style: TextStyle(
            fontSize: 15.5 * fontScale,
            height: 1.75,
            color: scheme.onSurface,
          ),
        );

      case BlockType.quote:
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: scheme.tertiary, width: 4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.info_outline, size: 18, color: scheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: InlineText(
                  block.text,
                  style: TextStyle(
                    fontSize: 14.5 * fontScale,
                    height: 1.7,
                    color: scheme.onSurface,
                    fontStyle: FontStyle.italic,
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
        );

      case BlockType.numbered:
        return _ListView(
          items: block.items,
          ordered: true,
          fontScale: fontScale,
          scheme: scheme,
        );

      case BlockType.table:
        return _TableView(block: block, fontScale: fontScale);

      case BlockType.divider:
        return Divider(color: scheme.outlineVariant);
    }
  }
}

class _ListView extends StatelessWidget {
  const _ListView({
    required this.items,
    required this.ordered,
    required this.fontScale,
    required this.scheme,
  });

  final List<GuideListItem> items;
  final bool ordered;
  final double fontScale;
  final ColorScheme scheme;

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
  });

  final GuideListItem item;
  final bool ordered;
  final int index;
  final int depth;
  final double fontScale;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final Color marker = depth == 0
        ? scheme.primary
        : scheme.primary.withValues(alpha: 0.65);

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
                      '${item.order ?? '${index + 1}'}.',
                      style: TextStyle(
                        fontSize: 14.5 * fontScale,
                        height: 1.7,
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
                  fontSize: 15 * fontScale,
                  height: 1.72,
                  color: scheme.onSurface,
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
            ),
          ),
      ],
    );
  }
}

class _TableView extends StatelessWidget {
  const _TableView({required this.block, required this.fontScale});

  final GuideBlock block;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          if (block.headers.isNotEmpty)
            Container(
              color: scheme.primary.withValues(alpha: 0.10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < block.headers.length; i++)
                    Expanded(
                      flex: i == 0 ? 1 : 3,
                      child: InlineText(
                        block.headers[i],
                        style: TextStyle(
                          fontSize: 13.5 * fontScale,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
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
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
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
                          fontSize: 13.5 * fontScale,
                          height: 1.6,
                          color: scheme.onSurface,
                          fontWeight:
                              c == 0 ? FontWeight.w600 : FontWeight.w400,
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
