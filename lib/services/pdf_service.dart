import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/client.dart';
import '../models/invoice.dart';

class PdfService {
  Future<File> createPdfFile(Invoice invoice, Client client) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Sparks Invoice',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Invoice Details',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              pw.Text('Client: ${client.name}'),
              pw.Text(
                  'Date: ${invoice.date.toDate().toLocal().toString().split(' ')[0]}'),
              pw.SizedBox(height: 20),
              pw.Text('Line Items',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Table.fromTextArray(
                headers: ['Item', 'Quantity', 'Price', 'Subtotal'],
                data: invoice.items
                    .map((item) => [
                          item.name,
                          item.quantity.toString(),
                          item.price.toStringAsFixed(2),
                          item.subtotal.toStringAsFixed(2)
                        ])
                    .toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Subtotal: ${invoice.subtotal.toStringAsFixed(2)}'),
              pw.Text('Tax: ${invoice.taxRate.toStringAsFixed(2)}%'),
              pw.Text('Discount: ${invoice.discountAmount.toStringAsFixed(2)}'),
              pw.Divider(),
              pw.Text('Total: ${invoice.total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/invoice_${invoice.id}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> openInvoicePdf(Invoice invoice, Client client) async {
    final file = await createPdfFile(invoice, client);
    await OpenFilex.open(file.path);
  }

  Future<void> shareInvoicePdf(Invoice invoice, Client client) async {
    final file = await createPdfFile(invoice, client);
    if (!await file.exists()) {
      throw Exception('PDF not generated');
    }
    print('Sharing PDF file path: ${file.path}');
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Invoice attached',
      subject: 'Invoice from Sparks Invoice',
    );
  }
}
