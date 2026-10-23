import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class WebSearchResult {
  WebSearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.source = '',
  });

  final String title;
  final String url;
  final String snippet;
  final String source;
}

/// Searches the live web using the public DuckDuckGo Instant Answer API
/// (no API key required) and can hand off to a full Google search in the
/// browser.
class WebSearchService {
  WebSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _ddgEndpoint = 'https://api.duckduckgo.com/';

  /// Runs a web search and returns the best available results.
  Future<List<WebSearchResult>> search(String query) async {
    final String q = query.trim();
    if (q.isEmpty) return const <WebSearchResult>[];

    final Uri uri = Uri.parse(_ddgEndpoint).replace(
      queryParameters: <String, String>{
        'q': q,
        'format': 'json',
        'no_html': '1',
        'skip_disambig': '1',
        't': 'plant_doctor',
      },
    );

    final http.Response response = await _client.get(uri).timeout(
      const Duration(seconds: 20),
    );    if (response.statusCode != 200) {
      throw Exception('ইন্টারনেট সার্চ ব্যর্থ হয়েছে (${response.statusCode})।');
    }

    final Map<String, dynamic> json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    final List<WebSearchResult> results = <WebSearchResult>[];

    final String abstract = (json['AbstractText'] as String?)?.trim() ?? '';
    final String abstractSource = (json['AbstractSource'] as String?)?.trim() ?? '';
    final String abstractUrl = (json['AbstractURL'] as String?)?.trim() ?? '';
    if (abstract.isNotEmpty) {
      results.add(WebSearchResult(
        title: abstractSource.isEmpty ? 'DuckDuckGo' : abstractSource,
        url: abstractUrl.isEmpty ? 'https://duckduckgo.com/?q=$q' : abstractUrl,
        snippet: abstract,
        source: 'DuckDuckGo',
      ));
    }

    final List<dynamic> related = (json['RelatedTopics'] as List<dynamic>?) ?? const <dynamic>[];
    for (final topic in related) {
      if (topic is! Map) continue;
      final text = (topic['Text'] as String?)?.trim();
      final url = (topic['FirstURL'] as String?)?.trim();
      if (text == null || text.isEmpty) continue;
      results.add(WebSearchResult(
        title: _firstLine(text),
        url: url ?? 'https://duckduckgo.com/?q=$q',
        snippet: text,
        source: 'DuckDuckGo',
      ));
    }

    final List<dynamic> resultsList = (json['Results'] as List<dynamic>?) ?? const <dynamic>[];
    for (final item in resultsList) {
      if (item is! Map) continue;
      final url = (item['URL'] as String?)?.trim();
      if (url == null || url.isEmpty) continue;
      results.add(WebSearchResult(
        title: _firstLine((item['FirstURL'] as String?) ?? url),
        url: url,
        snippet: (item['Text'] as String?) ?? url,
        source: 'DuckDuckGo',
      ));
    }

    return results;
  }

  String _firstLine(String text) {
    final int idx = text.indexOf(' - ');
    return idx > 0 ? text.substring(0, idx) : text;
  }

  /// Opens the query in a Google search in the default browser.
  Future<void> openGoogleSearch(String query) async {
    final Uri uri = Uri.https('www.google.com', '/search', <String, String>{
      'q': query.trim(),
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('ব্রাউজার খোলা যায়নি।');
    }
  }

  /// Opens the query in a Google search in an in-app browser view.
  Future<void> openGoogleSearchInApp(String query) async {
    final Uri uri = Uri.https('www.google.com', '/search', <String, String>{
      'q': query.trim(),
    });
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      throw Exception('ব্রাউজার খোলা যায়নি।');
    }
  }

  /// Opens a URL in the default browser.
  Future<void> openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('লিংক খোলা যায়নি।');
    }
  }

  void dispose() => _client.close();
}
