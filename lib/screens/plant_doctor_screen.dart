import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/gemini_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';

/// Runs in a background isolate so a large photo never freezes or crashes
/// the UI thread while being base64-encoded.
String _encodeBase64(Uint8List bytes) => base64Encode(bytes);

class PlantDoctorScreen extends StatefulWidget {
  const PlantDoctorScreen({
    super.key,
    required this.controller,
    required this.geminiService,
  });

  final AppController controller;
  final GeminiService geminiService;

  @override
  State<PlantDoctorScreen> createState() => _PlantDoctorScreenState();
}

class _PlantDoctorScreenState extends State<PlantDoctorScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  Uint8List? _previewBytes;
  String? _base64;
  String _mimeType = 'image/jpeg';
  bool _loading = false;
  String? _error;
  GeminiReply? _reply;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool _hasKey() => widget.controller.settings.apiKey.isNotEmpty;

  Future<void> _pick(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        // ছোট সাইজ রাখলে RAM ও API cost দুটোই কমে — Gemini এত বড় ছবিও দরকার নেই
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (picked == null) return;
      final Uint8List bytes = await picked.readAsBytes();
      // পুরনো base64 আগে ছেড়ে দিই, দুটো বড় স্ট্রিং একসাথে মেমোরি দখল না করে
      final String encoded = kIsWeb
          ? base64Encode(bytes)
          : await compute(_encodeBase64, bytes);
      if (!mounted) return;
      setState(() {
        _image = picked;
        _previewBytes = bytes;
        _base64 = encoded;
        _mimeType = picked.mimeType ?? 'image/jpeg';
        _reply = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _pickErrorMessage(e));
    }
  }

  /// Turns raw picker errors (permission denial, broken picker, etc.) into
  /// a Bengali message the user can act on.
  String _pickErrorMessage(Object e) {
    final String raw = e.toString().toLowerCase();
    if (raw.contains('camera') || raw.contains('permission')) {
      return 'ক্যামেরা/গ্যালারির অনুমতি দেওয়া হয়নি। ফোনের Settings → Apps → '
          'Plant Doctor → Permissions থেকে Camera ও Photos অনুমতি চালু করুন।';
    }
    if (raw.contains('activity') || raw.contains('unavailable')) {
      return 'ফোনে উপযুক্ত ক্যামেরা/গ্যালারি অ্যাপ পাওয়া যায়নি। '
          'গ্যালারি থেকে চেষ্টা করুন।';
    }
    return 'ছবি নির্বাচন করা যায়নি: $e';
  }

  Future<void> _analyze() async {
    if (_base64 == null || !_hasKey()) {
      setState(() => _error =
          'Gemini API key সেটিংসে যোগ করুন, তারপর বিশ্লেষণ করুন।');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _reply = null;
    });

    try {
      final reply = await widget.geminiService.identifyPlant(
        apiKey: widget.controller.settings.apiKey,
        model: widget.controller.settings.model,
        base64Image: _base64!,
        mimeType: _mimeType,
        additionalPrompt: _note.text,
      );
      if (!mounted) return;
      setState(() => _reply = reply);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _analyzeErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Keeps any failure visible as a Bengali message instead of freezing
  /// or killing the app.
  String _analyzeErrorMessage(Object e) {
    final String raw = e.toString().toLowerCase();
    if (raw.contains('out of memory') || raw.contains('oom')) {
      return 'ফোনের মেমোরি কম এছে (RAM)। অন্য অ্যাপ বন্ধ করে আবার চেষ্টা করুন, '
          'অথবা ছোট ছবি (০.৫-১ MB) দিয়ে চেষ্টা করুন।';
    }
    if (e is FormatException) {
      return 'সার্ভার থেকে অপ্রত্যাশিত উত্তর এছে। কিছুক্ষণ পর আবার চেষ্টা করুন।';
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final s = widget.controller.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('গাছের ডাক্তার'),
        actions: <Widget>[
          IconButton(
            tooltip: 'রিসেট',
            onPressed: () => setState(() {
              _image = null;
              _previewBytes = null;
              _base64 = null;
              _reply = null;
              _error = null;
              _note.clear();
            }),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppTheme.seed, AppTheme.moss],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.local_florist, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ছবি আপলোড করে উদ্ভিদ শনাক্ত করুন',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'পাতা, কান্ড বা আক্রান্ত অংশের ক্লোজআপ ছবি দিন',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (s.apiKey.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'সেটিংসে Gemini API key যোগ করুন',
                      style: TextStyle(color: scheme.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('গ্যালারি থেকে'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('ক্যামেরা'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_previewBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                _previewBytes!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  height: 240,
                  color: scheme.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Text(_image?.name ?? ''),
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'অতিরিক্ত তথ্য (ঐচ্ছিক) যেমন: কখন থেকে সমস্যা শুরু হয়েছে...',
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _analyze,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_loading ? 'বিশ্লেষণ হচ্ছে...' : 'রোগ শনাক্ত ও চিকিৎসা বলুন'),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ],
          if (_reply != null) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              'ফলাফল',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.dividerColor),
              ),
              child: SelectableText(
                _reply!.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.8,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
