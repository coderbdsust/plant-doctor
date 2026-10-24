import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/gemini_service.dart';
import '../services/plant_history_service.dart';
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
  final PlantHistoryService _history = const PlantHistoryService();
  bool? _lastSaveOk;

  Future<void> _openHistory() async {
    final List<PlantHistoryEntry> entries = await _history.load();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlantHistoryScreen(
          controller: widget.controller,
          initialEntries: entries,
        ),
      ),
    );
  }

  /// Auto-saves every successful diagnosis so the user never loses a result.
  Future<void> _saveToHistory(GeminiReply reply) async {
    final Uint8List? bytes = _previewBytes;
    if (bytes == null) return;
    final PlantHistoryEntry? saved = await _history.save(
      photoBytes: bytes,
      resultText: reply.text,
      model: widget.controller.settings.model,
    );
    if (!mounted) return;
    setState(() => _lastSaveOk = saved != null);
  }

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
          'গাছের ডাক্তার → Permissions থেকে Camera ও Photos অনুমতি চালু করুন।';
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
      await _saveToHistory(reply);
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
            tooltip: 'সাভ করা ফলাফল',
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'রিসেট',
            onPressed: () => setState(() {
              _image = null;
              _previewBytes = null;
              _base64 = null;
              _reply = null;
              _error = null;
              _lastSaveOk = null;
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
            if (_lastSaveOk != null) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(
                    _lastSaveOk! ? Icons.bookmark_added_rounded : Icons.error_outline,
                    size: 16,
                    color: _lastSaveOk!
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _lastSaveOk!
                        ? 'ফলাফল বুকমার্কে সাভ হয়েছে'
                        : 'ফলাফল সাভ করা গেল না',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _lastSaveOk! ? scheme.primary : theme.hintColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openHistory,
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('সাভ করা ফলাফল দেখুন'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Shows every saved diagnosis (thumbnail + snippet + full result).
class PlantHistoryScreen extends StatefulWidget {
  const PlantHistoryScreen({
    super.key,
    required this.controller,
    required this.initialEntries,
  });

  final AppController controller;
  final List<PlantHistoryEntry> initialEntries;

  @override
  State<PlantHistoryScreen> createState() => _PlantHistoryScreenState();
}

class _PlantHistoryScreenState extends State<PlantHistoryScreen> {
  final PlantHistoryService _history = const PlantHistoryService();
  late List<PlantHistoryEntry> _entries = widget.initialEntries;

  Future<void> _reload() async {
    final List<PlantHistoryEntry> entries = await _history.load();
    if (!mounted) return;
    setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('সাভ করা ফলাফল'),
        actions: <Widget>[
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: 'সব মুছুন',
              onPressed: () async {
                final bool? ok = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext dialogContext) => AlertDialog(
                    title: const Text('সব ফলাফল মুছে ফেলবেন?'),
                    content: const Text('এটি ফেরানো যাবে না।'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('বাতিল'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onError,
                        ),
                        child: const Text('মুছুন'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await _history.clear();
                  await _reload();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.history_toggle_off_rounded, size: 48),
                  SizedBox(height: 12),
                  Text('এখনো কোনো ফলাফল সাভ হয়নি'),
                  SizedBox(height: 4),
                  Text('গাছের ডাক্তারে বিশ্লেষণ করলে ফলাফল এখানে জমা হবে'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                final PlantHistoryEntry entry = _entries[index];
                return _HistoryCard(
                  entry: entry,
                  onDelete: () async {
                    await _history.remove(entry.id);
                    await _reload();
                  },
                );
              },
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.onDelete});

  final PlantHistoryEntry entry;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String snippet = entry.resultText.length > 140
        ? '${entry.resultText.substring(0, 140)}…'
        : entry.resultText;

    return Material(
      color: theme.cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: InkWell(
        onTap: () => _showFullResult(context, entry.resultText),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 64,
                  height: 64,
                  color: scheme.surfaceContainerHighest,
                  child: entry.thumbnailBase64.isEmpty
                      ? const Icon(Icons.image_outlined)
                      : Image.memory(
                          base64Decode(entry.thumbnailBase64),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.image_outlined),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.schedule, size: 13, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          bengaliTimestamp(entry.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snippet,
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.55,
                        color: scheme.onSurface,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (String value) {
                      if (value == 'delete') onDelete();
                      if (value == 'full') _showFullResult(context, entry.resultText);
                    },
                    itemBuilder: (BuildContext menuContext) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'full',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.visibility_outlined, size: 17),
                            SizedBox(width: 8),
                            Text('পুরো ফলাফল দেখুন'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.delete_outline, size: 17),
                            SizedBox(width: 8),
                            Text('মুছুন'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullResult(BuildContext context, String text) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullResultScreen(text: text),
      ),
    );
  }
}

class _FullResultScreen extends StatelessWidget {
  const _FullResultScreen({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('সাভ করা ফলাফল')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.dividerColor),
            ),
            child: SelectableText(
              text,
              style: TextStyle(
                fontSize: 15,
                height: 1.8,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
