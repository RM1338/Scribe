import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'navigation/app_shell.dart';
import 'dart:io' show Platform;

void main() {
  runApp(const MeetNoteApp());
}

class MeetNoteApp extends StatelessWidget {
  const MeetNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;

    return MaterialApp(
      title: 'MeetNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
      home: const AppShell(),
    );
  }
}
