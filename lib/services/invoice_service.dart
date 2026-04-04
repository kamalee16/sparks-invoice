import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/invoice.dart';

class InvoiceService {
  final CollectionReference _col = FirebaseFirestore.instance.collection('invoices');

  Future<String> addInvoice(Invoice invoice) async {
    final ref = await _col.add(invoice.toJson());
    return ref.id;
  }

  Future<void> updateInvoice(Invoice invoice) {
    return _col.doc(invoice.id).update(invoice.toJson());
  }

  Future<void> updateStatus(String invoiceId, InvoiceStatus newStatus, {double? amountPaid}) async {
    final history = InvoiceStatusHistory(status: newStatus, changedAt: DateTime.now(), amountPaid: amountPaid);
    await _col.doc(invoiceId).update({
      'status': newStatus.name,
      if (amountPaid != null) 'amountPaid': amountPaid,
      'statusHistory': FieldValue.arrayUnion([history.toJson()]),
    });
  }

  Stream<List<Invoice>> getInvoices() {
    return _col.orderBy('date', descending: true).snapshots().map((s) =>
        s.docs.map((d) => Invoice.fromFirestore(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Future<int> getNextInvoiceNumber() async {
    final snap = await _col.get();
    return snap.docs.length + 1;
  }

  Future<void> deleteInvoice(String id) => _col.doc(id).delete();
}
