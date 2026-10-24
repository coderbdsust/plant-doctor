import 'package:flutter/material.dart';

import '../services/gemini_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _apiKey;
  bool _obscure = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _apiKey = TextEditingController(text: widget.controller.settings.apiKey);
  }

  @override
  void dispose() {
    _apiKey.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppController controller = widget.controller;

    return Scaffold(
      appBar: AppBar(title: const Text('সেটিংস')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          _SectionTitle(
            icon: Icons.key_outlined,
            title: 'Gemini API key',
            subtitle: 'aistudio.google.com/apikey থেকে key নিন',
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _apiKey,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'AIza...',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  IconButton(
                    tooltip: 'দেখান/লুকান',
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  IconButton(
                    tooltip: 'সেভ করুন',
                    icon: Icon(
                      _copied ? Icons.check_circle : Icons.save_outlined,
                      color: _copied ? scheme.primary : null,
                    ),
                    onPressed: () async {
                      final ScaffoldMessengerState messenger =
                          ScaffoldMessenger.of(context);
                      await controller.setApiKey(_apiKey.text);
                      if (!mounted) return;
                      setState(() => _copied = true);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('API key সংরক্ষিত হয়েছে')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.memory,
            title: 'মডেল',
            subtitle: 'জেমিনি মডেল নির্বাচন করুন',
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: controller.settings.model,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.auto_awesome),
            ),
            items: <DropdownMenuItem<String>>[
              for (final model in GeminiService.availableModels)
                DropdownMenuItem<String>(
                  value: model,
                  child: Text(model, style: const TextStyle(fontSize: 14)),
                ),
            ],
            onChanged: (String? value) {
              if (value != null) controller.setModel(value);
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: controller.settings.useGoogleSearch,
            onChanged: (bool value) => controller.setUseGoogleSearch(value),
            title: const Text('গুগল সার্ক ব্যবহার করুন'),
            subtitle: const Text(
              'জেমিনি উত্তর দেওয়ার আগে ওয়েব থেকে তথ্য খুঁজবে',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.brightness_6_outlined,
            title: 'অ্যাপ থিম',
            subtitle: 'সিস্টেম, লাইট বা ডার্ক',
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: 'system',
                label: Text('সিস্টেম'),
                icon: Icon(Icons.brightness_auto, size: 17),
              ),
              ButtonSegment<String>(
                value: 'light',
                label: Text('লাইট'),
                icon: Icon(Icons.light_mode_outlined, size: 17),
              ),
              ButtonSegment<String>(
                value: 'dark',
                label: Text('ডার্ক'),
                icon: Icon(Icons.dark_mode_outlined, size: 17),
              ),
            ],
            selected: <String>{controller.settings.themeMode},
            onSelectionChanged: (Set<String> value) =>
                controller.setThemeMode(value.first),
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            icon: Icons.text_fields,
            title: 'টেক্সট সাইজ',
            subtitle: 'পড়ার সময় কত বড় লেখা দেখবেন',
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(Icons.text_fields, size: 16),
              Expanded(
                child: Slider(
                  value: controller.settings.fontScale,
                  min: 0.85,
                  max: 1.4,
                  divisions: 11,
                  label: '${(controller.settings.fontScale * 100).round()}%',
                  onChanged: controller.setFontScale,
                ),
              ),
              Text('${(controller.settings.fontScale * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.park, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'গাছের ডাক্তার',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ছাদ বাগান ও উদ্ভিদ পরিচর্যা সম্পূর্ণ গাইডলাইন — '
                        'ধাপে ধাপে পড়ুন, খুঁজুন, এবং AI সহায়কের সাহায্য নিন।',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.6,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.seed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppTheme.seed),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
