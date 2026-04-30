import 'package:cloud_firestore/cloud_firestore.dart';
import 'line_item.dart';

enum InvoiceStatus { draft, unpaid, paid, partiallyPaid, overdue, cancelled }

enum TaxType { igst, cgstSgst, generic }

enum DiscountType { percentage, flat }

class InvoiceStatusHistory {
  final InvoiceStatus status;
  final DateTime changedAt;
  final double? amountPaid;

  InvoiceStatusHistory({required this.status, required this.changedAt, this.amountPaid});

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'changedAt': Timestamp.fromDate(changedAt),
        if (amountPaid != null) 'amountPaid': amountPaid,
      };

  factory InvoiceStatusHistory.fromJson(Map<String, dynamic> d) =>
      InvoiceStatusHistory(
        status: InvoiceStatus.values.firstWhere((e) => e.name == d['status'], orElse: () => InvoiceStatus.unpaid),
        changedAt: (d['changedAt'] as Timestamp).toDate(),
        amountPaid: d['amountPaid']?.toDouble(),
      );
}

class Invoice {
  final String? id;
  final String invoiceNumber;
  final DocumentReference clientRef;
  final List<LineItem> items;
  final double taxRate;
  final TaxType taxType;
  final bool taxApplicable;
  final DiscountType discountType;
  final double discountValue;
  final String currency;
  final String paymentTerms;
  final Timestamp date;
  final Timestamp dueDate;
  final InvoiceStatus status;
  final double amountPaid;
  final String notes;
  final String termsAndConditions;
  final String bankDetails;
  final List<InvoiceStatusHistory> statusHistory;

  Invoice({
    this.id,
    required this.invoiceNumber,
    required this.clientRef,
    required this.items,
    this.taxRate = 18.0,
    this.taxType = TaxType.igst,
    this.taxApplicable = true,
    this.discountType = DiscountType.flat,
    this.discountValue = 0.0,
    this.currency = 'INR',
    this.paymentTerms = 'Net 30',
    required this.date,
    required this.dueDate,
    required this.status,
    this.amountPaid = 0.0,
    this.notes = '',
    this.termsAndConditions = '',
    this.bankDetails = '',
    this.statusHistory = const [],
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);

  double get discountAmount {
    if (discountType == DiscountType.percentage) {
      return subtotal * (discountValue / 100);
    }
    return discountValue;
  }

  double get discountedSubtotal => subtotal - discountAmount;

  double get taxAmount {
    if (!taxApplicable) return 0;
    return discountedSubtotal * (taxRate / 100);
  }

  double get total => discountedSubtotal + taxAmount;

  InvoiceStatus get effectiveStatus {
    if (status == InvoiceStatus.paid || status == InvoiceStatus.cancelled || status == InvoiceStatus.draft) {
      return status;
    }
    if (status == InvoiceStatus.partiallyPaid) {
      if (dueDate.toDate().isBefore(DateTime.now())) return InvoiceStatus.overdue;
      return InvoiceStatus.partiallyPaid;
    }
    if (dueDate.toDate().isBefore(DateTime.now())) return InvoiceStatus.overdue;
    return status;
  }

  static List<InvoiceStatus> allowedTransitions(InvoiceStatus from) {
    switch (from) {
      case InvoiceStatus.draft: return [InvoiceStatus.unpaid];
      case InvoiceStatus.unpaid: return [InvoiceStatus.paid, InvoiceStatus.partiallyPaid, InvoiceStatus.cancelled];
      case InvoiceStatus.partiallyPaid: return [InvoiceStatus.paid, InvoiceStatus.cancelled];
      case InvoiceStatus.overdue: return [InvoiceStatus.paid, InvoiceStatus.partiallyPaid, InvoiceStatus.cancelled];
      case InvoiceStatus.paid: return [];
      case InvoiceStatus.cancelled: return [];
    }
  }

  Invoice copyWith({
    String? id,
    String? invoiceNumber,
    DocumentReference? clientRef,
    List<LineItem>? items,
    double? taxRate,
    TaxType? taxType,
    bool? taxApplicable,
    DiscountType? discountType,
    double? discountValue,
    String? currency,
    String? paymentTerms,
    Timestamp? date,
    Timestamp? dueDate,
    InvoiceStatus? status,
    double? amountPaid,
    String? notes,
    String? termsAndConditions,
    String? bankDetails,
    List<InvoiceStatusHistory>? statusHistory,
  }) {
    return Invoice(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      clientRef: clientRef ?? this.clientRef,
      items: items ?? this.items,
      taxRate: taxRate ?? this.taxRate,
      taxType: taxType ?? this.taxType,
      taxApplicable: taxApplicable ?? this.taxApplicable,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      currency: currency ?? this.currency,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      amountPaid: amountPaid ?? this.amountPaid,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      bankDetails: bankDetails ?? this.bankDetails,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }

  Map<String, dynamic> toJson() => {
        'invoiceNumber': invoiceNumber,
        'clientRef': clientRef,
        'items': items.map((i) => i.toJson()).toList(),
        'taxRate': taxRate,
        'taxType': taxType.name,
        'taxApplicable': taxApplicable,
        'discountType': discountType.name,
        'discountValue': discountValue,
        'currency': currency,
        'paymentTerms': paymentTerms,
        'date': date,
        'dueDate': dueDate,
        'status': status.name,
        'amountPaid': amountPaid,
        'notes': notes,
        'termsAndConditions': termsAndConditions,
        'bankDetails': bankDetails,
        'subtotal': subtotal,
        'total': total,
        'statusHistory': statusHistory.map((h) => h.toJson()).toList(),
      };

  factory Invoice.fromFirestore(Map<String, dynamic> d, String id) => Invoice(
        id: id,
        invoiceNumber: d['invoiceNumber'] ?? id.substring(0, 8).toUpperCase(),
        clientRef: d['clientRef'],
        items: (d['items'] as List).map((i) => LineItem.fromFirestore(i)).toList(),
        taxRate: (d['taxRate'] ?? d['tax'] ?? 18.0).toDouble(),
        taxType: TaxType.values.firstWhere((e) => e.name == d['taxType'], orElse: () => TaxType.igst),
        taxApplicable: d['taxApplicable'] ?? true,
        discountType: DiscountType.values.firstWhere((e) => e.name == d['discountType'], orElse: () => DiscountType.flat),
        discountValue: (d['discountValue'] ?? d['discount'] ?? 0.0).toDouble(),
        currency: d['currency'] ?? 'INR',
        paymentTerms: d['paymentTerms'] ?? 'Net 30',
        date: d['date'] ?? Timestamp.now(),
        dueDate: d['dueDate'] ?? Timestamp.now(),
        status: InvoiceStatus.values.firstWhere((e) => e.name == d['status'], orElse: () => InvoiceStatus.unpaid),
        amountPaid: (d['amountPaid'] ?? 0.0).toDouble(),
        notes: d['notes'] ?? '',
        termsAndConditions: d['termsAndConditions'] ?? '',
        bankDetails: d['bankDetails'] ?? '',
        statusHistory: d['statusHistory'] != null
            ? (d['statusHistory'] as List).map((h) => InvoiceStatusHistory.fromJson(h)).toList()
            : [],
      );
}
