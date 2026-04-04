import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../services/client_service.dart';
import '../services/invoice_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import 'invoice_create_screen.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final Invoice invoice;
  const InvoiceDetailsScreen({Key? key, required this.invoice}) : super(key: key);
  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen> {
  late Invoice _invoice;
  final _clientSvc = ClientService();
  final _invoiceSvc = InvoiceService();
  final _pdfSvc = PdfService();

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  String get _sym => _invoice.currency == 'USD' ? '\$' : '₹';
  String _fmt(double v) => NumberFormat('#,##,###.##').format(v);

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid: return Colors.green;
      case InvoiceStatus.unpaid: return Colors.orange;
      case InvoiceStatus.draft: return Colors.blueGrey;
      case InvoiceStatus.partiallyPaid: return Colors.blue;
      case InvoiceStatus.overdue: return Colors.red;
      case InvoiceStatus.cancelled: return Colors.grey;
    }
  }

  String _statusLabel(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid: return 'Paid';
      case InvoiceStatus.unpaid: return 'Unpaid';
      case InvoiceStatus.draft: return 'Draft';
      case InvoiceStatus.partiallyPaid: return 'Partially Paid';
      case InvoiceStatus.overdue: return 'Overdue';
      case InvoiceStatus.cancelled: return 'Cancelled';
    }
  }

  IconData _statusIcon(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid: return Icons.check_circle_outline_rounded;
      case InvoiceStatus.unpaid: return Icons.hourglass_empty_rounded;
      case InvoiceStatus.draft: return Icons.edit_note_rounded;
      case InvoiceStatus.partiallyPaid: return Icons.pie_chart_outline_rounded;
      case InvoiceStatus.overdue: return Icons.report_problem_outlined;
      case InvoiceStatus.cancelled: return Icons.cancel_outlined;
    }
  }

  void _showStatusPicker() {
    final transitions = Invoice.allowedTransitions(_invoice.effectiveStatus);
    if (transitions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No further status transitions available.'), behavior: SnackBarBehavior.floating));
      return;
    }
    double? partialAmount;
    InvoiceStatus? chosen;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ...transitions.map((s) => RadioListTile<InvoiceStatus>(
              value: s, groupValue: chosen,
              title: Text(_statusLabel(s)),
              secondary: Icon(_statusIcon(s), color: _statusColor(s)),
              onChanged: (v) => setS(() => chosen = v),
            )),
            if (chosen == InvoiceStatus.partiallyPaid) ...[
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(labelText: 'Amount Received ($_sym)', prefixIcon: const Icon(Icons.payments_outlined)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => partialAmount = double.tryParse(v),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: chosen == null ? null : () async {
                Navigator.pop(ctx);
                print("START LOADING (Status Update)");
                try {
                  await _invoiceSvc.updateStatus(_invoice.id!, chosen!, amountPaid: partialAmount);
                  if (mounted) {
                    setState(() => _invoice = _invoice.copyWith(status: chosen, amountPaid: partialAmount ?? _invoice.amountPaid));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Status updated to ${_statusLabel(chosen!)}'), 
                      backgroundColor: Colors.green, 
                      behavior: SnackBarBehavior.floating
                    ));
                  }
                } catch (e) {
                  print("STATUS UPDATE ERROR: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error updating status: $e'), 
                      backgroundColor: Colors.red
                    ));
                  }
                } finally {
                  print("STOP LOADING (Status Update)");
                }
              },
              child: const Text('Confirm'),
            ),
          ]),
        ),
      )),
    );
  }

  void _shareOptions(Client client) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.share_rounded, color: AppColors.primary), 
            title: const Text('Share (WhatsApp / Email)'), 
            onTap: () { 
              Navigator.pop(context); 
              // Direct call without UI block (allow bottom sheet animation to finish)
              Future.delayed(const Duration(milliseconds: 100), () {
                _pdfSvc.shareInvoicePdf(_invoice, client).catchError((e) {
                  print("SHARE ERROR: $e");
                });
              });
            }
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: Colors.green), 
            title: const Text('Download PDF'), 
            onTap: () { 
              Navigator.pop(context); 
              // Direct call without UI block
              Future.delayed(const Duration(milliseconds: 100), () {
                _pdfSvc.openInvoicePdf(_invoice, client).catchError((e) {
                  print("OPEN PDF ERROR: $e");
                });
              });
            }
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _invoice.effectiveStatus;
    final color = _statusColor(status);
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber),
        actions: [
          if (status == InvoiceStatus.draft || status == InvoiceStatus.unpaid)
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Edit', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceCreateScreen(existingInvoice: _invoice)))),
          FutureBuilder<Client?>(
            future: _clientSvc.getClient(_invoice.clientRef.id),
            builder: (_, snap) => snap.hasData
                ? IconButton(icon: const Icon(Icons.ios_share_rounded), tooltip: 'Share', onPressed: () => _shareOptions(snap.data!))
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Status banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(_statusIcon(status), color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
                if (status == InvoiceStatus.partiallyPaid) Text('Paid: $_sym${_fmt(_invoice.amountPaid)}', style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
              ])),
          if (Invoice.allowedTransitions(status).isNotEmpty)
                TextButton(onPressed: _showStatusPicker, child: const Text('Update')),
            ]),
          ),
          const SizedBox(height: 20),

          // Client info
          FutureBuilder<Client?>(
            future: _clientSvc.getClient(_invoice.clientRef.id),
            builder: (_, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              final c = snap.data!;
              return _infoCard('CLIENT', [
                Row(children: [
                  CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1), child: Text(c.name[0], style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (c.contactPerson.isNotEmpty) Text(c.contactPerson, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    Text(c.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    if (c.phone.isNotEmpty) Text(c.phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ])),
                ]),
              ]);
            },
          ),
          const SizedBox(height: 16),

          // Dates
          _infoCard('DATES', [
            Row(children: [
              Expanded(child: _labelValue('Invoice Date', fmt.format(_invoice.date.toDate()))),
              Expanded(child: _labelValue('Due Date', fmt.format(_invoice.dueDate.toDate()), danger: status == InvoiceStatus.overdue)),
              Expanded(child: _labelValue('Terms', _invoice.paymentTerms)),
            ]),
          ]),
          const SizedBox(height: 16),

          // Line items
          _infoCard('LINE ITEMS', [
            ..._invoice.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${item.quantity} x $_sym${_fmt(item.price)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ])),
                Text('$_sym${_fmt(item.subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            )),
            const Divider(),
            _totRow('Subtotal', _invoice.subtotal),
            if (_invoice.discountValue > 0) _totRow('Discount', _invoice.discountAmount, isNeg: true),
            if (_invoice.taxApplicable) _totRow('Tax (${_invoice.taxRate.toStringAsFixed(0)}%)', _invoice.taxAmount),
            const Divider(),
            _totRow('Total', _invoice.total, isBold: true),
          ]),

          if (_invoice.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            _infoCard('NOTES', [Text(_invoice.notes, style: TextStyle(color: Colors.grey.shade700))]),
          ],
          if (_invoice.termsAndConditions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _infoCard('TERMS & CONDITIONS', [Text(_invoice.termsAndConditions, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))]),
          ],
          if (_invoice.bankDetails.isNotEmpty) ...[
            const SizedBox(height: 16),
            _infoCard('BANK DETAILS', [Text(_invoice.bankDetails, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))]),
          ],

          // Status history
          if (_invoice.statusHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            _infoCard('STATUS HISTORY', [
              ..._invoice.statusHistory.reversed.map((h) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(_statusIcon(h.status), size: 16, color: _statusColor(h.status)),
                  const SizedBox(width: 8),
                  Text(_statusLabel(h.status), style: TextStyle(color: _statusColor(h.status), fontWeight: FontWeight.w600, fontSize: 13)),
                  const Spacer(),
                  Text(DateFormat('dd MMM yyyy, HH:mm').format(h.changedAt), style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ]),
              )),
            ]),
          ],
          const SizedBox(height: 32),

          // ── Update Status button (always visible if transitions exist) ──
          if (Invoice.allowedTransitions(_invoice.effectiveStatus).isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: _showStatusPicker,
              icon: const Icon(Icons.update_rounded),
              label: const Text('Update Invoice Status'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Share button ────────────────────────────────────────────────
          FutureBuilder<Client?>(
            future: _clientSvc.getClient(_invoice.clientRef.id),
            builder: (_, snap) => snap.hasData
                ? OutlinedButton.icon(
                    onPressed: () => _shareOptions(snap.data!),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share Invoice'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _infoCard(String label, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _labelValue(String label, String value, {bool danger = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: danger ? Colors.red : null)),
    ]);
  }

  Widget _totRow(String label, double value, {bool isBold = false, bool isNeg = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14)),
        Text('${isNeg ? "- " : ""}$_sym${_fmt(value)}', style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: isBold ? 16 : 14, color: isBold ? Theme.of(context).colorScheme.primary : null)),
      ]),
    );
  }
}

