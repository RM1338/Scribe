import 'package:flutter/material.dart';

/// Centres auth content vertically and caps its width on wide screens.
///
/// The column is centred inside a viewport that shrinks when the keyboard
/// opens, so the content drifts upward as the user types and the focused
/// field stays above the keyboard. It stays scrollable, so short screens and
/// large text scales still reach every field.
class AuthLayout extends StatelessWidget {
  final List<Widget> children;

  const AuthLayout({super.key, required this.children});

  static const double _verticalPadding = 24;
  static const double _maxContentWidth = 420;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Subtract the padding the scroll view adds, or the content would
        // always be a little taller than the viewport and scroll by 48px.
        final minHeight = (constraints.maxHeight - _verticalPadding * 2).clamp(
          0.0,
          double.infinity,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: _verticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
