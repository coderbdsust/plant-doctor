import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A grounding citation returned by the Gemini Google Search tool.
class GeminiCitation {
  GeminiCitation({required this.title, required this.uri});
  final String title;
  final String uri;
}

class GeminiReply {
  GeminiReply({required this.text, this.citations = const <GeminiCitation>[]});
  final String text;
  final List<GeminiCitation> citations;
}

class GeminiException implements Exception {
  GeminiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Thin client around the Google Gemini REST API.
///
/// Uses `models.generateContent` with the optional `googleSearch` tool so
/// answers can be grounded in live web results.
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _base = 'https://generativelanguage.googleapis.com/v1beta';

  static const List<String> availableModels = <String>[
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.5-pro',
  ];

  static const String systemInstruction =
      'তুমি একজন অভিজ্ঞ বাংলাদেশি ছাদ বাগান (rooftop garden) ও উদ্ভিদ পরিচর্যা বিশেষজ্ঞ। '
      'ব্যবহারকারীর প্রশ্নের উত্তর বাংলায় দাও, সহজ ও বাস্তবসম্মত ভাষায়। '
      'যদি প্রশ্ন ছাদ বাগান সম্পর্কিত না হয়, তাহলেও সাধারণ জ্ঞানের ভিত্তিতে সংক্ষিপ্ত ও '
      'সঠিক উত্তর দাও।';

  static const String plantDoctorSystemInstruction =
      'তুমি একজন অভিজ্ঞ উদ্ভিদ রোগ নির্ণয় ও চিকিৎসা বিশেষজ্ঞ। '
      'তুমি উদ্ভিদের ছবি দেখে সঠিকভাবে শনাক্ত করবে, সম্ভাব্য রোগ/পোকা শনাক্ত করবে এবং '
      'বাংলাদেশি পরিবেশ অনুযায়ী জৈব ও রাসায়নিক উভয় ধরনের কার্যকর প্রতিকার বলবে। '
      'উত্তর অবশ্যই বাংলায় দাও। প্রতিটি উত্তরে নিম্নোক্ত বিষয় অন্তর্ভুক্ত করবে: '
      '১) উদ্ভিদের নাম (বাংলা ও বৈজ্ঞানিক নাম), '
      '২) স্বাস্থ্যের অবস্থা, '
      '৩) শনাক্তকৃত রোগ/পোকা (যদি থাকে), '
      '৪) কারণ, '
      '৫) প্রতিকার (জৈব পদ্ধতি প্রথমে বলবে), '
      '৬) প্রতিরোধমূলক ব্যবস্থা, '
      '৭) জরুরি পরামর্শ।';

  /// Sends a plant/leaf image for identification and disease diagnosis.
  Future<GeminiReply> identifyPlant({
    required String apiKey,
    required String model,
    required String base64Image,
    required String mimeType,
    String? additionalPrompt,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw GeminiException(
          'Gemini API key যোগ করা হয়নি। সেটিংস থেকে key দিন।');
    }

    final String prompt = additionalPrompt?.trim().isNotEmpty == true
        ? additionalPrompt!.trim()
        : 'এই উদ্ভিদের ছবি বিশ্লেষণ করে রোগ/পোকা শনাক্ত করুন এবং উপযুক্ত চিকিৎসা পরামর্শ দিন।';

    final Map<String, dynamic> body = <String, dynamic>{
      'systemInstruction': <String, dynamic>{
        'parts': <Map<String, String>>[
          <String, String>{'text': plantDoctorSystemInstruction},
        ],
      },
      'contents': <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, dynamic>>[
            <String, String>{'text': prompt},
            <String, dynamic>{
              'inlineData': <String, String>{
                'mimeType': mimeType,
                'data': base64Image,
              },
            },
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'maxOutputTokens': 4096,
      },
    };

    final http.Response response = await _postGenerate(
      model: model,
      body: body,
      apiKey: apiKey,
      timeout: const Duration(seconds: 120),
    );

    return _parseReply(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Sends a chat turn and returns the assistant reply.
  Future<GeminiReply> chat({
    required String apiKey,
    required String model,
    required List<Map<String, dynamic>> history,
    required String prompt,
    bool useGoogleSearch = true,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw GeminiException(
          'Gemini API key যোগ করা হয়নি। সেটিংস থেকে key দিন।');
    }

    final Map<String, dynamic> body = <String, dynamic>{
      'systemInstruction': <String, dynamic>{
        'parts': <Map<String, String>>[
          <String, String>{'text': systemInstruction},
        ],
      },
      'contents': <Map<String, dynamic>>[
        ...history,
        <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, String>>[
            <String, String>{'text': prompt},
          ],
        },
      ],
      'generationConfig': <String, dynamic>{
        'maxOutputTokens': 4096,
      },
    };

    if (useGoogleSearch) {
      body['tools'] = <Map<String, dynamic>>[
        <String, dynamic>{'googleSearch': <String, dynamic>{}},
      ];
    }

    final http.Response response = await _postGenerate(
      model: model,
      body: body,
      apiKey: apiKey,
      timeout: const Duration(seconds: 90),
    );

    return _parseReply(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Posts a `generateContent` request authenticating with the API key
  /// header (`x-goog-api-key`), with one automatic retry when the server
  /// asks for a short retry delay (HTTP 429).
  Future<http.Response> _postGenerate({
    required String model,
    required Map<String, dynamic> body,
    required String apiKey,
    required Duration timeout,
  }) async {
    final Uri uri = Uri.parse('$_base/models/$model:generateContent');
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey.trim(),
    };

    final String encodedBody = jsonEncode(body);
    const int maxAttempts = 2;

    for (int attempt = 1;; attempt++) {
      final http.Response response;
      try {
        response = await _client
            .post(uri, headers: headers, body: encodedBody)
            .timeout(timeout);
      } on TimeoutException {
        throw GeminiException('অনুরোধের সময় শেষ হয়ে গেছে। আবার চেষ্টা করুন।');
      }

      if (response.statusCode == 200) return response;

      if (response.statusCode == 429 && attempt < maxAttempts) {
        final Duration? delay = retryDelayFromError(response.body);
        if (delay != null && delay <= const Duration(seconds: 15)) {
          await Future<void>.delayed(delay);
          continue;
        }
      }

      throw GeminiException(
        friendlyError(response.body, response.statusCode),
        statusCode: response.statusCode,
      );
    }
  }

  /// Extracts the server-suggested retry delay (ISO-8601 duration, e.g.
  /// `"12s"`) from a 429 error body, if present.
  static Duration? retryDelayFromError(String body) {
    String? raw;
    try {
      final dynamic json = jsonDecode(body);
      if (json is Map && json['error'] is Map) {
        final Map<dynamic, dynamic> error = json['error'] as Map<dynamic, dynamic>;
        final dynamic details = error['details'];
        if (details is List) {
          for (final detail in details) {
            if (detail is Map) {
              final dynamic violations = detail['violations'];
              if (violations is List && violations.isNotEmpty) {
                final dynamic first = violations.first;
                if (first is Map && first['retryDelay'] is String) {
                  raw = first['retryDelay'] as String;
                  break;
                }
              }
              if (detail['retryDelay'] is String) {
                raw = detail['retryDelay'] as String;
              }
            }
          }
        }
        if (raw == null && error['retryDelay'] is String) {
          raw = error['retryDelay'] as String;
        }
      }
    } catch (_) {
      return null;
    }
    if (raw == null) return null;
    final RegExpMatch? match =
        RegExp(r'^PT?(?:(\d+(?:\.\d+)?)S)?$').firstMatch(raw.trim());
    if (match != null && match.group(1) != null) {
      return Duration(milliseconds: (double.parse(match.group(1)!) * 1000).round());
    }
    return null;
  }

  /// Turns a raw Gemini error response into a friendly Bengali message.
  static String friendlyError(String body, [int? statusCode]) {
    String message = 'Gemini অনুরোধ ব্যর্থ হয়েছে। অনুগ্রহ করে API key যাচাই করুন।';
    try {
      final dynamic json = jsonDecode(body);
      if (json is Map && json['error']['message'] is String) {
        message = json['error']['message'] as String;
      }
    } catch (_) {
      // keep default message
    }

    if (statusCode == 429) {
      final Duration? delay = retryDelayFromError(body);
      final String waitHint =
          delay == null ? '' : ' প্রায় ${delay.inSeconds} সেকেন্ড পর আবার চেষ্টা করুন।';
      return 'রেট লিমিট/কোটা শেষ হয়ে গেছে (৪২৯)।$waitHint\n\n'
          'টিপস: একই Google Cloud প্রজেক্টের সব API key মিলে কোটা ব্যবহার করে — '
          'নতুন key বানালেও একই প্রজেক্টে কোটা রিসেট হয় না। নতুন প্রজেক্টে '
          '(aistudio.google.com/apikey) key তৈরি করলে ফ্রি কোটা আলাদাভাবে পাওয়া যায়।';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'প্রমাণীকরণ ব্যর্থ ($statusCode)। API key সঠিক কিনা এবং মডেলটি আপনার '
          'প্রজেক্টের জন্য উন্মুক্ত কিনা যাচাই করুন।\n\nসার্ভার বলেছে: $message';
    }
    return message;
  }

  GeminiReply _parseReply(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      final blockReason = json['promptFeedback']?['blockReason'];
      if (blockReason != null) {
        throw GeminiException('অনুরোধটি ব্লক করা হয়েছে ($blockReason)।');
      }
      throw GeminiException('কোনো উত্তর পাওয়া যায়নি।');
    }

    final candidate = candidates.first as Map<String, dynamic>;
    final parts = candidate['content']?['parts'];
    final buffer = StringBuffer();
    if (parts is List) {
      for (final part in parts) {
        final text = part?['text'];
        if (text is String) buffer.write(text);
      }
    }

    final List<GeminiCitation> citations = <GeminiCitation>[];
    final grounding = candidate['groundingMetadata'];
    if (grounding is Map) {
      final chunks = grounding['groundingChunks'];
      if (chunks is List) {
        for (final chunk in chunks) {
          final web = chunk?['web'];
          if (web is Map && web['uri'] is String) {
            citations.add(GeminiCitation(
              title: (web['title'] as String?) ?? web['uri'] as String,
              uri: web['uri'] as String,
            ));
          }
        }
      }
    }

    return GeminiReply(text: buffer.toString().trim(), citations: citations);
  }

  void dispose() => _client.close();
}
