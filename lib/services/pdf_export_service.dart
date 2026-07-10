import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/language.dart';
import '../models/meeting.dart';

/// Renders a meeting as a minutes-style PDF.
///
/// ## Fonts
///
/// The PDF built-in fonts are Helvetica-family Type1 faces with no glyphs
/// outside Latin-1. Handed Devanagari, Tamil, Arabic or CJK they emit blank
/// boxes rather than failing, so a Hindi export would look broken with no error
/// anywhere. Every document therefore embeds a Noto face chosen for the script
/// it is about to render, with plain Noto Sans as a fallback for the Latin bits
/// (speaker labels, timestamps) that survive translation.
///
/// [PdfGoogleFonts] fetches each face over the network once and caches it on
/// disk, so the first export of a new script needs connectivity and subsequent
/// ones do not. Latin-only exports need no network at all.
class PdfExportService {
  /// Scripts whose text runs right to left.
  static const _rtlCodes = {'ar', 'ur'};

  /// Loader per language code. Absent codes use Latin Noto Sans, which already
  /// covers every Latin-script language in [AppLanguage.all] plus Cyrillic.
  static final Map<String, Future<pw.Font> Function()> _scriptRegular = {
    'hi': PdfGoogleFonts.notoSansDevanagariRegular,
    'mr': PdfGoogleFonts.notoSansDevanagariRegular,
    'ta': PdfGoogleFonts.notoSansTamilRegular,
    'te': PdfGoogleFonts.notoSansTeluguRegular,
    'kn': PdfGoogleFonts.notoSansKannadaRegular,
    'ml': PdfGoogleFonts.notoSansMalayalamRegular,
    'bn': PdfGoogleFonts.notoSansBengaliRegular,
    'gu': PdfGoogleFonts.notoSansGujaratiRegular,
    'ar': PdfGoogleFonts.notoSansArabicRegular,
    'ur': PdfGoogleFonts.notoSansArabicRegular,
    'th': PdfGoogleFonts.notoSansThaiRegular,
    'ja': PdfGoogleFonts.notoSansJPRegular,
    'zh': PdfGoogleFonts.notoSansSCRegular,
    'ko': PdfGoogleFonts.notoSansKRRegular,
  };

  static final Map<String, Future<pw.Font> Function()> _scriptBold = {
    'hi': PdfGoogleFonts.notoSansDevanagariBold,
    'mr': PdfGoogleFonts.notoSansDevanagariBold,
    'ta': PdfGoogleFonts.notoSansTamilBold,
    'te': PdfGoogleFonts.notoSansTeluguBold,
    'kn': PdfGoogleFonts.notoSansKannadaBold,
    'ml': PdfGoogleFonts.notoSansMalayalamBold,
    'bn': PdfGoogleFonts.notoSansBengaliBold,
    'gu': PdfGoogleFonts.notoSansGujaratiBold,
    'ar': PdfGoogleFonts.notoSansArabicBold,
    'ur': PdfGoogleFonts.notoSansArabicBold,
    'th': PdfGoogleFonts.notoSansThaiBold,
    'ja': PdfGoogleFonts.notoSansJPBold,
    'zh': PdfGoogleFonts.notoSansSCBold,
    'ko': PdfGoogleFonts.notoSansKRBold,
  };

  /// Builds the document for [meeting] in [languageCode], or in the original
  /// language when that is null.
  ///
  /// Throws if the script's font cannot be fetched, which the caller should
  /// surface -- silently falling back to Helvetica would produce a page of
  /// empty boxes.
  Future<Uint8List> build(Meeting meeting, {String? languageCode}) async {
    final latin = await PdfGoogleFonts.notoSansRegular();
    final latinBold = await PdfGoogleFonts.notoSansBold();

    final regularLoader = languageCode == null
        ? null
        : _scriptRegular[languageCode];
    final boldLoader = languageCode == null ? null : _scriptBold[languageCode];

    final base = regularLoader != null ? await regularLoader() : latin;
    final bold = boldLoader != null ? await boldLoader() : latinBold;

    final document = pw.Document(
      title: meeting.title,
      subject: 'Meeting minutes',
    );

    final theme = pw.ThemeData.withFont(
      base: base,
      bold: bold,
      // Glyphs missing from the script face -- Latin speaker names, digits in a
      // Devanagari transcript -- resolve here instead of vanishing.
      fontFallback: [latin, latinBold],
    );

    final segments = meeting.segmentsIn(languageCode);
    final summary = meeting.summaryIn(languageCode);
    final actionItems = meeting.actionItemsIn(languageCode);
    final highlights = meeting.highlightsIn(languageCode);

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 40),
          textDirection:
              (languageCode != null && _rtlCodes.contains(languageCode))
              ? pw.TextDirection.rtl
              : pw.TextDirection.ltr,
        ),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerLeft,
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  meeting.title,
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  ·  Generated by Scribe',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          _title(meeting),
          pw.SizedBox(height: 16),
          _metadata(meeting, languageCode),
          pw.SizedBox(height: 20),
          if (summary != null && summary.isNotEmpty) ...[
            _sectionHeading('Summary'),
            pw.Paragraph(
              text: summary,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
            pw.SizedBox(height: 8),
          ],
          if (actionItems.isNotEmpty) ...[
            _sectionHeading('Action Items'),
            for (var i = 0; i < actionItems.length; i++)
              _actionItem(actionItems[i], meeting.isActionItemCompleted(i)),
            pw.SizedBox(height: 12),
          ],
          if (highlights.isNotEmpty) ...[
            _sectionHeading('Highlights'),
            for (final highlight in highlights) _bullet(highlight),
            pw.SizedBox(height: 12),
          ],
          if (segments.isNotEmpty) ...[
            _sectionHeading('Transcript'),
            for (final segment in segments)
              _transcriptLine(segment, meeting.speakerMapping),
          ] else if (meeting.transcript != null &&
              meeting.transcript!.isNotEmpty) ...[
            _sectionHeading('Transcript'),
            pw.Paragraph(
              text: meeting.transcript!,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
            ),
          ],
        ],
      ),
    );

    return document.save();
  }

  /// Hands [bytes] to the platform share sheet. On Android and iOS this is the
  /// share-to-any-app dialog; on desktop it is a save/print dialog.
  Future<void> share(Uint8List bytes, Meeting meeting) {
    return Printing.sharePdf(bytes: bytes, filename: _filename(meeting));
  }

  String _filename(Meeting meeting) {
    final safeTitle = meeting.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final stem = safeTitle.isEmpty ? 'meeting' : safeTitle.toLowerCase();
    return '$stem-minutes.pdf';
  }

  pw.Widget _title(Meeting meeting) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'MEETING MINUTES',
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
            letterSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          meeting.title,
          style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
      ],
    );
  }

  pw.Widget _metadata(Meeting meeting, String? languageCode) {
    final speakers = meeting.speakers
        .map((id) => meeting.speakerMapping[id] ?? id)
        .where((name) => name.isNotEmpty)
        .toList();

    final rows = <List<String>>[
      ['Date', meeting.date],
      ['Duration', meeting.duration],
      if (speakers.isNotEmpty) ['Attendees', speakers.join(', ')],
      if (languageCode != null)
        ['Language', '${AppLanguage.nameForCode(languageCode)} (translated)']
      else if (meeting.detectedLanguage != null)
        ['Language', AppLanguage.nameForCode(meeting.detectedLanguage!)],
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(
                    row[0],
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    row[1],
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _sectionHeading(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8, top: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _actionItem(String text, bool completed) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // A checkbox drawn as text: the Noto faces have these glyphs, and a
          // real pw.Checkbox is an interactive form field, not a printed mark.
          pw.Container(
            width: 16,
            child: pw.Text(
              completed ? '[x]' : '[ ]',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 11,
                lineSpacing: 2,
                color: completed ? PdfColors.grey600 : PdfColors.black,
                decoration: completed ? pw.TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 16,
            child: pw.Text('•', style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _transcriptLine(
    MeetingSegment segment,
    Map<String, String> speakerMapping,
  ) {
    final speaker = segment.speaker == null
        ? null
        : (speakerMapping[segment.speaker] ?? segment.speaker);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 46,
            child: pw.Text(
              _timestamp(segment.start),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (speaker != null)
                  pw.Text(
                    speaker,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                pw.Text(
                  segment.text.trim(),
                  style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timestamp(double seconds) {
    final total = seconds.round();
    final minutes = total ~/ 60;
    final secs = total % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
