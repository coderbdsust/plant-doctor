import 'package:flutter/material.dart';

import '../services/gemini_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/inline_text.dart';

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
    this.citations = const <GeminiCitation>[],
    this.error = false,
  });

  final String text;
  final bool isUser;
  final List<GeminiCitation> citations;
  final bool error;
}

/// Chat with Gemini, optionally grounded with live Google Search results.
class GeminiChatScreen extends StatefulWidget {
  const GeminiChatScreen({
    super.key,
    required this.controller,
    required this.geminiService,
  });

  final AppController controller;
  final GeminiService geminiService;

  @override
  State<GeminiChatScreen> createState() => _GeminiChatScreenState();
}

class _GeminiChatScreenState extends State<GeminiChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = <_ChatMessage>[];
  final List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];

  bool _loading = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String prompt = _input.text.trim();
    if (prompt.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMessage(text: prompt, isUser: true));
      _input.clear();
      _loading = true;
    });
    _scrollToBottom();

    try {
      final GeminiReply reply = await widget.geminiService.chat(
        apiKey: widget.controller.settings.apiKey,
        model: widget.controller.settings.model,
        history: _history,
        prompt: prompt,
        useGoogleSearch: widget.controller.settings.useGoogleSearch,
      );

      _history.add(<String, dynamic>{
        'role': 'user',
        'parts': <Map<String, String>>[
          <String, String>{'text': prompt},
        ],
      });
      _history.add(<String, dynamic>{
        'role': 'model',
        'parts': <Map<String, String>>[
          <String, String>{'text': reply.text},
        ],
      });

      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: reply.text,
            isUser: false,
            citations: reply.citations,
          ),
        );
        _loading = false;
      });
    } on GeminiException catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(text: e.message, isUser: false, error: true),
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'উত্তর পেতে সমস্যা হয়েছে: $e',
            isUser: false,
            error: true,
          ),
        );
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool hasKey = widget.controller.settings.hasApiKey;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[AppTheme.seed, AppTheme.moss],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'জেমিনি সহকারী',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  widget.controller.settings.useGoogleSearch
                      ? 'গুগল সার্চ সহ'
                      : 'শুধু মডেলের জ্ঞান',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'মডেল ও সেটিংস',
            onPressed: () => _showModelSheet(context),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (!hasKey) _ApiKeyBanner(controller: widget.controller),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyChat(
                    hasKey: hasKey,
                    onSuggestion: (String text) {
                      _input.text = text;
                      _send();
                    },
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (BuildContext context, int index) {
                      if (index >= _messages.length) {
                        return const _TypingBubble();
                      }
                      return _Bubble(message: _messages[index]);
                    },
                  ),
          ),
          _Composer(controller: _input, loading: _loading, onSend: _send),
        ],
      ),
    );
  }

  void _showModelSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final AppController controller = widget.controller;
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'মডেল ও সেটিংস',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: controller.settings.model,
                    decoration: const InputDecoration(
                      labelText: 'Gemini মডেল',
                      prefixIcon: Icon(Icons.memory),
                    ),
                    items: <DropdownMenuItem<String>>[
                      for (final model in GeminiService.availableModels)
                        DropdownMenuItem<String>(
                          value: model,
                          child: Text(
                            model,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                    onChanged: (String? value) {
                      if (value == null) return;
                      controller.setModel(value);
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: controller.settings.useGoogleSearch,
                    onChanged: (bool value) {
                      controller.setUseGoogleSearch(value);
                      setModalState(() {});
                    },
                    title: const Text('গুগল সার্চ ব্যবহার করুন'),
                    subtitle: const Text(
                      'উত্তর ওয়েব থেকে যাচাই করা তথ্য দিয়ে দেবে',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ApiKeyBanner extends StatelessWidget {
  const _ApiKeyBanner({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.key, color: scheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Gemini API key প্রয়োজন',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'সেটিংস থেকে আপনার API key যোগ করুন। '
                  'key পাবেন: aistudio.google.com/apikey',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: scheme.onErrorContainer,
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

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.hasKey, required this.onSuggestion});

  final bool hasKey;
  final void Function(String text) onSuggestion;

  static const List<(String, IconData)> _suggestions = <(String, IconData)>[
    ('ছাদে কোন গাছ সহজে লাগানো যায়?', Icons.grass_rounded),
    ('পাতা হলুদ হয়ে গেলে কী করব?', Icons.eco_rounded),
    ('কোকোপিট কী এবং কীভাবে ব্যবহার করব?', Icons.science_rounded),
    ('মিলিবাগ দমনের উপায় কী?', Icons.bug_report_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;

    // Empty-state hero: mint tile with emerald glyph (light) matching the
    // clinical design language.
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      children: <Widget>[
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: isLight
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[Color(0xFFDCFCE7), Color(0xFFF0FDF4)],
                    )
                  : const LinearGradient(
                      colors: <Color>[AppTheme.seed, AppTheme.moss],
                    ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLight ? const Color(0xFFBBF7D0) : Colors.transparent,
              ),
              boxShadow: isLight
                  ? <BoxShadow>[
                      BoxShadow(
                        color: const Color(0x1416A34A),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.auto_awesome,
              color: isLight ? const Color(0xFF15803D) : Colors.white,
              size: 34,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'ছাদ বাগান সহকারী',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'উদ্ভিদ পরিচর্যা, সার, রোগ ও ছাদ বাগান নিয়ে যেকোনো প্রশ্ন করুন। '
          'প্রয়োজনে গুগল সার্চ চালিয়ে সঠিক তথ্য দেবে।',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'এভাবে শুরু করুন',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        for (final (String label, IconData icon) in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: hasKey ? () => onSuggestion(label) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.brightness == Brightness.light
                          ? const Color(0xFFD1E7D8)
                          : scheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.light
                              ? const Color(0xFFF5FBF7)
                              : scheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.brightness == Brightness.light
                                ? const Color(0xFFD6EBD9)
                                : scheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          icon,
                          size: 15,
                          color: theme.brightness == Brightness.light
                              ? const Color(0xFF047857)
                              : scheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: theme.brightness == Brightness.light
                                ? const Color(0xFF0A2E18)
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    final bool isUser = message.isUser;
    final Color bubbleColor = message.error
        ? scheme.errorContainer.withValues(alpha: 0.5)
        : isUser
        ? scheme.primary
        : theme.cardTheme.color!;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.86,
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: (isUser || message.error)
              ? null
              : Border.all(
                  color: isLight
                      ? const Color(0xFFD1E7D8)
                      : scheme.outline.withValues(alpha: 0.5),
                ),
          boxShadow: (isLight && !isUser && !message.error)
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
            InlineText(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                height: 1.7,
                color: message.error
                    ? scheme.onErrorContainer
                    : isUser
                    ? scheme.onPrimary
                    : scheme.onSurface,
              ),
            ),
            if (message.citations.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.light
                      ? const Color(0xFFF5FBF7)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.brightness == Brightness.light
                        ? const Color(0xFFD6EBD9)
                        : scheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.link, size: 13, color: scheme.primary),
                        const SizedBox(width: 5),
                        Text(
                          'সূত্র',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final citation in message.citations.take(6))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '• ${citation.title}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.brightness == Brightness.light
                ? const Color(0xFFD1E7D8)
                : scheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'গুগল সার্চ করছে...',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.loading,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'প্রশ্ন লিখুন...',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: loading ? null : onSend,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
