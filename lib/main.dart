import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/reader_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'services/settings_service.dart';
import 'state/app_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/modern_motion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final SettingsService settings = await SettingsService.load();
  final AppController controller = AppController(settings);
  runApp(NogorOronnoApp(controller: controller));
}

class NogorOronnoApp extends StatefulWidget {
  const NogorOronnoApp({super.key, required this.controller});

  final AppController controller;

  @override
  State<NogorOronnoApp> createState() => _NogorOronnoAppState();
}

class _NogorOronnoAppState extends State<NogorOronnoApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final String mode = widget.controller.settings.themeMode;
        final ThemeMode themeMode = switch (mode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };

        return MaterialApp(
          title: 'উদ্ভিদ ডাক্তার',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: HomeShell(
            controller: widget.controller,
          ),
        );
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _openReader(int chapterIndex, {int step = 0}) {
    final chapters = widget.controller.chapters;
    if (chapterIndex < 0 || chapterIndex >= chapters.length) return;
    Navigator.of(context).push(
      FadeSlideRoute<void>(
        builder: (_) => ReaderScreen(
          controller: widget.controller,
          chapter: chapters[chapterIndex],
          initialStep: step,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      FadeSlideRoute<void>(
        builder: (_) => SettingsScreen(controller: widget.controller),
      ),
    );
  }

  /// Resumes reading where the user left off.
  void _continueReading() {
    final chapters = widget.controller.chapters;
    if (chapters.isEmpty) return;

    final int saved = widget.controller.settings.lastStepIndex;
    int chapterIndex = 0;
    int step = 0;
    int remaining = saved;

    for (int i = 0; i < chapters.length; i++) {
      if (remaining < chapters[i].steps.length) {
        chapterIndex = i;
        step = remaining;
        break;
      }
      remaining -= chapters[i].steps.length;
      chapterIndex = i;
      step = chapters[i].steps.length - 1;
    }

    _openReader(chapterIndex, step: step);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      HomeScreen(
        controller: widget.controller,
        onOpenChapter: (chapter) => _openReader(chapter.index),
        onContinueReading: _continueReading,
        onOpenSearch: () => setState(() => _tab = 1),
        onOpenSettings: _openSettings,
      ),
      SearchScreen(
        controller: widget.controller,
        onOpenStep: (chapter, step) =>
            _openReader(chapter.index, step: step.stepIndex),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (int index) => setState(() => _tab = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'হোম',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search_rounded),
            label: 'সার্চ',
          ),
        ],
      ),
    );
  }
}
