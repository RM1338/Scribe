import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/language.dart';
import '../theme/app_theme.dart';

/// A searchable language list in a bottom sheet.
///
/// Returns the selected [AppLanguage], or null if dismissed. When
/// [includeAutoDetect] is set, choosing "Auto-detect" also returns null -- so
/// callers must distinguish the two via [showLanguagePicker]'s bool result
/// where it matters. Translation targets can't be auto-detected, so the
/// transcript view leaves it off.
Future<AppLanguage?> showLanguagePicker(
  BuildContext context, {
  required String title,
  String? selectedCode,
  bool includeAutoDetect = false,
  VoidCallback? onAutoDetect,
}) {
  return showModalBottomSheet<AppLanguage>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _LanguagePickerSheet(
      title: title,
      selectedCode: selectedCode,
      includeAutoDetect: includeAutoDetect,
      onAutoDetect: onAutoDetect,
    ),
  );
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({
    required this.title,
    required this.selectedCode,
    required this.includeAutoDetect,
    required this.onAutoDetect,
  });

  final String title;
  final String? selectedCode;
  final bool includeAutoDetect;
  final VoidCallback? onAutoDetect;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  final _searchController = TextEditingController();
  List<AppLanguage> _results = AppLanguage.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _results = AppLanguage.search(query));
  }

  @override
  Widget build(BuildContext context) {
    // Sized against the sheet's own space, and lifted clear of the keyboard the
    // search box summons.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appSeparator,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(widget.title, style: context.dialogTitle),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: GoogleFonts.manrope(color: context.appTextPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search languages',
                    hintStyle: GoogleFonts.manrope(
                      color: context.appTextSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: context.appTextSecondary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: context.appBackground,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (widget.includeAutoDetect &&
                        _searchController.text.isEmpty)
                      _Row(
                        title: AppLanguage.autoDetect,
                        subtitle: 'Let Scribe identify the language',
                        selected: widget.selectedCode == null,
                        onTap: () {
                          widget.onAutoDetect?.call();
                          Navigator.pop(context);
                        },
                      ),
                    for (final language in _results)
                      _Row(
                        title: language.name,
                        subtitle: language.nativeName == language.name
                            ? null
                            : language.nativeName,
                        selected: widget.selectedCode == language.code,
                        onTap: () => Navigator.pop(context, language),
                      ),
                    if (_results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No languages match "${_searchController.text}"',
                            style: GoogleFonts.manrope(
                              color: context.appTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      color: selected
                          ? context.appPrimary
                          : context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.manrope(
                        color: context.appTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, color: context.appPrimary, size: 20),
          ],
        ),
      ),
    );
  }
}
