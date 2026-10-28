import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/diagnosis.dart';
import '../services/gemini_service.dart';
import '../services/plant_history_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/diagnosis_report.dart';

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
  List<PlantHistoryEntry> _recent = const <PlantHistoryEntry>[];
  String _reportId = '#PLNT-8842';

  /// Gemini may return structured JSON — render the clinical report when it
  /// does, and fall back to plain text otherwise.
  DiagnosisReport? get _parsedReport {
    final GeminiReply? reply = _reply;
    if (reply == null) return null;
    return DiagnosisReport.tryParse(reply.text);
  }

  @override
  void initState() {
    super.initState();
    // Web-প্রিভিউ হ্যাচ: /?demo দিলে মক JSON দিয়ে ক্লিনিক্যাল রিপোর্ট দেখা যায়।
    if (kIsWeb && Uri.base.queryParameters.containsKey('demo')) {
      _reply = GeminiReply(text: _demoReportJson);
    }
    _reloadRecent();
  }

  Future<void> _reloadRecent() async {
    final List<PlantHistoryEntry> entries = await _history.load();
    if (mounted) {
      setState(() => _recent = entries);
    }
  }

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
    await _reloadRecent();
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
          'উদ্ভিদ ডাক্তার → Permissions থেকে Camera ও Photos অনুমতি চালু করুন।';
    }
    if (raw.contains('activity') || raw.contains('unavailable')) {
      return 'ফোনে উপযুক্ত ক্যামেরা/গ্যালারি অ্যাপ পাওয়া যায়নি। '
          'গ্যালারি থেকে চেষ্টা করুন।';
    }
    return 'ছবি নির্বাচন করা যায়নি: $e';
  }

  Future<void> _analyze() async {
    if (_base64 == null || !_hasKey()) {
      setState(
        () => _error = 'Gemini API key সেটিংসে যোগ করুন, তারপর বিশ্লেষণ করুন।',
      );
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
      setState(() {
        _reply = reply;
        // ডিজাইনের #PLNT-8842 স্টাইলে প্রতি রিপোর্টে নতুন আইডি।
        _reportId = '#PLNT-${1000 + math.Random().nextInt(9000)}';
      });
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
      return 'ফোনের মেমোরি কম পড়েছে (RAM)। অন্য অ্যাপ বন্ধ করে আবার চেষ্টা করুন, '
          'অথবা ছোট ছবি (০.৫-১ MB) দিয়ে চেষ্টা করুন।';
    }
    if (e is FormatException) {
      return 'সার্ভার থেকে অপ্রত্যাশিত উত্তর এসেছে। কিছুক্ষণ পর আবার চেষ্টা করুন।';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'উদ্ভিদ ডাক্তার',
              style: theme.appBarTheme.titleTextStyle?.copyWith(fontSize: 17),
            ),
            Text(
              'উদ্ভিদ রোগ নির্ণয় ক্যামেরা',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'সেভ করা ফলাফল',
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          _StatusPill(model: s.model),
          const SizedBox(height: 12),
          if (s.apiKey.isEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.key_off_rounded, color: scheme.onErrorContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'সেটিংসে Gemini API key যোগ করুন',
                      style: TextStyle(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          _Viewfinder(
            bytes: _previewBytes,
            imageName: _image?.name,
            loading: _loading,
          ),
          const SizedBox(height: 10),
          _ScanToolbar(
            loading: _loading,
            hasImage: _base64 != null,
            onGallery: () => _pick(ImageSource.gallery),
            onCamera: () => _pick(ImageSource.camera),
            onScan: _analyze,
            onHistory: _openHistory,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText:
                  'অতিরিক্ত তথ্য (ঐচ্ছিক) যেমন: কখন থেকে সমস্যা শুরু হয়েছে...',
              prefixIcon: Icon(Icons.edit_note_outlined),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
          if (_reply != null) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              'ফলাফল',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (_parsedReport != null)
              DiagnosisReportHeader(reportId: _reportId, rawText: _reply!.text)
            else ...<Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.psychology_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'AI নির্ণয় • ${s.model}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (_parsedReport != null)
              DiagnosisReportView(
                report: _parsedReport!,
                imageBytes: _previewBytes,
                reportId: _reportId,
                rawText: _reply!.text,
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outline),
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
                    _lastSaveOk!
                        ? Icons.bookmark_added_rounded
                        : Icons.error_outline,
                    size: 16,
                    color: _lastSaveOk!
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _lastSaveOk!
                        ? 'ফলাফল বুকমার্কে সেভ হয়েছে'
                        : 'ফলাফল সেভ করা গেল না',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _lastSaveOk! ? scheme.primary : theme.hintColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openHistory,
                    icon: const Icon(Icons.history_rounded, size: 16),
                    label: const Text('সেভ করা ফলাফল দেখুন'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ],
          if (_recent.isNotEmpty) ...<Widget>[
            const SizedBox(height: 22),
            _RecentScans(
              entries: _recent,
              onOpenAll: _openHistory,
              onOpenEntry: (PlantHistoryEntry entry) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _FullResultScreen(text: entry.resultText),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// ── স্ট্যাটাস পিল ──────────────────────────────────────────────────────
/// ({model} সক্রিয় • তাত্ক্ষণিক নিদান) — design: "Gemini Vision সক্রিয়"।
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.model});

  final String model;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    // Design: white pill, glowing emerald dot, auto_awesome lead, and an
    // emerald-100 accuracy badge on the right.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white
            : scheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isLight
              ? const Color(0xFFD1E7D8)
              : scheme.outline.withValues(alpha: 0.5),
        ),
        boxShadow: isLight
            ? const <BoxShadow>[
                BoxShadow(color: Color(0x0A0D3823), blurRadius: 6),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppTheme.glow.withValues(alpha: 0.8),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '$model সক্রিয়',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isLight ? const Color(0xFF0F2E1E) : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isLight
                  ? const Color(0xFFDCFCE7)
                  : scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isLight
                    ? const Color(0xFFBBF7D0)
                    : scheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              'তাত্ক্ষণিক নিদান',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isLight ? const Color(0xFF065F46) : scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── ভিউফাইন্ডার (design: 4:5 rounded-3xl + গ্লো কর্নার + স্ক্যান-লাইন) ──
class _Viewfinder extends StatefulWidget {
  const _Viewfinder({
    required this.bytes,
    this.imageName,
    required this.loading,
  });

  final Uint8List? bytes;
  final String? imageName;
  final bool loading;

  @override
  State<_Viewfinder> createState() => _ViewfinderState();
}

class _ViewfinderState extends State<_Viewfinder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  late final Animation<double> _scan = Tween<double>(
    begin: 0.10,
    end: 0.88,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color glow = AppTheme.glow;

    // Design: rounded-3xl black canvas with a centered hairline reticle,
    // HUD tracking chip (top) and focus guidance chip (bottom).
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x1E0D3823)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x140D3823),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // বেস — ক্যামেরা ফিডের মতো গাঢ় ক্যানভাস
              Container(color: const Color(0xFF0A0F0D)),
              if (widget.bytes != null)
                Positioned.fill(
                  child: Image.memory(
                    widget.bytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        widget.imageName ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0x88FFFFFF),
                        ),
                      ),
                    ),
                  ),
                )
              else
                const _EmptyFinder(),

              // হেয়ারলাইন রেটিকেল — ৪ কোনায় সবুজ ব্র্যাকেট
              const Center(child: _Reticle()),

              // স্ক্যান-লাইন (লোডিং অবস্থায়)
              if (widget.loading)
                AnimatedBuilder(
                  animation: _scan,
                  builder: (BuildContext context, Widget? child) {
                    return Align(
                      alignment: Alignment(0, _scan.value * 2 - 1),
                      child: child,
                    );
                  },
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          glow.withValues(alpha: 0.0),
                          glow,
                          glow.withValues(alpha: 0.0),
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: glow.withValues(alpha: 0.9),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),

              // উপরের HUD: ট্র্যাকিং চিপ
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x73000000), // black/45
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0x33FFFFFF)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      widget.loading
                          ? SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                color: const Color(0xFF34D399),
                              ),
                            )
                          : Icon(
                              Icons.sync_rounded,
                              size: 13,
                              color: const Color(0xFF34D399),
                            ),
                      const SizedBox(width: 6),
                      Text(
                        widget.loading
                            ? 'বিশ্লেষণ হচ্ছে...'
                            : 'পাতার রোগ ট্র্যাক মোড',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // নিচের ফোকাস নির্দেশনা চিপ
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xBF000000), // black/75
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x1AFFFFFF)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.center_focus_strong_rounded,
                        size: 17,
                        color: const Color(0xFF34D399),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.bytes == null
                              ? 'গাছের ছবি তুলুন বা আপলোড করুন — আক্রান্ত পাতা কেন্দ্রে রাখুন।'
                              : 'আক্রান্ত পাতা বা কুঁড়িকে ফ্রেমের কেন্দ্রস্থলে স্থাপন করুন।',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: Color(0xE6FFFFFF), // white/90
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centered 4-bracket reticle + hairline guides, per the scanner design.
class _Reticle extends StatelessWidget {
  const _Reticle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 218,
      height: 218,
      child: Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.topLeft,
            child: _bracket(
              border: const Border(
                top: BorderSide(color: Color(0xFF22C55E), width: 2.6),
                left: BorderSide(color: Color(0xFF22C55E), width: 2.6),
              ),
              radius: const BorderRadius.only(topLeft: Radius.circular(8)),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: _bracket(
              border: const Border(
                top: BorderSide(color: Color(0xFF22C55E), width: 2.6),
                right: BorderSide(color: Color(0xFF22C55E), width: 2.6),
              ),
              radius: const BorderRadius.only(topRight: Radius.circular(8)),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: _bracket(
              border: const Border(
                bottom: BorderSide(color: Color(0xFF22C55E), width: 2.6),
                left: BorderSide(color: Color(0xFF22C55E), width: 2.6),
              ),
              radius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: _bracket(
              border: const Border(
                bottom: BorderSide(color: Color(0xFF22C55E), width: 2.6),
                right: BorderSide(color: Color(0xFF22C55E), width: 2.6),
              ),
              radius: const BorderRadius.only(bottomRight: Radius.circular(8)),
            ),
          ),
          // কেন্দ্র ফোকাস ডট
          Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF22C55E),
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Color(0x5922C55E), blurRadius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bracket({required Border border, required BorderRadius radius}) {
    // No outer glow here: the box shadow would bleed through the
    // transparent interior and make the brackets look filled.
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(border: border, borderRadius: radius),
    );
  }
}

class _EmptyFinder extends StatelessWidget {
  const _EmptyFinder();

  @override
  Widget build(BuildContext context) {
    // The viewfinder canvas is always dark (camera feed look), so the
    // empty state uses fixed light-on-dark colors.
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0x1A22C55E),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: Color(0xFF34D399),
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'গাছের ছবি তুলুন বা আপলোড করুন',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'পাতা, কান্ড বা আক্রান্ত অংশের ক্লোজআপ ছবি দিন',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFFFFFFFF).withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// ── নিচের টুলবার + কেন্দ্রীয় স্ক্যান FAB ─────────────────────────────
class _ScanToolbar extends StatelessWidget {
  const _ScanToolbar({
    required this.loading,
    required this.hasImage,
    required this.onGallery,
    required this.onCamera,
    required this.onScan,
    required this.onHistory,
  });

  final bool loading;
  final bool hasImage;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onScan;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    // Design: [gallery] [camera] ( shutter ) [history] — square icon tiles
    // with labels below, glowing emerald shutter in the middle.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _ToolbarTile(
          scheme: scheme,
          theme: theme,
          icon: Icons.add_photo_alternate_outlined,
          label: 'গ্যালারি',
          onTap: loading ? null : onGallery,
        ),
        const SizedBox(width: 10),
        _ToolbarTile(
          scheme: scheme,
          theme: theme,
          icon: Icons.photo_camera_outlined,
          label: 'ক্যামেরা',
          onTap: loading ? null : onCamera,
        ),
        Expanded(
          child: GestureDetector(
            onTap: (!loading && hasImage) ? onScan : null,
            child: Column(
              children: <Widget>[
                AnimatedScale(
                  scale: (!loading && hasImage) ? 1.0 : 0.94,
                  duration: const Duration(milliseconds: 140),
                  child: Container(
                    width: 62,
                    height: 62,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF16A34A), Color(0xFF15803D)],
                      ),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: (loading || hasImage)
                          ? <BoxShadow>[
                              BoxShadow(
                                color: const Color(0x7316A34A),
                                blurRadius: 26,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: loading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Color(0xFFFFFFFF),
                              ),
                            )
                          : Icon(
                              Icons.center_focus_strong_rounded,
                              size: 24,
                              color: (hasImage
                                  ? const Color(0xFFFFFFFF)
                                  : const Color(0xB3FFFFFF)),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'স্ক্যান করুন',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _ToolbarTile(
          scheme: scheme,
          theme: theme,
          icon: Icons.history_rounded,
          label: 'হিস্ট্রি',
          onTap: onHistory,
        ),
      ],
    );
  }
}

class _ToolbarTile extends StatelessWidget {
  const _ToolbarTile({
    required this.scheme,
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final ColorScheme scheme;
  final ThemeData theme;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    // Design: rounded-2xl bordered tile with an emerald icon + tiny label.
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isLight ? Colors.white : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isLight
                      ? const Color(0xFFD1E7D8)
                      : scheme.outline.withValues(alpha: 0.5),
                ),
                boxShadow: isLight
                    ? const <BoxShadow>[
                        BoxShadow(color: Color(0x0A0D3823), blurRadius: 5),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 21,
                color: isLight ? const Color(0xFF047857) : scheme.primary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isLight
                    ? const Color(0xFF4A6B57)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Human-friendly one-line title from a saved result (parsed JSON or plain
/// text): "গাছের নাম — রোগ/পোকা", e.g. "জাবা ফুল — পাতায় ছত্রাক"।
String _entryDisplayTitle(PlantHistoryEntry entry) {
  final DiagnosisReport? report = DiagnosisReport.tryParse(entry.resultText);
  if (report != null) {
    final List<String> parts = <String>[
      if (report.plantName.isNotEmpty) report.plantName,
      if (report.diseaseTitle.isNotEmpty) report.diseaseTitle,
    ];
    final String title = parts.join(' — ');
    if (title.isNotEmpty) return title;
  }
  // Plain-text fallback: first meaningful line (brace prefixes removed).
  final String firstLine = entry.resultText
      .split('\n')
      .map((String line) => line.trim())
      .firstWhere((String line) => line.isNotEmpty && line != '{' && line != '}',
          orElse: () => '');
  return firstLine.replaceFirst(RegExp(r'^[\{,\s]*'), '').trim();
}

/// Short readable snippet for the history card list body.
String _entryDisplaySnippet(PlantHistoryEntry entry, {int maxChars = 140}) {
  final DiagnosisReport? report = DiagnosisReport.tryParse(entry.resultText);
  String text = '';
  if (report != null) {
    text = report.observations.isNotEmpty
        ? report.observations
        : (report.caution.isNotEmpty
            ? report.caution
            : (report.plantName.isNotEmpty || report.diseaseTitle.isNotEmpty
                ? <String>[
                    if (report.plantName.isNotEmpty) report.plantName,
                    if (report.diseaseTitle.isNotEmpty) report.diseaseTitle,
                  ].join(' — ')
                : ''));
  }
  if (text.isEmpty) {
    // Strip JSON punctuation so raw output never reads like code.
    text = entry.resultText
        .replaceAll(RegExp(r'[{}\[\]"]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  if (text.length > maxChars) text = '${text.substring(0, maxChars)}…';
  return text;
}

/// ── সাম্প্রতিক শনাক্তকরণ (design: recent scans history) ──────────────
class _RecentScans extends StatelessWidget {
  const _RecentScans({
    required this.entries,
    required this.onOpenAll,
    required this.onOpenEntry,
  });

  final List<PlantHistoryEntry> entries;
  final VoidCallback onOpenAll;
  final void Function(PlantHistoryEntry) onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.history_rounded, size: 17, color: scheme.primary),
            const SizedBox(width: 7),
            Text(
              'পূর্ববর্তী স্ক্যান হিস্ট্রি',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: onOpenAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('সব দেখুন'),
            ),
          ],
        ),
        ...entries.take(3).map((PlantHistoryEntry entry) {
          final String firstLine =
              _entryDisplayTitle(entry);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onOpenEntry(entry),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                // Design: white row card with sage border + chevron.
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLight
                        ? const Color(0xFFD1E7DD)
                        : scheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isLight
                                ? const Color(0xFFD6EBD9)
                                : scheme.outline.withValues(alpha: 0.4),
                          ),
                          color: scheme.surfaceContainerHighest,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: entry.thumbnailBase64.isEmpty
                            ? Icon(
                                Icons.spa_outlined,
                                color: isLight
                                    ? const Color(0xFF047857)
                                    : scheme.tertiary,
                                size: 20,
                              )
                            : Image.memory(
                                base64Decode(entry.thumbnailBase64),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.spa_outlined,
                                  color: isLight
                                      ? const Color(0xFF047857)
                                      : scheme.tertiary,
                                  size: 20,
                                ),
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              firstLine.isEmpty ? 'শনাক্তকরণ ফলাফল' : firstLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isLight
                                    ? const Color(0xFF0A2E18)
                                    : scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bengaliTimestamp(entry.createdAt),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: isLight
                                    ? const Color(0xFF4A6B57)
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

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
        title: const Text('সেভ করা ফলাফল'),
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
                  Text('এখনো কোনো ফলাফল সেভ হয়নি'),
                  SizedBox(height: 4),
                  Text('উদ্ভিদ ডাক্তারে বিশ্লেষণ করলে ফলাফল এখানে জমা হবে'),
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
    final String snippet = _entryDisplaySnippet(entry);

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
                      if (value == 'delete') {
                        onDelete();
                      }
                      if (value == 'full') {
                        _showFullResult(context, entry.resultText);
                      }
                    },
                    itemBuilder: (BuildContext menuContext) =>
                        <PopupMenuEntry<String>>[
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
      MaterialPageRoute<void>(builder: (_) => _FullResultScreen(text: text)),
    );
  }
}

/// Web-প্রিভিউ হ্যাচ-এর মক ডায়াগনোসিস (ডিজাইনের মতো সামগ্রী)।
const String _demoReportJson =
    '{"plantName":"লেবু গাছ","diseaseTitle":"পাতায় ছত্রাক ও ক্লোরোসিস",'
    '"latinName":"Fungal Leaf Blight & Micro-nutrient Deficiency",'
    '"confidencePercent":97.8,'
    '"observations":"পাতায় ছোট ছোট কালো দাগ, পাতার কিনারা পুড়ে যাওয়া ভাব ও '
    'অনুখাদ্যের ঘাটতি পরিলক্ষিত হয়েছে।",'
    '"caution":"গাছের গোড়ায় অতিরিক্ত পানি জমতে দেবেন না, ড্রেনেজ ছিদ্র ৩-৪টি '
    'নিশ্চিত করুন। টবের গোড়া স্যাঁতস্যাঁতে থাকলে ছত্রাক দ্রুত বংশবৃদ্ধি করে।",'
    '"duration":"২৫ দিন চক্র","sprayInterval":"১৫ দিনে ১ বার",'
    '"cureRate":"৯২% নিরাময় হার",'
    '"steps":['
    '{"title":"ধাপ ১: ফাঙ্গিসাইড স্প্রে","badge":"ছত্রাক দমন",'
    '"medicine":"ম্যানসার + নিম তেল মিশ্রণ",'
    '"howToDo":"১ চামচ নিমতেল + ১ চামচ ম্যানসার + ২ টাকার শ্যাম্পু, ২ লিটার পানিতে '
    'মিশিয়ে স্প্রে করুন।","dosage":"১ চামচ / ২ লিটার","frequency":"১৫ দিনে ১ বার",'
    '"tip":"পাতার উভয় পিঠে স্প্রে করুন","timing":"বিকালে প্রযোজ্য"},'
    '{"title":"ধাপ ২: অনুখাদ্য ও সার প্রয়োগ","badge":"পুষ্টি ঘাটতি পূরণ",'
    '"medicine":"ইউরিয়া + জিংক সালফেট",'
    '"howToDo":"হাফ ড্রাম সাইজের টবে ৪ মুঠ, ছোট টবে ২ মুঠ করে প্রয়োগ করুন।",'
    '"dosage":"৪ মুঠ / টব","frequency":"২৫ দিনে ১ বার",'
    '"tip":"টবের কিনারা ঘেঁষে গোল নালা কেটে দিন","timing":"সকালে প্রযোজ্য"},'
    '{"title":"ধাপ ৩: প্রতিরোধমূলক যত্ন","badge":"প্রতিরোধ",'
    '"medicine":"ট্রাইকোডার্মা পাউডার",'
    '"howToDo":"গোড়ার মাটিতে মেশান ও পানি দেওয়ার রুটিন ঠিক রাখুন।",'
    '"dosage":"১ গ্রাম / টব","frequency":"মাসে ১ বার",'
    '"tip":"আক্রান্ত পাতা তুলে ফেলুন","timing":""}'
    ']}';

class _FullResultScreen extends StatelessWidget {
  const _FullResultScreen({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DiagnosisReport? report = DiagnosisReport.tryParse(text);

    return Scaffold(
      appBar: AppBar(title: const Text('সেভ করা ফলাফল')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          if (report != null) ...<Widget>[
            DiagnosisReportHeader(reportId: '', rawText: text),
            const SizedBox(height: 12),
            DiagnosisReportView(report: report, rawText: text),
          ] else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outline),
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
