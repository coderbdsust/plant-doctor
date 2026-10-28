import 'package:flutter/material.dart';

import '../models/guide.dart';
import '../services/local_search_service.dart';
import '../state/app_controller.dart';
import '../widgets/inline_text.dart';

/// Guide search screen.
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.onOpenStep,
  });

  final AppController controller;
  final void Function(GuideChapter chapter, GuideStep step) onOpenStep;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  String? _error;
  List<SearchHit> _hits = const <SearchHit>[];
  List<String> _related = const <String>[];

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

  void _submit(String query) {
    final String q = query.trim();
    if (q.isEmpty) return;
    _runGuideSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('সার্চ'),
            Text(
              'গাইড অনুসন্ধান',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _input,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              onChanged: (String value) {
                if (value.trim().isNotEmpty) {
                  _runGuideSearch(value);
                } else {
                  setState(() {
                    _hits = const <SearchHit>[];
                    _related = const <String>[];
                    _error = null;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'যেমন: কোকোপিট, ছত্রাক, টব',
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
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.wifi_off_rounded, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'সার্চ ব্যর্থ হয়েছে',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _submit(_input.text),
              child: const Text('আবার চেষ্টা করুন'),
            ),
          ],
        ),
      );
    }

    return _buildGuideResults(theme, scheme);
  }

  Widget _buildGuideResults(ThemeData theme, ColorScheme scheme) {
    final String query = _input.text.trim();

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_rounded, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'গাইডে খুঁজুন',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'সার, রোগ, উদ্ভিদের নাম বা যেকোনো উপাদান লিখে সার্চ করুন। ফলাফলে ধাপে ট্যাপ করলে সরাসরি সেই জায়গায় পৌঁছে যাবেন।',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    if (_hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off_rounded, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'কিছু পাওয়া যায়নি',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '"$query" সম্পর্কে গাইডে কিছু নেই। অন্য কোনো শব্দ দিয়ে চেষ্টা করুন',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
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
}

class _HitCard extends StatelessWidget {
  const _HitCard({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Material(
      color: theme.cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isLight
                  ? const Color(0xFFD1E7D8)
                  : scheme.outline.withValues(alpha: 0.5),
            ),
            boxShadow: isLight
                ? const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x0A0D3823),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLight
                          ? const Color(0xFFDCFCE7)
                          : scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLight
                            ? const Color(0xFFBBF7D0)
                            : scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'অধ্যায় ${hit.chapter.number}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isLight
                            ? const Color(0xFF065F46)
                            : scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hit.step.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isLight
                            ? const Color(0xFF0A2E18)
                            : scheme.onSurface,
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
                  color: isLight
                      ? const Color(0xFF344E40)
                      : scheme.onSurfaceVariant,
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
