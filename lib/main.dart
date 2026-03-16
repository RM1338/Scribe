import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'navigation/app_shell.dart';
import 'dart:io' show Platform;
import 'providers/meeting_provider.dart';
import 'providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProxyProvider<SettingsProvider, MeetingProvider>(
          create: (_) => MeetingProvider(),
          update: (_, settings, meeting) => meeting!..attachSettings(settings)..init(),
        ),
      ],
      child: const ScribeApp(),
    ),
  );
}

class ScribeApp extends StatelessWidget {
  const ScribeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;

    final settings = context.watch<SettingsProvider>();
    final themeMode = _getThemeMode(settings.themeMode);

    return MaterialApp(
      title: 'Scribe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 800),
      themeAnimationCurve: Curves.easeInOutCubic,
      builder: isDesktop
          ? (context, child) {
              return Container(
                color: const Color(0xFF0D0D0D),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(48),
                      border: Border.all(color: const Color(0xFF2A2A2A), width: 10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.03),
                          blurRadius: 1,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(38),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 393),
                        child: Stack(
                          children: [
                            // App content with status bar padding
                            MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                padding: const EdgeInsets.only(top: 54),
                              ),
                              child: child!,
                            ),
                            // Dynamic Island
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                margin: const EdgeInsets.only(top: 12),
                                width: 126,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
          : null,
      home: AppShell(key: AppShell.shellKey),
    );
  }

  ThemeMode _getThemeMode(ThemeModeOption option) {
    switch (option) {
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
      case ThemeModeOption.system:
        return ThemeMode.system;
    }
  }
}
