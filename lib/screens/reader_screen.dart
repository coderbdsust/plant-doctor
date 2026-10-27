import 'package:flutter/material.dart';

import '../models/guide.dart';
import '../state/app_controller.dart';
import '../widgets/guide_block_view.dart';
import '../widgets/inline_text.dart';

/// Step-by-step reader. Each step is a full page; swipe or use the buttons
/// at the bottom to move between steps.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.controller,
    required this.chapter,
    this.initialStep = 0,
  });

  final AppController controller;
  final GuideChapter chapter;
  final int initialStep;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialStep.clamp(0, widget.chapter.steps.length - 1);
    _pageController = PageController(initialPage: _current);
    widget.controller.saveReadingPosition(_globalIndex(_current));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _globalIndex(int localStep) {
    int global = 0;
    final chapters = widget.controller.chapters;
    for (int i = 0; i < localStep; i++) {
      if (i < widget.chapter.index) {
        global += chapters[i].steps.length;
      }
    }
    global += localStep;
    return global;
  }

  void _goTo(int step) {
    if (step < 0 || step >= widget.chapter.steps.length) return;
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<GuideStep> steps = widget.chapter.steps;
    final double fontScale = widget.controller.settings.fontScale;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.chapter.number.isEmpty
                  ? widget.chapter.title
                  : 'অধ্যায় ${widget.chapter.number}',
              style: theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 17),
            ),
            Text(
              widget.chapter.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'সব ধাপ',
            onPressed: () => _showStepSheet(context, steps, _current, _goTo),
            icon: const Icon(Icons.list_alt_rounded),
          ),
          IconButton(
            tooltip: 'টেক্সট সাইজ',
            onPressed: () => _showFontScaleSheet(context, widget.controller),
            icon: const Icon(Icons.text_fields_rounded),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _ProgressBar(current: _current, total: steps.length, onSelect: _goTo),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: steps.length,
              onPageChanged: (int index) {
                setState(() => _current = index);
                widget.controller.saveReadingPosition(_globalIndex(index));
              },
              itemBuilder: (BuildContext context, int index) {
                final GuideStep step = steps[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 26),
                  child: _StepCard(
                    header: _StepHeader(
                      stepNumber: index + 1,
                      total: steps.length,
                      title: step.title,
                      group: step.group == widget.chapter.title
                          ? ''
                          : step.group,
                    ),
                    fontScale: fontScale,
                    blocks: step.blocks,
                  ),
                );
              },
            ),
          ),
          _BottomNav(
            current: _current,
            total: steps.length,
            onPrevious: _current > 0 ? () => _goTo(_current - 1) : null,
            onNext: _current < steps.length - 1
                ? () => _goTo(_current + 1)
                : null,
            onMenu: () => _showStepSheet(context, steps, _current, _goTo),
          ),
        ],
      ),
    );
  }

  void _showStepSheet(
    BuildContext context,
    List<GuideStep> steps,
    int current,
    void Function(int) onSelect,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (BuildContext context, ScrollController scrollController) {
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              itemCount: steps.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'সব ধাপ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                final int stepIndex = index - 1;
                final GuideStep step = steps[stepIndex];
                final bool active = stepIndex == current;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: active
                        ? theme.colorScheme.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      onTap: () {
                        Navigator.of(context).pop();
                        onSelect(stepIndex);
                      },
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                        child: Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      title: InlineText(
                        step.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showFontScaleSheet(BuildContext context, AppController controller) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double value = controller.settings.fontScale;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'টেক্সট সাইজ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.text_fields, size: 16),
                      Expanded(
                        child: Slider(
                          value: value,
                          min: 0.85,
                          max: 1.4,
                          divisions: 11,
                          label: '${(value * 100).round()}%',
                          onChanged: (double v) {
                            setModalState(() {});
                            controller.setFontScale(v);
                          },
                        ),
                      ),
                      Text('${(value * 100).round()}%'),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.current,
    required this.total,
    required this.onSelect,
  });

  final int current;
  final int total;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double progress = total <= 1 ? 1 : (current + 1) / total;

    // Design's status row: gray label left, emerald count right.
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 5,
                  backgroundColor: theme.brightness == Brightness.light
                      ? const Color(0xFFDCFCE7)
                      : scheme.surfaceContainerHighest,
                  color: const Color(0xFF16A34A),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'ধাপ ${current + 1} / $total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.light
                      ? const Color(0xFF4A6B57)
                      : scheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${(progress * 100).round()}% সম্পন্ন',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.light
                      ? const Color(0xFF065F46)
                      : scheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White remedy-card wrapper around each step, matching the directory
/// design's `rounded-xl bg-white border-[#d1e7dd] p-3.5 shadow-sm` card.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.header,
    required this.blocks,
    required this.fontScale,
  });

  final Widget header;
  final List<GuideBlock> blocks;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight
              ? const Color(0xFFD1E7DD)
              : scheme.outline.withValues(alpha: 0.6),
        ),
        boxShadow: isLight
            ? const <BoxShadow>[
                BoxShadow(
                  // Level-1 ambient card shadow
                  color: Color(0x0A0D3823),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          header,
          const SizedBox(height: 12),
          GuideBlockView(blocks: blocks, fontScale: fontScale),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.stepNumber,
    required this.total,
    required this.title,
    this.group = '',
  });

  final int stepNumber;
  final int total;
  final String title;
  final String group;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    // Directory-card header: icon tile + title/subtitle + category pill.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFF5FBF7)
                    : scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLight
                      ? const Color(0xFFD6EBD9)
                      : scheme.outline.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                Icons.eco_rounded,
                size: 20,
                color: isLight ? const Color(0xFF047857) : scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  InlineText(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      height: 1.42,
                      fontWeight: FontWeight.w700,
                      color: isLight
                          ? const Color(0xFF0A2E18)
                          : scheme.onSurface,
                    ),
                  ),
                  if (group.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.folder_open_rounded,
                          size: 12,
                          color: isLight
                              ? const Color(0xFF4A6B57)
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            group,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isLight
                                  ? const Color(0xFF4A6B57)
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // "ধাপ N" pill, like the design's category badge.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isLight
                    ? const Color(0xFFDCFCE7)
                    : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isLight
                      ? const Color(0xFFBBF7D0)
                      : scheme.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'ধাপ $stepNumber',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isLight
                      ? const Color(0xFF065F46)
                      : scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(
          color: isLight
              ? const Color(0xFFE2EFE7)
              : scheme.outlineVariant.withValues(alpha: 0.5),
          thickness: 1,
        ),
      ],
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.current,
    required this.total,
    required this.onPrevious,
    required this.onNext,
    required this.onMenu,
  });

  final int current;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLast = current == total - 1;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              tooltip: 'আগের ধাপ',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onMenu,
                icon: const Icon(Icons.list_rounded, size: 18),
                label: const Text('সব ধাপ'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: onNext,
              icon: Icon(
                isLast ? Icons.done_all_rounded : Icons.arrow_forward_ios,
                size: 18,
              ),
              tooltip: isLast ? 'সম্পূর্ণ' : 'পরের ধাপ',
              style: IconButton.styleFrom(
                backgroundColor: isLast ? scheme.tertiary : scheme.primary,
                foregroundColor: isLast ? scheme.onTertiary : scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
