import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../theme/app_colors.dart';
import 'invoice_create_screen.dart';
import 'invoice_details_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  final InvoiceStatus? initialFilter;
  const InvoiceListScreen({Key? key, this.initialFilter}) : super(key: key);
  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final _svc = InvoiceService();
  late InvoiceStatus? _statusFilter;

  @override
  void initState() { super.initState(); _statusFilter = widget.initialFilter; }

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

  void _showStatusPicker(Invoice inv) {
    final transitions = Invoice.allowedTransitions(inv.effectiveStatus);
    if (transitions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No further transitions.'), behavior: SnackBarBehavior.floating));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...transitions.map((s) => ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _statusColor(s).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(_statusIcon(s), color: _statusColor(s), size: 18)),
            title: Text(_statusLabel(s), style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => _updateStatus(inv, s),
          )),
        ]),
      ),
    );
  }

  Future<void> _updateStatus(Invoice inv, InvoiceStatus newStatus) async {
    Navigator.pop(context);
    try {
      await FirebaseFirestore.instance.collection('invoices').doc(inv.id).update({'status': newStatus.name, 'updatedAt': Timestamp.now()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to ${_statusLabel(newStatus)}'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.danger, behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _duplicate(Invoice inv) async {
    final n = await _svc.getNextInvoiceNumber();
    final newNumber = 'INV-${DateTime.now().year}-${n.toString().padLeft(3, '0')}';
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceCreateScreen(existingInvoice: inv.copyWith(id: null, invoiceNumber: newNumber, status: InvoiceStatus.draft, date: null, dueDate: null))));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onBg = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<InvoiceStatus?>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (v) => setState(() => _statusFilter = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              ...InvoiceStatus.values.map((s) => PopupMenuItem(value: s, child: Text(_statusLabel(s)))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceCreateScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Invoice'),
        backgroundColor: primary,
      ),
      body: StreamBuilder<List<Invoice>>(
        stream: _svc.getInvoices(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final all = snap.data ?? [];
          final invoices = _statusFilter == null ? all : all.where((i) => i.effectiveStatus == _statusFilter).toList();
          if (invoices.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.receipt_long_outlined, size: 72, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('No invoices found', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ]));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: invoices.length,
            itemBuilder: (_, i) {
              final inv = invoices[i];
              final status = inv.effectiveStatus;
              final c = _statusColor(status);
              final sym = inv.currency == 'USD' ? r'$' : 'Rs.';
              final canEdit = status == InvoiceStatus.draft || status == InvoiceStatus.unpaid;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailsScreen(invoice: inv))),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 42, height: 42, decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.receipt_outlined, color: c, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(inv.invoiceNumber, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onBg)),
                          const SizedBox(height: 2),
                          Text(DateFormat('dd MMM yyyy').format(inv.date.toDate()), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('$sym${NumberFormat('#,##,###.##').format(inv.total)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: onBg)),
                          const SizedBox(height: 4),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status.name.toUpperCase(), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold))),
                        ]),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: () => _showStatusPicker(inv),
                          icon: Icon(Icons.update_rounded, size: 14, color: primary),
                          label: Text('Update Status', style: TextStyle(fontSize: 12, color: primary)),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8), side: BorderSide(color: primary.withOpacity(0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: canEdit
                          ? OutlinedButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceCreateScreen(existingInvoice: inv))),
                              icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.warning),
                              label: const Text('Edit', style: TextStyle(fontSize: 12, color: AppColors.warning)),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8), side: BorderSide(color: AppColors.warning.withOpacity(0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            )
                          : OutlinedButton.icon(
                              onPressed: () => _duplicate(inv),
                              icon: const Icon(Icons.copy_outlined, size: 14, color: AppColors.textSecondary),
                              label: const Text('Duplicate', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 8), side: const BorderSide(color: AppColors.textMuted), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            )),
                      ]),
                    ]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
