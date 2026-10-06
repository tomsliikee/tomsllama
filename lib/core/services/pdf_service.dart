import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'context_manager.dart';

class PdfExtractionResult {
  final String text;
  final int pageCount;
  final bool isTruncated;
  final bool hasTextLayer;

  const PdfExtractionResult({
    required this.text,
    required this.pageCount,
    this.isTruncated = false,
    this.hasTextLayer = true,
  });
}

class PdfService {
  /// Extracts text from a PDF file with page caps and character caps for local CPU performance.
  static Future<PdfExtractionResult?> extractText(
    String filePath, {
    int maxPages = 2,
    int maxCharacters = 1800,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    PdfDocument? document;
    try {
      final bytes = await file.readAsBytes();
      document = PdfDocument(inputBytes: bytes);
      final int totalPages = document.pages.count;
      if (totalPages == 0) {
        return const PdfExtractionResult(
          text: '',
          pageCount: 0,
          hasTextLayer: false,
        );
      }

      final info = document.documentInformation;
      final String? title = info.title.trim().isNotEmpty ? info.title.trim() : null;
      final String? author = info.author.trim().isNotEmpty ? info.author.trim() : null;
      final String? subject = info.subject.trim().isNotEmpty ? info.subject.trim() : null;

      final extractor = PdfTextExtractor(document);
      final StringBuffer buffer = StringBuffer();

      buffer.writeln(
          '[PDF Overview: ${p.basename(filePath)} | Pages: $totalPages${title != null ? ' | Title: $title' : ''}${author != null ? ' | Author: $author' : ''}${subject != null ? ' | Subject: $subject' : ''}]');
      buffer.writeln();

      int pagesRead = 0;
      bool isTruncated = false;

      final int pagesToRead = totalPages > maxPages ? maxPages : totalPages;
      for (int i = 0; i < pagesToRead; i++) {
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
        if (pageText.isNotEmpty) {
          buffer.writeln('--- Page ${i + 1} ---');
          buffer.writeln(pageText);
          buffer.writeln();
        }
        pagesRead++;

        if (buffer.length >= maxCharacters) {
          isTruncated = true;
          break;
        }
      }

      if (pagesRead < totalPages && !isTruncated) {
        isTruncated = true;
      }

      String extractedText = buffer.toString().trim();
      if (extractedText.length > maxCharacters) {
        extractedText = extractedText.substring(0, maxCharacters).trimRight();
        isTruncated = true;
      }
      final hasTextLayer = extractedText.length > 30;

      String finalText = extractedText;
      if (!hasTextLayer) {
        finalText =
            '[Hinweis: Diese PDF enthält keine lesbare Textebene (gescanntes Dokument/Foto ohne OCR). Es konnte kein Text extrahiert werden.]';
      } else if (isTruncated) {
        finalText +=
            '\n\n// ... [Truncated: Extracted first $pagesRead of $totalPages pages (~${ContextManager.estimateTokens(extractedText)} tokens) for CPU performance] ...';
      }

      return PdfExtractionResult(
        text: finalText,
        pageCount: totalPages,
        isTruncated: isTruncated,
        hasTextLayer: hasTextLayer,
      );
    } catch (_) {
      return null;
    } finally {
      document?.dispose();
    }
  }
}
