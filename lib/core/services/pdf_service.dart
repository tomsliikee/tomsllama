import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
    int maxPages = 20,
    int maxCharacters = 30000,
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

      final extractor = PdfTextExtractor(document);
      final StringBuffer buffer = StringBuffer();
      int pagesRead = 0;
      bool isTruncated = false;

      final int pagesToRead = totalPages > maxPages ? maxPages : totalPages;
      for (int i = 0; i < pagesToRead; i++) {
        final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
        if (pageText.isNotEmpty) {
          if (totalPages > 1) {
            buffer.writeln('--- Page ${i + 1} ---');
          }
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

      final extractedText = buffer.toString().trim();
      final hasTextLayer = extractedText.isNotEmpty;

      String finalText = extractedText;
      if (!hasTextLayer) {
        finalText =
            '[Hinweis: Diese PDF enthält keine lesbare Textebene (gescanntes Dokument/Foto ohne OCR). Es konnte kein Text extrahiert werden.]';
      } else if (isTruncated) {
        finalText +=
            '\n\n// ... [Truncated: Extracted first $pagesRead of $totalPages pages for CPU performance] ...';
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
