import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

/// Six evenly spaced cells, each holding one digit of the verification code.
///
/// A single transparent [TextField] stretched across the cells does the real
/// input work -- the cells only paint [controller]'s current text. This keeps
/// backspace, paste and autofill working, which per-cell fields with one
/// controller each tend to break.
class OtpCodeField extends StatefulWidget {
  final TextEditingController controller;
  final int length;

  const OtpCodeField({super.key, required this.controller, this.length = 6});

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_repaint);
    _focusNode.addListener(_repaint);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_repaint);
    _focusNode.removeListener(_repaint);
    _focusNode.dispose();
    super.dispose();
  }

  void _repaint() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _Cell(
                  digit: i < text.length ? text[i] : null,
                  // The cell awaiting the next keystroke, once the field has
                  // the keyboard. Sits past the last digit, except when full.
                  active:
                      _focusNode.hasFocus &&
                      i == text.length &&
                      i < widget.length,
                ),
              ),
            ],
          ],
        ),
        // Opacity still hit-tests at 0, so tapping any cell focuses the field.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              showCursor: false,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              // Positioned.fill hands this a tight height. Without isCollapsed
              // the decoration's 48px minimum would overflow the cell row.
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final String? digit;
  final bool active;

  const _Cell({required this.digit, required this.active});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? context.appPrimary : context.appSeparator,
            width: active ? 2 : 1.5,
          ),
        ),
        child: digit != null
            ? Text(
                digit!,
                style: GoogleFonts.manrope(
                  color: context.appTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              )
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.appTextSecondary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
