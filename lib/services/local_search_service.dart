import '../models/guide.dart';

class SearchHit {
  SearchHit({
    required this.chapter,
    required this.step,
    required this.excerpt,
    required this.score,
    required this.terms,
  });

  final GuideChapter chapter;
  final GuideStep step;
  final String excerpt;
  final int score;
  final List<String> terms;
}

/// Full-text search across the parsed guide.
class LocalSearchService {
  const LocalSearchService();

  List<SearchHit> search(GuideDocument document, String rawQuery) {
    final String query = rawQuery.trim();
    if (query.isEmpty) return const <SearchHit>[];

    final List<String> terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const <SearchHit>[];

    final List<SearchHit> hits = <SearchHit>[];

    for (final chapter in document.chapters) {
      for (final step in chapter.steps) {
        final String haystack = '${chapter.title} ${step.title} ${step.plainText}'.toLowerCase();
        final String stepText = step.plainText;

        int score = 0;
        final List<String> matched = <String>[];
        for (final term in terms) {
          if (chapter.title.toLowerCase().contains(term)) score += 6;
          if (step.title.toLowerCase().contains(term)) score += 5;
          final int occurrences = term.allMatches(haystack).length;
          if (occurrences > 0) {
            score += occurrences * 2;
            matched.add(term);
          }
        }
        if (score == 0) continue;

        hits.add(SearchHit(
          chapter: chapter,
          step: step,
          excerpt: _excerpt(stepText, matched),
          score: score,
          terms: matched,
        ));
      }
    }

    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits;
  }

  /// Builds a short snippet around the first matched term.
  String _excerpt(String text, List<String> terms) {
    final String clean = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return '';

    const int radius = 90;
    int index = -1;
    for (final term in terms) {
      final int i = clean.toLowerCase().indexOf(term);
      if (i != -1 && (index == -1 || i < index)) index = i;
    }
    if (index == -1) {
      return clean.length <= radius * 2 ? clean : '${clean.substring(0, radius * 2)}…';
    }
    final int start = (index - radius).clamp(0, clean.length);
    final int end = (index + radius).clamp(0, clean.length);
    final String snippet = clean.substring(start, end);
    return '${start > 0 ? '…' : ''}$snippet${end < clean.length ? '…' : ''}';
  }

  /// Suggests related keywords from the guide vocabulary.
  List<String> relatedTerms(GuideDocument document, String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return const <String>[];

    final Map<String, int> counts = <String, int>{};
    for (final chapter in document.chapters) {
      for (final step in chapter.steps) {
        final RegExp bold = RegExp(r'\*\*([^*]{2,30})\*\*');
        for (final m in bold.allMatches(step.plainText)) {
          final String term = m.group(1)!.trim();
          if (term.toLowerCase().contains(q)) {
            counts[term] = (counts[term] ?? 0) + 1;
          }
        }
      }
    }
    final List<String> list = counts.keys.toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    return list.take(6).toList();
  }
}
