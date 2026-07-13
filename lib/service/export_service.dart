import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/models/expense_model.dart';
import '../constants/models/projects_model.dart';

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  String buildTimestampedBaseName(String prefix) {
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${prefix}_$stamp';
  }

  Future<String> exportProjectsToExcel({
    required List<Project> projects,
    required Future<List<Expense>> Function(String projectId) expensesLoader,
  }) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final excel = Excel.createExcel();

    final logSheet = excel['Project Logs'];
    logSheet.appendRow([
      TextCellValue('Project Name'),
      TextCellValue('Date'),
      TextCellValue('Entry Name'),
      TextCellValue('Merchant'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
      TextCellValue('Has Receipt'),
    ]);
    _styleHeaderRow(logSheet, 0, 7);

    for (final project in projects) {
      final expenses = await expensesLoader(project.id);
      expenses.sort((a, b) => a.date.compareTo(b.date));
      for (final expense in expenses) {
        final entryName =
            (expense.notes != null && expense.notes!.trim().isNotEmpty)
            ? expense.notes!
            : expense.merchant;
        logSheet.appendRow([
          TextCellValue(project.name),
          TextCellValue(dateFmt.format(expense.date)),
          TextCellValue(entryName),
          TextCellValue(expense.merchant),
          TextCellValue(expense.category.displayName),
          DoubleCellValue(expense.amount),
          TextCellValue(expense.hasReceipt ? 'Yes' : 'No'),
        ]);
      }
    }

    final summarySheet = excel['Projects'];
    summarySheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Description'),
      TextCellValue('Start Date'),
      TextCellValue('End Date'),
      TextCellValue('Budget'),
      TextCellValue('Spent'),
      TextCellValue('Remaining'),
      TextCellValue('Status'),
      TextCellValue('Category'),
      TextCellValue('Progress %'),
      TextCellValue('Tags'),
    ]);
    _styleHeaderRow(summarySheet, 0, 11);

    for (final project in projects) {
      summarySheet.appendRow([
        TextCellValue(project.name),
        TextCellValue(project.description),
        TextCellValue(dateFmt.format(project.startDate)),
        TextCellValue(
          project.endDate != null ? dateFmt.format(project.endDate!) : 'N/A',
        ),
        DoubleCellValue(project.budget),
        DoubleCellValue(project.spent),
        DoubleCellValue(project.remainingBudget),
        TextCellValue(project.status),
        TextCellValue(project.category),
        DoubleCellValue((project.progress * 100).clamp(0.0, 100.0)),
        TextCellValue(project.tags.join(', ')),
      ]);
    }

    final statsSheet = excel['Statistics'];
    statsSheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    _styleHeaderRow(statsSheet, 0, 2);
    statsSheet.appendRow([
      TextCellValue('Total Projects'),
      IntCellValue(projects.length),
    ]);
    statsSheet.appendRow([
      TextCellValue('Total Budget'),
      DoubleCellValue(projects.fold(0.0, (sum, p) => sum + p.budget)),
    ]);
    statsSheet.appendRow([
      TextCellValue('Total Spent'),
      DoubleCellValue(projects.fold(0.0, (sum, p) => sum + p.spent)),
    ]);
    statsSheet.appendRow([
      TextCellValue('Export Date'),
      TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
    ]);

    const keepSheets = {'Project Logs', 'Projects', 'Statistics'};
    for (final name in List<String>.from(excel.tables.keys)) {
      if (!keepSheets.contains(name)) {
        excel.delete(name);
      }
    }

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Excel export returned no file data.');
    }

    final baseName = buildTimestampedBaseName('projects_export');
    return _writeExportFile(
      bytes: Uint8List.fromList(bytes),
      baseName: baseName,
      extension: 'xlsx',
    );
  }

  Future<String> exportProjectsToCsv({
    required List<Project> projects,
    required Future<List<Expense>> Function(String projectId) expensesLoader,
  }) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final rows = <List<dynamic>>[
      [
        'Name',
        'Description',
        'Start Date',
        'End Date',
        'Budget',
        'Spent',
        'Remaining',
        'Status',
        'Category',
        'Progress %',
        'Tags',
      ],
    ];

    for (final project in projects) {
      rows.add([
        project.name,
        project.description,
        dateFmt.format(project.startDate),
        project.endDate != null ? dateFmt.format(project.endDate!) : 'N/A',
        project.budget,
        project.spent,
        project.remainingBudget,
        project.status,
        project.category,
        (project.progress * 100).clamp(0.0, 100.0),
        project.tags.join(', '),
      ]);
    }

    rows.add([]);
    rows.add([
      'Project Name',
      'Date',
      'Entry Name',
      'Merchant',
      'Category',
      'Amount',
      'Has Receipt',
    ]);

    for (final project in projects) {
      final expenses = await expensesLoader(project.id);
      expenses.sort((a, b) => a.date.compareTo(b.date));
      for (final expense in expenses) {
        final entryName =
            (expense.notes != null && expense.notes!.trim().isNotEmpty)
            ? expense.notes!
            : expense.merchant;
        rows.add([
          project.name,
          dateFmt.format(expense.date),
          entryName,
          expense.merchant,
          expense.category.displayName,
          expense.amount,
          expense.hasReceipt ? 'Yes' : 'No',
        ]);
      }
    }

    final csv = const CsvEncoder().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
    final baseName = buildTimestampedBaseName('projects_export');
    return _writeExportFile(
      bytes: bytes,
      baseName: baseName,
      extension: 'csv',
    );
  }

  Future<String> exportProjectSummaryPdf({
    required Project project,
    required List<Expense> expenses,
    required String currencyLabel,
  }) async {
    final pdf = pw.Document();
    // Default to Kenyan Shilling symbol when no currencyLabel provided.
    final currency = currencyLabel.trim().isEmpty ? 'KSh' : currencyLabel;
    final dateFmt = DateFormat('yyyy-MM-dd');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Project Summary: ${project.name}',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Paragraph(text: project.description),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metricCardPdf('Status', project.status),
              _metricCardPdf('Category', project.category),
              _metricCardPdf(
                'Budget',
                '$currency${project.budget.toStringAsFixed(2)}',
              ),
              _metricCardPdf(
                'Spent',
                '$currency${project.spent.toStringAsFixed(2)}',
              ),
              _metricCardPdf(
                'Remaining',
                '$currency${project.remainingBudget.toStringAsFixed(2)}',
              ),
              _metricCardPdf(
                'Progress',
                '${(project.progress * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
          if (project.tags.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Tags: ${project.tags.join(', ')}',
              style: const pw.TextStyle(fontSize: 12),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'Recent Expenses',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Merchant', 'Category', 'Amount', 'Receipt'],
            data: expenses
                .map(
                  (expense) => [
                    dateFmt.format(expense.date),
                    expense.merchant,
                    expense.category.displayName,
                    '$currency${expense.amount.toStringAsFixed(2)}',
                    expense.hasReceipt ? 'Yes' : 'No',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final baseName = buildTimestampedBaseName(
      'project_summary_${_slug(project.name)}',
    );
    return _writeExportFile(
      bytes: Uint8List.fromList(bytes),
      baseName: baseName,
      extension: 'pdf',
    );
  }

  Future<String> exportReceiptPdf({
    required Expense expense,
    String? projectName,
  }) async {
    final pdf = pw.Document();
    final imageBytes =
        expense.receiptImage != null && expense.receiptImage!.isNotEmpty
        ? await File(expense.receiptImage!).readAsBytes()
        : null;
    final image = imageBytes == null ? null : pw.MemoryImage(imageBytes);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Receipt Export',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.TableHelper.fromTextArray(
            headers: ['Field', 'Value'],
            data: [
              ['Merchant', expense.merchant],
              ['Amount', expense.formattedAmount],
              ['Date', dateFmt.format(expense.date)],
              ['Category', expense.category.displayName],
              ['Status', expense.status.displayName],
              ['Project', projectName ?? 'Unassigned'],
              [
                'Notes',
                expense.notes?.trim().isNotEmpty == true
                    ? expense.notes!
                    : 'None',
              ],
            ],
          ),
          if (image != null) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Receipt Image',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            pw.Image(image, fit: pw.BoxFit.contain, height: 360),
          ],
        ],
      ),
    );

    final bytes = await pdf.save();
    final baseName = buildTimestampedBaseName(
      'receipt_${_slug(expense.merchant)}',
    );
    return _writeExportFile(
      bytes: Uint8List.fromList(bytes),
      baseName: baseName,
      extension: 'pdf',
    );
  }

  Future<String> exportReceiptImageCopy({
    required String imagePath,
    required String merchant,
  }) async {
    final bytes = await File(imagePath).readAsBytes();
    final extension = imagePath.split('.').last.toLowerCase();
    final baseName = buildTimestampedBaseName('receipt_${_slug(merchant)}');
    return _writeExportFile(
      bytes: Uint8List.fromList(bytes),
      baseName: baseName,
      extension: extension,
    );
  }

  Future<String> exportReportPdf({
    required String title,
    required String periodLabel,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> categoryBreakdown,
    required List<Map<String, dynamic>> projectBreakdown,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              title,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text('Period: $periodLabel'),
          pw.SizedBox(height: 16),
          pw.Wrap(
            spacing: 12,
            runSpacing: 12,
            children: metrics.entries
                .map((entry) => _metricCardPdf(entry.key, '${entry.value}'))
                .toList(),
          ),
          pw.SizedBox(height: 20),
          if (categoryBreakdown.isNotEmpty) ...[
            pw.Text(
              'Category Breakdown',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Category', 'Amount', 'Share %'],
              data: categoryBreakdown
                  .map(
                    (row) => [
                      '${row['name'] ?? row['category'] ?? 'Unknown'}',
                      '${row['amount'] ?? 0}',
                      '${row['percentage'] ?? 0}',
                    ],
                  )
                  .toList(),
            ),
          ],
          if (projectBreakdown.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              'Project Breakdown',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Project', 'Amount', 'Share %'],
              data: projectBreakdown
                  .map(
                    (row) => [
                      '${row['name'] ?? row['project'] ?? 'Unknown'}',
                      '${row['amount'] ?? 0}',
                      '${row['percentage'] ?? 0}',
                    ],
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );

    final bytes = await pdf.save();
    final baseName = buildTimestampedBaseName('report_export');
    return _writeExportFile(
      bytes: Uint8List.fromList(bytes),
      baseName: baseName,
      extension: 'pdf',
    );
  }

  Future<String> exportReportCsv({
    required String title,
    required String periodLabel,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> categoryBreakdown,
    required List<Map<String, dynamic>> projectBreakdown,
  }) async {
    final rows = <List<dynamic>>[
      ['Report', title],
      ['Period', periodLabel],
      [],
      ['Metric', 'Value'],
      ...metrics.entries.map((entry) => [entry.key, entry.value]),
      [],
      ['Category', 'Amount', 'Share %'],
      ...categoryBreakdown.map(
        (row) => [
          row['name'] ?? row['category'] ?? 'Unknown',
          row['amount'] ?? 0,
          row['percentage'] ?? 0,
        ],
      ),
      [],
      ['Project', 'Amount', 'Share %'],
      ...projectBreakdown.map(
        (row) => [
          row['name'] ?? row['project'] ?? 'Unknown',
          row['amount'] ?? 0,
          row['percentage'] ?? 0,
        ],
      ),
    ];

    final csv = const CsvEncoder().convert(rows);
    final baseName = buildTimestampedBaseName('report_export');
    return _writeExportFile(
      bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
      baseName: baseName,
      extension: 'csv',
    );
  }

  void _styleHeaderRow(Sheet sheet, int rowIndex, int colCount) {
    for (var col = 0; col < colCount; col++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(rowIndex: rowIndex, columnIndex: col),
      );
      cell.cellStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString('#5A4FCF'),
        bold: true,
        textWrapping: TextWrapping.WrapText,
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      );
    }
  }

  pw.Widget _metricCardPdf(String label, String value) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _slug(String input) {
    final normalized = input.trim().toLowerCase();
    return normalized
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<String> _writeExportFile({
    required Uint8List bytes,
    required String baseName,
    required String extension,
  }) async {
    final directory = await _resolveExportDirectory();
    final filePath = p.join(directory.path, '$baseName.$extension');
    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Directory> _resolveExportDirectory() async {
    Directory baseDirectory;
    if (Platform.isAndroid) {
      baseDirectory =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      baseDirectory = await getApplicationDocumentsDirectory();
    }
    final exportDirectory = Directory(p.join(baseDirectory.path, 'exports'));
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }
    return exportDirectory;
  }
}
