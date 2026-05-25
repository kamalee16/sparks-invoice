import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';

class PdfService {
  static const _orange  = PdfColor.fromInt(0xFFFFA500);
  static const _yellow  = PdfColor.fromInt(0xFFFFD700);
  static const _black   = PdfColor.fromInt(0xFF111111);
  static const _grey    = PdfColor.fromInt(0xFF666666);
  static const _lightBg = PdfColor.fromInt(0xFFF5F5F5);
  static const _white   = PdfColors.white;

  Future<pw.Font> _loadRegular() async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));

  Future<pw.Font> _loadBold() async =>
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

  Future<Uint8List?> _fetchImage(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) return resp.bodyBytes;
    } catch (_) {}
    return null;
  }

  Future<File> createPdfFile(Invoice invoice, Client client, {Company? company}) async {
    final regular = await _loadRegular();
    final bold    = await _loadBold();

    pw.TextStyle reg(double size, {PdfColor? color}) =>
        pw.TextStyle(font: regular, fontSize: size, color: color ?? _black);
    pw.TextStyle bld(double size, {PdfColor? color}) =>
        pw.TextStyle(font: bold, fontSize: size, color: color ?? _black);

    final pdf  = pw.Document();
    final fmt  = DateFormat('dd/MM/yyyy');
    final nFmt = NumberFormat('#,##0.00');
    final sym  = invoice.currency == 'USD' ? r'$' : 'Rs.';
    final comp = company ?? Company.empty;

    // Load logo from local asset for PDF invoice
    final logoBytes = (await rootBundle.load('assets/images/logo.png'))
        .buffer
        .asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    // Pre-fetch address image (only used when text address is empty)
    pw.ImageProvider? addressImage;
    if (comp.address.isEmpty && comp.addressImageUrl.isNotEmpty) {
      final bytes = await _fetchImage(comp.addressImageUrl);
      if (bytes != null) addressImage = pw.MemoryImage(bytes);
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          // ── HEADER: Logo left | INVOICE title right ──────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Logo image from local asset
              pw.Image(
                logoImage,
                width: 185,
                height: 65,
                fit: pw.BoxFit.contain,
              ),
              // INVOICE title block
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('INVOICE',
                    style: pw.TextStyle(font: bold, fontSize: 24, color: _black, letterSpacing: 2)),
                pw.SizedBox(height: 4),
                pw.Text('#${invoice.invoiceNumber}', style: reg(12, color: _grey)),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: _lightBg, thickness: 1),
          pw.SizedBox(height: 16),

          // ── FROM / TO ─────────────────────────────────────────────────────
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            // FROM — left (clean minimal layout)
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('From:', style: bld(11)),
              pw.SizedBox(height: 6),
              pw.Text(comp.name.isNotEmpty ? comp.name : 'Sparks AI', style: bld(10)),
              pw.SizedBox(height: 3),
              pw.Text('India', style: reg(9, color: _grey)),
              pw.SizedBox(height: 3),
              pw.Text('Email: ${comp.email.isNotEmpty ? comp.email : 'contactsparksai@gmail.com'}', style: reg(9, color: _grey)),
              pw.SizedBox(height: 3),
              pw.Text('Website: ${comp.website.isNotEmpty ? comp.website : 'sparksai.in'}', style: reg(9, color: _grey)),
              pw.SizedBox(height: 3),
              pw.Text('Phone: ${comp.phone.isNotEmpty ? comp.phone : '+91 93453 64408'}', style: reg(9, color: _grey)),
            ])),
            pw.SizedBox(width: 40),
            // TO — right block (all left aligned)
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('To:', style: bld(11)),
              pw.SizedBox(height: 6),
              pw.Text(client.name, style: bld(10)),
              pw.SizedBox(height: 4),
              if (client.contactPerson.isNotEmpty) ...[
                pw.Text(client.contactPerson, style: reg(9, color: _grey)),
                pw.SizedBox(height: 4),
              ],
              if (client.phone.isNotEmpty) ...[
                pw.Text('Phone: ${client.phone}', style: reg(9, color: _grey)),
                pw.SizedBox(height: 4),
              ],
              if (client.email.isNotEmpty)
                pw.Text('Email: ${client.email}', style: reg(9, color: _grey)),
              if (client.billingAddress.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(
                  '${client.billingAddress}${client.city.isNotEmpty ? ", ${client.city}" : ""}',
                  style: reg(9, color: _grey),
                ),
              ],
            ])),
          ]),
          pw.SizedBox(height: 16),

          // ── INFO CARD ─────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _lightBg,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _infoCol('Project Name',
                    invoice.projectName,
                    reg, bld),
                _infoCol('Invoice Date', fmt.format(invoice.date.toDate()), reg, bld),
                _infoCol('Due Date', fmt.format(invoice.dueDate.toDate()), reg, bld),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Total Amount', style: reg(8, color: _grey)),
                  pw.SizedBox(height: 2),
                  pw.Text('$sym${nFmt.format(invoice.total)}', style: bld(13, color: _orange)),
                ]),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── ITEMS TABLE ───────────────────────────────────────────────────
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(40),
              2: const pw.FixedColumnWidth(72),
              3: const pw.FixedColumnWidth(72),
            },
            children: [
              // Gradient orange header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  gradient: pw.LinearGradient(colors: [_orange, _yellow]),
                ),
                children: [
                  _th('Description', bld),
                  _th('Qty',    bld, align: pw.TextAlign.center),
                  _th('Rate',   bld, align: pw.TextAlign.right),
                  _th('Amount', bld, align: pw.TextAlign.right),
                ],
              ),
              // Data rows — alternating light background
              ...invoice.items.asMap().entries.map((e) {
                final item   = e.value;
                final isEven = e.key.isEven;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: isEven ? _white : _lightBg),
                  children: [
                    _td(item.name, reg),
                    _td(item.quantity.toString(), reg, align: pw.TextAlign.center),
                    _td('$sym${nFmt.format(item.price)}',    reg, align: pw.TextAlign.right),
                    _td('$sym${nFmt.format(item.subtotal)}', bld, align: pw.TextAlign.right, color: _orange),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── TOTALS ────────────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: 250,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // Subtotal row
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Subtotal:',
                          style: pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey700)),
                      pw.Text('$sym${nFmt.format(invoice.subtotal)}',
                          style: pw.TextStyle(font: regular, fontSize: 12, color: _black)),
                    ],
                  ),
                  // Discount row (conditional)
                  if (invoice.discountValue > 0) ...[
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Discount:',
                            style: pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey700)),
                        pw.Text('- $sym${nFmt.format(invoice.discountAmount)}',
                            style: pw.TextStyle(font: regular, fontSize: 12, color: _black)),
                      ],
                    ),
                  ],
                  // Tax row (conditional)
                  if (invoice.taxApplicable) ...[
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Tax (${invoice.taxRate.toStringAsFixed(0)}%):',
                            style: pw.TextStyle(font: regular, fontSize: 12, color: PdfColors.grey700)),
                        pw.Text('$sym${nFmt.format(invoice.taxAmount)}',
                            style: pw.TextStyle(font: regular, fontSize: 12, color: _black)),
                      ],
                    ),
                  ],
                  pw.SizedBox(height: 8),
                  pw.Divider(color: PdfColors.grey300, thickness: 0.8),
                  pw.SizedBox(height: 8),
                  // Total row — bold and prominent
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total:',
                          style: pw.TextStyle(font: bold, fontSize: 16, color: _black)),
                      pw.Text('$sym${nFmt.format(invoice.total)}',
                          style: pw.TextStyle(font: bold, fontSize: 16, color: _orange)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          // ── TERMS ─────────────────────────────────────────────────────────
          if (invoice.termsAndConditions.isNotEmpty) ...[
            pw.Text('Terms and Conditions:', style: bld(10)),
            pw.SizedBox(height: 4),
            pw.Text(invoice.termsAndConditions, style: reg(9, color: _grey)),
            pw.SizedBox(height: 16),
          ],

          // ── BANK DETAILS ──────────────────────────────────────────────────
          if (invoice.bankDetails.isNotEmpty) ...[
            pw.Text('Bank Details:', style: bld(10)),
            pw.SizedBox(height: 4),
            pw.Text(invoice.bankDetails, style: reg(9, color: _grey)),
            pw.SizedBox(height: 16),
          ],

          // ── FOOTER ────────────────────────────────────────────────────────
          pw.Divider(color: _lightBg, thickness: 1),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('Thank you for your business!',
              style: bld(10, color: _grey))),
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text('Generated by Sparks AI Invoice Generator',
              style: reg(8, color: _grey))),
        ],
      ),
    ));

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/${invoice.invoiceNumber}.pdf');
    final pdfBytes = await pdf.save();
    if (pdfBytes.isEmpty) throw Exception('PDF generation produced empty file');
    await file.writeAsBytes(pdfBytes);
    return file;
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  pw.Widget _infoCol(String label, String value,
      pw.TextStyle Function(double, {PdfColor? color}) reg,
      pw.TextStyle Function(double, {PdfColor? color}) bld) =>
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: reg(8, color: _grey)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: bld(10)),
      ]);

  pw.Widget _th(String text, pw.TextStyle Function(double, {PdfColor? color}) bld,
      {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: pw.Text(text, textAlign: align, style: bld(10, color: _white)),
      );

  pw.Widget _td(String text, pw.TextStyle Function(double, {PdfColor? color}) style,
      {pw.TextAlign align = pw.TextAlign.left, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(text, textAlign: align, style: style(9, color: color)),
      );

  pw.Widget _totRow(String label, String value,
      pw.TextStyle Function(double, {PdfColor? color}) reg,
      pw.TextStyle Function(double, {PdfColor? color}) bld,
      {bool bold = false, bool large = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.SizedBox(width: 120,
              child: pw.Text(label, textAlign: pw.TextAlign.right,
                  style: bold ? bld(large ? 12 : 10) : reg(large ? 12 : 10))),
          pw.SizedBox(width: 16),
          pw.SizedBox(width: 80,
              child: pw.Text(value, textAlign: pw.TextAlign.right,
                  style: bold ? bld(large ? 13 : 10, color: color) : reg(large ? 13 : 10, color: color))),
        ]),
      );

  // Full-width totals row — label left, value right, clean spaceBetween alignment
  pw.Widget _totRowFull(String label, String value,
      pw.TextStyle Function(double, {PdfColor? color}) reg,
      pw.TextStyle Function(double, {PdfColor? color}) bld,
      {bool bold = false, bool large = false, PdfColor? color}) =>
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: bold ? bld(large ? 12 : 10) : reg(large ? 12 : 10)),
          pw.Text(value, style: bold ? bld(large ? 13 : 10, color: color) : reg(large ? 13 : 10, color: color)),
        ],
      );

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Opens the PDF in the device's default viewer.
  Future<void> openInvoicePdf(Invoice invoice, Client client, {Company? company}) async {
    final file = await createPdfFile(invoice, client, company: company);
    if (!await file.exists()) throw Exception('PDF file not found at ${file.path}');
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception('Could not open PDF: ${result.message}');
    }
  }

  /// Shares the PDF via the system share sheet.
  Future<void> shareInvoicePdf(Invoice invoice, Client client, {Company? company}) async {
    final file = await createPdfFile(invoice, client, company: company);
    if (!await file.exists()) throw Exception('PDF file not found at ${file.path}');
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      text: 'Invoice from ${company?.name.isNotEmpty == true ? company!.name : 'Sparks Invoice'}',
      subject: 'Invoice ${invoice.invoiceNumber}',
    );
  }
}
