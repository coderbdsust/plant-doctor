import 'package:flutter/material.dart';

import '../models/guide.dart';
import '../services/gemini_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_motion.dart';
import 'plant_doctor_screen.dart';

const List<String> _roofTips = <String>[
  'টবের কিনারা ঘেঁষে গোল নালা কেটে অনুখাদ্য দিয়ে মাটি ঢেকে দিন — পোড়া রোধ হবে।',
  'হাফ ড্রাম সাইজের টবে ৪ মুঠ সার, ছোট টবে ২ মুঠ — ২৫ দিন পর প্রয়োগ করুন।',
  'সকাল ৯টার আগে বা বিকাল ৪টার পর বাগানে পানি দিন — দুপুরের রোদে পানি দিলে শিকড় পোড়ে।',
  'পাতা ঝরে পড়লে পানির ঘাটতি ভাবার আগে মাটি আলগা করে দেখুন — শিকড়ে পানি জমে থাকলে ঝরে।',
  'লেবুর ক্লোরোসিস হলে জিংক + আয়রন মিশিয়ে গোড়ায় স্প্রে করুন।',
  'মিলিবাগ আক্রমণে ইমিটাফ/নিমতেল ১৫ দিনে একবার স্প্রে করুন — কচি পাতার পিঠে ভালো করে দিন।',
  'ছত্রাক দমনে প্রথমে ট্রাইকোডার্মা দিন — না হলে ম্যানকোজেব, ১৫ দিন ব্যবধানে।',
  'গাছের বৃদ্ধি থেমে গেলে দেখুন টব ছোট হয়ে গেছে কি না — শিকড় বেরিয়ে এলে বড় টবে রিপোট করুন।',
  'সিড ট্রেতে কোকোপিট মিশ্রণে বীজ রোপণ করুন — অঙ্কুরোদগম দ্রুত হবে।',
  'টবের নিচে ব্লক পাথর বসান যাতে পানি জমা না হয় — শিকড়ে বাতাস চলাচল থাকবে।',
  'পুষ্টি ঘাটতি দেখা দিলে ইউরিয়া, টিএসপি ও এমওপি সুষম অনুপাতে সপ্তাহে একবার দিন।',
  'ব্লু/হলুদ স্টিকি প্যাড টবের পাশে লাগান — উড়ন্ত পোকা দমনের প্রথম কাজ।',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenChapter,
    required this.onContinueReading,
    required this.onOpenSearch,
    required this.onOpenSettings,
  });

  final AppController controller;
  final void Function(GuideChapter chapter) onOpenChapter;
  final VoidCallback onContinueReading;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenSettings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// null = সকল অধ্যায় দেখাও, অন্য মান = এই অধ্যায়টি হাইলাইট করো।
  int? _selectedChapter;

  List<GuideChapter> get _chaptersFiltered {
    final List<GuideChapter> chapters = widget.controller.chapters;
    if (_selectedChapter == null) return chapters;
    if (_selectedChapter! < chapters.length) {
      return <GuideChapter>[chapters[_selectedChapter!]];
    }
    return chapters;
  }

  void _openPlantDoctor() {
    Navigator.of(context).push(
      FadeSlideRoute<void>(
        builder: (BuildContext context) => PlantDoctorScreen(
          controller: widget.controller,
          geminiService: GeminiService(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.controller.error != null) {
      return _ErrorView(
        message: widget.controller.error!,
        onRetry: widget.controller.load,
      );
    }

    final List<GuideChapter> all = widget.controller.chapters;
    final int stepCount = widget.controller.document?.stepCount ?? 0;
    final List<GuideChapter> chapters = _chaptersFiltered;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.controller.load,
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: StaggeredEntrance(
                  order: 0,
                  child: _TopBar(
                    onOpenSettings: widget.onOpenSettings,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Column(
                    children: <Widget>[
                      StaggeredEntrance(
                        order: 1,
                        child: _SearchPill(onTap: widget.onOpenSearch),
                      ),
                      const SizedBox(height: 12),
                      StaggeredEntrance(
                        order: 2,
                        child: _ChapterChips(
                          chapters: all,
                          selected: _selectedChapter,
                          onSelected: (int? i) =>
                              setState(() => _selectedChapter = i),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StaggeredEntrance(
                        order: 3,
                        child: PressableScale(
                          onTap: _openPlantDoctor,
                          child: const _ScanHero(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      StaggeredEntrance(order: 4, child: _TipOfDay()),
                      const SizedBox(height: 20),
                      StaggeredEntrance(
                        order: 5,
                        child: _SectionHeader(
                          title: 'প্রয়োজনীয় ক্যাটাগরি',
                          chips: <String>[
                            '${all.length}টি অধ্যায়',
                            '$stepCountটি ধাপ',
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                sliver: SliverList.separated(
                  itemCount: chapters.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final GuideChapter chapter = chapters[index];
                    return StaggeredEntrance(
                      order: 6 + index,
                      enabled: index < 8,
                      child: _ChapterCard(
                        chapter: chapter,
                        onTap: () => widget.onOpenChapter(chapter),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ── টপ বার: লোগো টাইল + টাইটেল + badge + actioncircle ──────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              // ডার্ক: গ্লো-গ্রেডিয়েন্ট টাইল • লাইট গ্রিন: emerald-100 টাইল
              color: isDark ? null : scheme.primaryContainer,
              gradient: isDark
                  ? const LinearGradient(
                      colors: AppTheme.accentGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: isDark ? null : Border.all(color: scheme.outlineVariant),
              boxShadow: isDark
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppTheme.glow.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.local_florist_rounded,
              color: isDark ? const Color(0xFF003915) : scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'উদ্ভিদ ডাক্তার',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    // ডার্ক: প্রাইমারি প্রি • লাইট: গাঢ় সবুজ টেক্সট (design: text-primary)
                    color: isDark ? scheme.primary : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'উদ্ভিদ ও বাগান সহকারী',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          _CircleIcon(
            tooltip: 'সেটিংস',
            icon: Icons.settings_outlined,
            onTap: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 21),
        color: scheme.onSurfaceVariant,
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(10),
        ),
      ),
    );
  }
}

/// ── রাউন্ড সার্চ পিল ─────────────────────────────────────────────────────
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return PressableScale(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0x0A0D3823), // green ambient Level-1
              blurRadius: 20,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.search_rounded, color: scheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'গাইডে সার্চ করুন বা প্রশ্ন লিখুন...',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.outline,
                ),
              ),
            ),
            Icon(
              Icons.mic_none_rounded,
              color: scheme.onSurfaceVariant,
              size: 19,
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: scheme.onSurfaceVariant,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// ── চ্যাপ্টার ফিল্টার চিপস (স্ক্রলযোগ্য পিল) ────────────────────────
class _ChapterChips extends StatelessWidget {
  const _ChapterChips({
    required this.chapters,
    required this.selected,
    required this.onSelected,
  });

  final List<GuideChapter> chapters;
  final int? selected;
  final void Function(int?) onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;

    String shortTitle(GuideChapter c) {
      final List<String> words = c.title.trim().split(RegExp(r'\s+'));
      if (words.length <= 3) return c.title.trim();
      return '${words.take(3).join(' ')}…';
    }

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chapters.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final bool isAll = index == 0;
          final GuideChapter? c = isAll ? null : chapters[index - 1];
          final bool selected = isAll
              ? this.selected == null
              : this.selected == index - 1;

          return GestureDetector(
            onTap: () => onSelected(isAll ? null : (index - 1)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                // Filter chip spec: white rest + 12% pine border,
                // active = #15803D fill with white text.
                color: selected ? scheme.primary : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: selected
                    ? null
                    : Border.all(
                        color: isDark
                            ? scheme.outlineVariant
                            : const Color(0x1F153E2B),
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!isAll) ...<Widget>[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: selected ? scheme.onPrimary : scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    isAll ? 'সকল নির্দেশিকা' : shortTitle(c!),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ── হিরো স্ক্যান কার্ড (গ্লো ব্লব + ব্যাজ + ফিচার + CTA) ───────────────
class _ScanHero extends StatelessWidget {
  const _ScanHero();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;

    return Container(
      // Hero scan summary: rounded-2xl (2rem) + soft sage border.
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(isDark ? 14 : 32),
        border: isDark ? null : Border.all(color: const Color(0x14153E2B)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x0A0D3823),
            blurRadius: 20,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          // গ্লো ব্লব (design: primary/10 top-right, tertiary/10 bottom-left)
          Positioned(
            right: -24,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    scheme.primary.withValues(alpha: 0.14),
                    scheme.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    scheme.tertiaryContainer.withValues(alpha: 0.14),
                    scheme.tertiaryContainer.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'AI স্ক্যানার',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'তাত্ক্ষণিক নিদান',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.center_focus_strong_rounded,
                        color: scheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        'গাছের ছবি তুলুন বা আপলোড করুন',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Row(
                  children: <Widget>[
                    _HeroFeature(
                      icon: Icons.check_circle,
                      label: 'মিলিবাগ ও ছত্রাক সনাক্তকরণ',
                    ),
                    SizedBox(width: 16),
                    _HeroFeature(
                      icon: Icons.check_circle,
                      label: 'বিনা মূল্যে তাৎক্ষণিক নিদান',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: FilledButton.icon(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: scheme.primary,
                      disabledForegroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: Icon(Icons.center_focus_strong_rounded, size: 18),
                    label: const Text(
                      'উদ্ভিদ ডাক্তার খুলুন',
                      overflow: TextOverflow.ellipsis,
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

class _HeroFeature extends StatelessWidget {
  const _HeroFeature({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: scheme.primary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// ── আজকের টিপস কার্ড (lightbulb + bookmark টগল) ─────────────────────
class _TipOfDay extends StatefulWidget {
  const _TipOfDay();

  @override
  State<_TipOfDay> createState() => _TipOfDayState();
}

class _TipOfDayState extends State<_TipOfDay> {
  bool _saved = false;

  static int _tipIndex() {
    final DateTime now = DateTime.now();
    return now.difference(DateTime(2026)).inDays % _roofTips.length;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String tip = _roofTips[_tipIndex()];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_rounded,
              size: 18,
              color: scheme.tertiary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'আজকের ছাদকৃষি টিপস',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.tertiary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.55),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'সেভ',
            onPressed: () => setState(() => _saved = !_saved),
            icon: Icon(
              _saved
                  ? Icons.bookmark_added_rounded
                  : Icons.bookmark_add_rounded,
              size: 20,
              color: _saved ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// ── সেকশন হেডার + স্ট্যাট চিপাস ──────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.chips});

  final String title;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            for (int i = 0; i < chips.length; i++)
              Container(
                margin: EdgeInsets.only(right: i == chips.length - 1 ? 0 : 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  chips[i],
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// ── চ্যাপ্টার কার্ড (ক্যাটাগরি স্টাইল) ───────────────────────────────
const List<IconData> _chapterIcons = <IconData>[
  Icons.local_florist_outlined,
  Icons.compost_outlined,
  Icons.water_drop_outlined,
  Icons.grass,
  Icons.pest_control_outlined,
  Icons.spa_outlined,
  Icons.science_outlined,
  Icons.eco_outlined,
  Icons.landscape_outlined,
  Icons.home_repair_service_outlined,
  Icons.menu_book_outlined,
];

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({required this.chapter, required this.onTap});

  final GuideChapter chapter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = scheme.brightness == Brightness.dark;
    final IconData icon =
        _chapterIcons[chapter.index < _chapterIcons.length
            ? chapter.index
            : _chapterIcons.length - 1];

    return PressableScale(
      onTap: onTap,
      child: Material(
        // Diagnostic plant card: white surface, 24px radius, sage border.
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDark ? 12 : 24),
          side: isDark
              ? BorderSide.none
              : const BorderSide(color: Color(0x14153E2B)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isDark ? 12 : 24),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        chapter.title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${chapter.steps.length}টি ধাপ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onRetry(),
                child: const Text('আবার চেষ্টা করুন'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
