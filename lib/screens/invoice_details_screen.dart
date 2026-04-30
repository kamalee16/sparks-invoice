import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../models/company.dart';
import '../models/invoice.dart';
import '../services/client_service.dart';
import '../services/company_service.dart';
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
  final _clientSvc   = ClientService();
  final _invoiceSvc  = InvoiceService();
  final _pdfSvc      = PdfService();
  final _companySvc  = CompanyService();
  Company? _company;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _companySvc.getCompany().first.then((c) {
      if (mounted) setState(() => _company = c);
    });
  }

  String get _sym => _invoice.currency == 'USD' ? '\$' : '₹';
  String _fmt(double v) => NumberFormat('#,##,###.##').format(v);

  Color _statusColor(InvoiceStatus s) {
    switch (s) {
      case InvoiceStatus.paid: return AppColors.success;
      case InvoiceStatus.unpaid: return AppColors.warning;
      case InvoiceStatus.draft: return AppColors.textSecondary;
      case InvoiceStatus.partiallyPaid: return AppColors.info;
      case InvoiceStatus.overdue: return AppColors.danger;
      case InvoiceStatus.cancelled: return AppColors.textMuted;
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
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
            const SizedBox(height: 20),
            ...transitions.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: chosen == s ? _statusColor(s).withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: RadioListTile<InvoiceStatus>(
                value: s, groupValue: chosen,
                title: Text(_statusLabel(s), style: TextStyle(fontWeight: FontWeight.bold, color: chosen == s ? _statusColor(s) : Colors.white)),
                secondary: Icon(_statusIcon(s), color: _statusColor(s)),
                onChanged: (v) => setS(() => chosen = v),
                activeColor: _statusColor(s),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )),
            if (chosen == InvoiceStatus.partiallyPaid) ...[
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Amount Received ($_sym)', 
                  prefixIcon: const Icon(Icons.payments_rounded),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) => partialAmount = double.tryParse(v),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: chosen == null ? null : () async {
                Navigator.pop(ctx);
                try {
                  await _invoiceSvc.updateStatus(_invoice.id!, chosen!, amountPaid: partialAmount);
                  if (mounted) {
                    setState(() => _invoice = _invoice.copyWith(status: chosen, amountPaid: partialAmount ?? _invoice.amountPaid));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Status updated to ${_statusLabel(chosen!)}'), 
                      backgroundColor: AppColors.success, 
                      behavior: SnackBarBehavior.floating
                    ));
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Error updating status: $e'), 
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating
                    ));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Confirm Status Update'),
            ),
          ]),
        ),
      )),
    );
  }

  void _shareOptions(Client client) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 22),
            ),
            title: const Text('Share PDF', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: const Text('WhatsApp, Email, or other apps', style: TextStyle(fontSize: 12)),
            onTap: () { 
              Navigator.pop(context); 
              Future.delayed(const Duration(milliseconds: 100), () {
                _pdfSvc.shareInvoicePdf(_invoice, client, company: _company).catchError((e) {
                  print("SHARE ERROR: $e");
                });
              });
            }
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.download_rounded, color: AppColors.success, size: 22),
            ),
            title: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: const Text('Save to your device', style: TextStyle(fontSize: 12)),
            onTap: () { 
              Navigator.pop(context); 
              Future.delayed(const Duration(milliseconds: 100), () {
                _pdfSvc.openInvoicePdf(_invoice, client, company: _company).catchError((e) {
                  print("OPEN PDF ERROR: $e");
                });
              });
            }
          ),
          const SizedBox(height: 12),
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

          // ── Invoice header with logo ──────────────────────────────────
          _InvoiceHeader(company: _company, invoiceNumber: _invoice.invoiceNumber),
          const SizedBox(height: 16),

          // Status banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(_statusIcon(status), color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_statusLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: -0.5)),
                if (status == InvoiceStatus.partiallyPaid) Text('Paid: $_sym${_fmt(_invoice.amountPaid)}', style: TextStyle(color: color.withOpacity(0.8), fontSize: 13)),
              ])),
          if (Invoice.allowedTransitions(status).isNotEmpty)
                TextButton(
                  onPressed: _showStatusPicker, 
                  child: Text('Update', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    backgroundColor: color.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 24),

          // From / To
          FutureBuilder<Client?>(
            future: _clientSvc.getClient(_invoice.clientRef.id),
            builder: (_, snap) {
              if (!snap.hasData) return const LinearProgressIndicator();
              final c = snap.data!;
              return _infoCard('FROM / TO', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FROM — left
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('From:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text(
                            _company?.name.isNotEmpty == true ? _company!.name : 'Sparks AI',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          if (_company?.legalName.isNotEmpty == true)
                            Text(_company!.legalName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), softWrap: true),
                          if (_company?.address.isNotEmpty == true)
                            Text(_company!.address, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), softWrap: true)
                          else
                            Text('India', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          if (_company?.email.isNotEmpty == true)
                            Text(_company!.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          if (_company?.phone.isNotEmpty == true)
                            Text(_company!.phone, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // TO — right block (label right, content left)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('To:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(
                            c.name,
                            softWrap: true,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          if (c.contactPerson.isNotEmpty) ...[
                            Text(c.contactPerson, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(height: 4),
                          ],
                          if (c.phone.isNotEmpty) ...[
                            Text('Phone: ${c.phone}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(height: 4),
                          ],
                          Text('Email: ${c.email}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          if (c.billingAddress.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${c.billingAddress}${c.city.isNotEmpty ? ", ${c.city}" : ""}',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              softWrap: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), 
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: 16),
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


// ── Invoice header widget — logo left, INVOICE right ─────────────────────────
class _InvoiceHeader extends StatelessWidget {
  final Company? company;
  final String invoiceNumber;
  const _InvoiceHeader({required this.company, required this.invoiceNumber});

  @override
  Widget build(BuildContext context) {
    final cardBg   = Theme.of(context).cardColor;
    final onBg     = Theme.of(context).colorScheme.onSurface;
    final logoUrl  = company?.logoUrl ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: logo or company name
          if (logoUrl.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 52, maxWidth: 160),
              child: CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => _fallbackLogo(context),
              ),
            )
          else
            _fallbackLogo(context),

          // Right: INVOICE label + number
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('INVOICE',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: onBg,
                    letterSpacing: 2.0)),
            const SizedBox(height: 4),
            Text('#$invoiceNumber',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }

  Widget _fallbackLogo(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      Text('Sparks',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, letterSpacing: -0.5)),
    ]);
  }
}
