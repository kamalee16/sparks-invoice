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
        title: const Text('Invoices', style: TextStyle(fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        actions: [
          Theme(
            data: Theme.of(context).copyWith(
              cardColor: AppColors.darkCard,
            ),
            child: PopupMenuButton<InvoiceStatus?>(
              icon: const Icon(Icons.filter_list_rounded),
              offset: const Offset(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (v) => setState(() => _statusFilter = v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('All Status')),
                ...InvoiceStatus.values.map((s) => PopupMenuItem(value: s, child: Text(_statusLabel(s)))),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-new-invoice',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceCreateScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
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
            Text(_statusFilter == null ? 'No invoices found' : 'No ${_statusLabel(_statusFilter!)} invoices', 
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
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
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // Rule 3
                padding: const EdgeInsets.all(12), // Rule 3
                decoration: BoxDecoration(
                  color: AppColors.darkCard,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceDetailsScreen(invoice: inv))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start, // Rule 6
                      children: [
                        Container(
                          width: 52, height: 52, 
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.12), 
                            borderRadius: BorderRadius.circular(16),
                          ), 
                          child: Icon(Icons.receipt_rounded, color: c, size: 24),
                        ),
                        const SizedBox(width: 12), // Rule 6
                        Expanded( // Rule 1
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(inv.invoiceNumber, 
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: onBg, letterSpacing: -0.5),
                                maxLines: 1, // Rule 2
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(DateFormat('dd MMM yyyy').format(inv.date.toDate()), 
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                maxLines: 1, // Rule 2
                                overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        const SizedBox(width: 8), // Rule 6
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('$sym${NumberFormat('#,##0.##').format(inv.total)}', 
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: onBg, letterSpacing: -0.5),
                              maxLines: 1, // Rule 2
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.15), 
                              borderRadius: BorderRadius.circular(10),
                            ), 
                            child: Text(status.name.toUpperCase(), 
                                style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                maxLines: 1, // Rule 2
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start, // Rule 6
                      children: [
                        Expanded(child: TextButton.icon(
                          onPressed: () => _showStatusPicker(inv),
                          icon: Icon(Icons.sync_rounded, size: 16, color: primary),
                          label: Text('Update Status', 
                              style: TextStyle(fontSize: 13, color: primary, fontWeight: FontWeight.bold),
                              maxLines: 1, // Rule 2
                              overflow: TextOverflow.ellipsis),
                          style: TextButton.styleFrom(
                            backgroundColor: primary.withOpacity(0.1),
                            minimumSize: const Size(0, 48), 
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: canEdit
                          ? TextButton.icon(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceCreateScreen(existingInvoice: inv))),
                              icon: const Icon(Icons.edit_rounded, size: 16, color: AppColors.warning),
                              label: const Text('Edit', 
                                  style: TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.bold),
                                  maxLines: 1, // Rule 2
                                  overflow: TextOverflow.ellipsis),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.warning.withOpacity(0.1),
                                minimumSize: const Size(0, 48), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )
                          : TextButton.icon(
                              onPressed: () => _duplicate(inv),
                              icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                              label: const Text('Duplicate', 
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                  maxLines: 1, // Rule 2
                                  overflow: TextOverflow.ellipsis),
                              style: TextButton.styleFrom(
                                backgroundColor: AppColors.textSecondary.withOpacity(0.1),
                                minimumSize: const Size(0, 48), 
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            )),
                      ],
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
