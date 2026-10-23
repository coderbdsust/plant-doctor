import 'package:flutter/material.dart';

import '../models/guide.dart';
import '../services/local_search_service.dart';
import '../services/web_search_service.dart';
import '../state/app_controller.dart';
import '../widgets/inline_text.dart';

/// Search screen with three modes: guide search, internet search and
/// Gemini AI.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.webSearchService,
    required this.onOpenStep,
    required this.onOpenAi,
  });

  final AppController controller;
  final WebSearchService webSearchService;
  final void Function(GuideChapter chapter, GuideStep step) onOpenStep;
  final VoidCallback onOpenAi;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _Mode { guide, web }

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  _Mode _mode = _Mode.guide;
  bool _searching = false;
  String? _error;

  List<SearchHit> _hits = const <SearchHit>[];
  List<String> _related = const <String>[];
  List<WebSearchResult> _webResults = const <WebSearchResult>[];

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _runGuideSearch(String query) {
    setState(() {
      _hits = widget.controller.search(query);
      _related = widget.controller.relatedTerms(query);
      _error = null;
    });
  }

  Future<void> _runWebSearch(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final List<WebSearchResult> results =
          await widget.webSearchService.search(query);
      if (!mounted) return;
      setState(() {
        _webResults = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _searching = false;
      });
    }
  }

  void _submit(String query) {
    final String q = query.trim();
    if (q.isEmpty) return;
    switch (_mode) {
      case _Mode.guide:
        _runGuideSearch(q);
        break;
      case _Mode.web:
        _runWebSearch(q);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('সার্চ'),
        actions: <Widget>[
          IconButton(
            tooltip: 'জেমিনি AI',
            onPressed: widget.onOpenAi,
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SegmentedButton<_Mode>(
              segments: const <ButtonSegment<_Mode>>[
                ButtonSegment<_Mode>(
                  value: _Mode.guide,
                  label: Text('গাইডে'),
                  icon: Icon(Icons.menu_book_outlined, size: 18),
                ),
                ButtonSegment<_Mode>(
                  value: _Mode.web,
                  label: Text('ইন্টারনেটে'),
                  icon: Icon(Icons.public, size: 18),
                ),
              ],
              selected: <_Mode>{_mode},
              onSelectionChanged: (Set<_Mode> value) {
                setState(() {
                  _mode = value.first;
                  _error = null;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _input,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              onChanged: (String value) {
                if (_mode == _Mode.guide && value.trim().isNotEmpty) {
                  _runGuideSearch(value);
                }
              },
              decoration: InputDecoration(
                hintText: _mode == _Mode.guide
                    ? 'যেমন: কোকোপিট, ছত্রাক, টব'
                    : 'যেমন: rooftop garden বাংলাদেশ',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _submit(_input.text),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody(theme, scheme)),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme scheme) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _Message(
        icon: Icons.wifi_off_rounded,
        title: 'সার্চ ব্যর্থ হয়েছে',
        body: _error!,
        action: FilledButton(
          onPressed: () => _submit(_input.text),
          child: const Text('আবার চেষ্টা করুন'),
        ),
      );
    }

    if (_mode == _Mode.guide) {
      return _buildGuideResults(theme, scheme);
    }
    return _buildWebResults(theme, scheme);
  }

  Widget _buildGuideResults(ThemeData theme, ColorScheme scheme) {
    final String query = _input.text.trim();

    if (query.isEmpty) {
      return _Message(
        icon: Icons.search_rounded,
        title: 'গাইডে খুঁজুন',
        body:
            'সার, রোগ, উদ্ভিদের নাম বা যেকোনো উপাদান লিখে সার্চ করুন। '
            'ফলাফলে ধাপে ট্যাপ করলে সরাসরি সেই জায়গায় পৌঁছে যাবেন।',
      );
    }

    if (_hits.isEmpty) {
      return _Message(
        icon: Icons.search_off_rounded,
        title: 'কিছু পাওয়া যায়নি',
        body: '"$query" সম্পর্কে গাইডে কিছু নেই। অন্য কোনো শব্দ দিয়ে চেষ্টা করুন '
            'অথবা ইন্টারনেটে সার্চ করুন।',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _hits.length + (_related.isEmpty ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (_related.isNotEmpty && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final term in _related)
                  ActionChip(
                    label: Text(term),
                    onPressed: () {
                      _input.text = term;
                      _runGuideSearch(term);
                    },
                  ),
              ],
            ),
          );
        }
        final SearchHit hit = _hits[index - (_related.isEmpty ? 0 : 1)];
        return _HitCard(
          hit: hit,
          onTap: () => widget.onOpenStep(hit.chapter, hit.step),
        );
      },
    );
  }

  Widget _buildWebResults(ThemeData theme, ColorScheme scheme) {
    final String query = _input.text.trim();

    if (query.isEmpty) {
      return _Message(
        icon: Icons.travel_explore_rounded,
        title: 'ইন্টারনেটে সার্চ করুন',
        body: 'যেকোনো বিষয়ে সার্চ করতে পারেন। ফলাফলের লিংকে ট্যাপ করে '
            'ব্রাউজারে খুলুন, অথবা "গুগলে সার্চ" বোতামে সরাসরি গুগলে যান।',
        action: FilledButton.icon(
          onPressed: () => widget.onOpenAi,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: const Text('জেমিনি AI দিয়ে জিজ্ঞাসা করুন'),
        ),
      );
    }

    if (_webResults.isEmpty) {
      return _Message(
        icon: Icons.travel_explore_rounded,
        title: 'রেজাল্ট পাওয়া যায়নি',
        body: 'কোনো ফলাফল পাওয়া যায়নি। গুগলে সার্চ করে দেখতে পারেন।',
        action: OutlinedButton.icon(
          onPressed: () => widget.webSearchService.openGoogleSearch(query),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('গুগলে সার্চ করুন'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _webResults.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: OutlinedButton.icon(
              onPressed: () =>
                  widget.webSearchService.openGoogleSearch(query),
              icon: const Icon(Icons.travel_explore, size: 18),
              label: Text('"$query" গুগলে সার্চ করুন'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          );
        }
        final WebSearchResult result = _webResults[index - 1];
        return _WebResultCard(
          result: result,
          onTap: () => widget.webSearchService.openUrl(result.url),
        );
      },
    );
  }
}

class _HitCard extends StatelessWidget {
  const _HitCard({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      'অধ্যায় ${hit.chapter.number}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hit.step.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              InlineText(
                hit.excerpt,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(Icons.arrow_forward, size: 14, color: scheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'এই ধাপে যান',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebResultCard extends StatelessWidget {
  const _WebResultCard({required this.result, required this.onTap});

  final WebSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                result.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.snippet,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(Icons.link, size: 13, color: scheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      result.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
