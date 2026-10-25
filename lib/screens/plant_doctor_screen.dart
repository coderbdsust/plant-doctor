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
  List<PlantHistoryEntry> _recent = const <PlantHistoryEntry>[];

  @override
  void initState() {
    super.initState();
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
                  const SizedBox(height: 8),
                  SelectableText(
                    _reply!.text,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.8,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 9,
            height: 9,
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
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'তাত্ক্ষণিক নিদান',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary.withValues(alpha: 0.9),
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
    final ColorScheme scheme = theme.colorScheme;
    final Color glow = AppTheme.glow;

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // বেস
            Container(
              color: scheme.surfaceContainerLowest,
              child: widget.bytes != null
                  ? Image.memory(
                      widget.bytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          widget.imageName ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : _EmptyFinder(scheme: scheme, theme: theme),
            ),

            // গ্লো কর্নার অ্যাকসেন্ট
            const _CornerAccent(alignment: Alignment.topLeft),
            const _CornerAccent(alignment: Alignment.topRight),
            const _CornerAccent(alignment: Alignment.bottomLeft),
            const _CornerAccent(alignment: Alignment.bottomRight),

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

            // লোডিং ব্যাজ
            if (widget.loading)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'বিশ্লেষণ হচ্ছে...',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFinder extends StatelessWidget {
  const _EmptyFinder({required this.scheme, required this.theme});

  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.center_focus_strong_rounded,
            color: scheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'গাছের ছবি তুলুন বা আপলোড করুন',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'পাতা, কান্ড বা আক্রান্ত অংশের ক্লোজআপ ছবি দিন',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CornerAccent extends StatelessWidget {
  const _CornerAccent({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final Color glow = AppTheme.glow.withValues(alpha: 0.5);

    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? const BorderSide(color: AppTheme.glow, width: 2.2)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? const BorderSide(color: AppTheme.glow, width: 2.2)
                : BorderSide.none,
            left: alignment.x < 0
                ? const BorderSide(color: AppTheme.glow, width: 2.2)
                : BorderSide.none,
            right: alignment.x > 0
                ? const BorderSide(color: AppTheme.glow, width: 2.2)
                : BorderSide.none,
          ),
          boxShadow: <BoxShadow>[BoxShadow(color: glow, blurRadius: 10)],
        ),
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
  });

  final bool loading;
  final bool hasImage;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      children: <Widget>[
        _ToolbarTile(
          scheme: scheme,
          theme: theme,
          icon: Icons.add_photo_alternate_outlined,
          label: 'গ্যালারি',
          onTap: loading ? null : onGallery,
        ),
        const SizedBox(width: 12),
        _ToolbarTile(
          scheme: scheme,
          theme: theme,
          icon: Icons.photo_camera_outlined,
          label: 'ক্যামেরা',
          onTap: loading ? null : onCamera,
        ),
        const SizedBox(width: 14),
        GestureDetector(
          onTap: (!loading && hasImage) ? onScan : null,
          child: AnimatedScale(
            scale: (!loading && hasImage) ? 1.0 : 0.94,
            duration: const Duration(milliseconds: 140),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: AppTheme.accentGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: (loading || hasImage)
                    ? <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.glow.withValues(alpha: 0.55),
                          blurRadius: 26,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerLowest,
                  ),
                  child: loading
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: scheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.center_focus_strong_rounded,
                          size: 26,
                          color: (hasImage
                              ? scheme.primary
                              : scheme.onSurfaceVariant),
                        ),
                ),
              ),
            ),
          ),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.history_rounded, size: 17, color: scheme.primary),
            const SizedBox(width: 7),
            Text(
              'সাম্প্রতিক শনাক্তকরণ',
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
              child: const Text('সাভ করা ফলাফল দেখুন'),
            ),
          ],
        ),
        ...entries.take(3).map((PlantHistoryEntry entry) {
          final String firstLine = entry.resultText.split('\n').first.trim();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => onOpenEntry(entry),
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: scheme.surfaceContainerHighest,
                          child: entry.thumbnailBase64.isEmpty
                              ? Icon(
                                  Icons.spa_outlined,
                                  color: scheme.tertiary,
                                  size: 20,
                                )
                              : Image.memory(
                                  base64Decode(entry.thumbnailBase64),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.spa_outlined,
                                    color: scheme.tertiary,
                                    size: 20,
                                  ),
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              bengaliTimestamp(entry.createdAt),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
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
