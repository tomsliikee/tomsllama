import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:tomsllama/core/services/pdf_service.dart';
import 'package:tomsllama/core/models/attached_file.dart';

void main() {
  late Directory tempDir;
  late String testPdfPath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tomsllama_pdf_test_');
    testPdfPath = '${tempDir.path}/sample_document.pdf';

    // Create a 2-page test PDF document
    final PdfDocument doc = PdfDocument();

    // Page 1
    final PdfPage page1 = doc.pages.add();
    page1.graphics.drawString(
      'Tomsllama AI Architecture Overview\nThis document describes local LLM orchestration.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    // Page 2
    final PdfPage page2 = doc.pages.add();
    page2.graphics.drawString(
      'Section 2: PDF Parsing and Token Management\nAll text layers are safely extracted.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );

    final List<int> bytes = await doc.save();
    doc.dispose();

    await File(testPdfPath).writeAsBytes(bytes);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('PdfService extracts text and page counts accurately from PDF documents', () async {
    final result = await PdfService.extractText(testPdfPath);

    expect(result, isNotNull);
    expect(result!.pageCount, equals(2));
    expect(result.hasTextLayer, isTrue);
    expect(result.text, contains('Tomsllama AI Architecture Overview'));
    expect(result.text, contains('Section 2: PDF Parsing'));
    expect(result.text, contains('--- Page 1 ---'));
    expect(result.text, contains('--- Page 2 ---'));
  });

  test('AttachedFile.fromPath extracts PDF content and formats markdown block', () async {
    final attached = await AttachedFile.fromPath(testPdfPath);

    expect(attached, isNotNull);
    expect(attached!.name, equals('sample_document.pdf'));
    expect(attached.extension, equals('.pdf'));
    expect(attached.estimatedTokens, greaterThan(0));
    expect(attached.content, contains('Tomsllama AI Architecture Overview'));

    final markdown = attached.toMarkdownBlock();
    expect(markdown, contains('[Attached PDF Document: sample_document.pdf]'));
    expect(markdown, contains('```text'));
    expect(markdown, contains('Section 2: PDF Parsing'));
  });

  test('PdfService returns null on missing file', () async {
    final result = await PdfService.extractText('${tempDir.path}/non_existent.pdf');
    expect(result, isNull);
  });
}
