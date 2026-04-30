import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../models/invoice.dart';
import '../models/line_item.dart';
import '../services/client_service.dart';
import '../services/invoice_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_drawer.dart';
import 'client_form_screen.dart';
import 'dashboard_screen.dart';

class InvoiceCreateScreen extends StatefulWidget {
  final Invoice? existingInvoice;
  const InvoiceCreateScreen({Key? key, this.existingInvoice}) : super(key: key);
  @override
  State<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends State<InvoiceCreateScreen> {
  final _clientSvc = ClientService();
  final _invoiceSvc = InvoiceService();
  final PageController _pageCtrl = PageController();
  int _step = 0;
  final List<String> steps = ['Client', 'Details', 'Items', 'Tax', 'Info', 'Preview'];

  // Step 1 - Client
  Client? _selectedClient;
  List<Client> _clients = [];

  // Step 2 - Invoice Details
  String _invoiceNumber = 'INV-${DateTime.now().year}-001';
  DateTime _invoiceDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  String _paymentTerms = 'Net 30';
  String _currency = 'INR';
  final _paymentTermsList = ['Net 15', 'Net 30', 'Net 45', 'Net 60', 'Custom'];

  // Step 3 - Line Items
  final List<LineItem> _items = [];

  // Step 4 - Tax & Discount
  bool _taxApplicable = true;
  TaxType _taxType = TaxType.igst;
  double _taxRate = 18.0;
  DiscountType _discountType = DiscountType.flat;
  double _discountValue = 0.0;
  final _discountCtrl = TextEditingController(text: '0');
  final _taxRateCtrl = TextEditingController(text: '18');

  // Step 5 - Additional Info
  final _notesCtrl = TextEditingController(text: 'Thank you for your business.');
  final _termsCtrl = TextEditingController(text: 'Payment is due within the agreed terms.');
  final _bankCtrl = TextEditingController(text: '');

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initInvoiceNumber();
    _loadClients();
    if (widget.existingInvoice != null) _prefill(widget.existingInvoice!);
  }

  Future<void> _initInvoiceNumber() async {
    final n = await _invoiceSvc.getNextInvoiceNumber();
    final year = DateTime.now().year;
    setState(() => _invoiceNumber = 'INV-$year-${n.toString().padLeft(3, '0')}');
  }

  Future<void> _loadClients() async {
    _clientSvc.getClients().listen((list) {
      if (mounted) setState(() => _clients = list);
    });
  }

  void _prefill(Invoice inv) {
    _invoiceNumber = inv.invoiceNumber;
    _invoiceDate = inv.date.toDate();
    _dueDate = inv.dueDate.toDate();
    _paymentTerms = inv.paymentTerms;
    _currency = inv.currency;
    _items.addAll(inv.items);
    _taxApplicable = inv.taxApplicable;
    _taxType = inv.taxType;
    _taxRate = inv.taxRate;
    _taxRateCtrl.text = inv.taxRate.toString();
    _discountType = inv.discountType;
    _discountValue = inv.discountValue;
    _discountCtrl.text = inv.discountValue.toString();
    _notesCtrl.text = inv.notes;
    _termsCtrl.text = inv.termsAndConditions;
    _bankCtrl.text = inv.bankDetails;
  }

  void _applyPaymentTerms(String terms) {
    setState(() {
      _paymentTerms = terms;
      switch (terms) {
        case 'Net 15': _dueDate = _invoiceDate.add(const Duration(days: 15)); break;
        case 'Net 30': _dueDate = _invoiceDate.add(const Duration(days: 30)); break;
        case 'Net 45': _dueDate = _invoiceDate.add(const Duration(days: 45)); break;
        case 'Net 60': _dueDate = _invoiceDate.add(const Duration(days: 60)); break;
        default: break;
      }
    });
  }

  double get _subtotal => _items.fold(0, (s, i) => s + i.subtotal);
  double get _discountAmount => _discountType == DiscountType.percentage ? _subtotal * (_discountValue / 100) : _discountValue;
  double get _discountedSubtotal => _subtotal - _discountAmount;
  double get _taxAmount => _taxApplicable ? _discountedSubtotal * (_taxRate / 100) : 0;
  double get _total => _discountedSubtotal + _taxAmount;

  String _fmt(double v) => NumberFormat('#,##,###.##').format(v);
  String get _sym => _currency == 'USD' ? '\$' : '₹';

  void _goTo(int step) {
    setState(() => _step = step);
    _pageCtrl.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  bool _canProceed() {
    switch (_step) {
      case 0: return _selectedClient != null;
      case 1: return _invoiceNumber.isNotEmpty;
      case 2: return _items.isNotEmpty;
      default: return true;
    }
  }

  Future<void> _saveInvoice({bool asDraft = false}) async {
    if (_selectedClient == null) return;
    
    print("START LOADING");
    if (!mounted) return;
    setState(() => _isSaving = true);
    
    try {
      final inv = Invoice(
        id: widget.existingInvoice?.id,
        invoiceNumber: _invoiceNumber,
        clientRef: FirebaseFirestore.instance.collection('clients').doc(_selectedClient!.id),
        items: _items,
        taxRate: _taxRate,
        taxType: _taxType,
        taxApplicable: _taxApplicable,
        discountType: _discountType,
        discountValue: _discountValue,
        currency: _currency,
        paymentTerms: _paymentTerms,
        date: Timestamp.fromDate(_invoiceDate),
        dueDate: Timestamp.fromDate(_dueDate),
        status: asDraft ? InvoiceStatus.draft : InvoiceStatus.unpaid,
        notes: _notesCtrl.text,
        termsAndConditions: _termsCtrl.text,
        bankDetails: _bankCtrl.text,
        statusHistory: [InvoiceStatusHistory(status: asDraft ? InvoiceStatus.draft : InvoiceStatus.unpaid, changedAt: DateTime.now())],
      );

      String? docId;
      if (widget.existingInvoice != null) {
        await _invoiceSvc.updateInvoice(inv);
        docId = inv.id;
      } else {
        docId = await _invoiceSvc.addInvoice(inv);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      print("STOP LOADING");
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(asDraft ? 'Saved as draft.' : 'Invoice created successfully'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } catch (e) {
      print("SAVE ERROR: $e");
      if (!mounted) return;
      setState(() => _isSaving = false);
      print("STOP LOADING");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted && _isSaving) {
        setState(() => _isSaving = false);
        print("STOP LOADING");
      }
    }
  }

  Future<void> _shareInvoice() async {
    if (_selectedClient == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please complete the invoice first.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final inv = Invoice(
      id: widget.existingInvoice?.id,
      invoiceNumber: _invoiceNumber,
      clientRef: FirebaseFirestore.instance.collection('clients').doc(_selectedClient!.id),
      items: _items,
      taxRate: _taxRate,
      taxType: _taxType,
      taxApplicable: _taxApplicable,
      discountType: _discountType,
      discountValue: _discountValue,
      currency: _currency,
      paymentTerms: _paymentTerms,
      date: Timestamp.fromDate(_invoiceDate),
      dueDate: Timestamp.fromDate(_dueDate),
      status: InvoiceStatus.unpaid,
      notes: _notesCtrl.text,
      termsAndConditions: _termsCtrl.text,
      bankDetails: _bankCtrl.text,
      statusHistory: [InvoiceStatusHistory(status: InvoiceStatus.unpaid, changedAt: DateTime.now())],
    );
    if (widget.existingInvoice != null) {
      _invoiceSvc.updateInvoice(inv);
    } else {
      _invoiceSvc.addInvoice(inv);
    }
    if (!mounted) return;
    _showShareSheet(inv);
  }

  void _showShareSheet(Invoice inv) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Share Invoice', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 20),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.share_rounded, color: AppColors.primary),
            ),
            title: const Text('Share via WhatsApp / Email', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Send PDF to client'),
            onTap: () async {
              Navigator.pop(context);
              final client = await ClientService().getClient(inv.clientRef.id);
              if (client != null && mounted) {
                await PdfService().shareInvoicePdf(inv, client);
              }
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.download_rounded, color: AppColors.success),
            ),
            title: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Save to device'),
            onTap: () async {
              Navigator.pop(context);
              final client = await ClientService().getClient(inv.clientRef.id);
              if (client != null && mounted) {
                await PdfService().openInvoicePdf(inv, client);
              }
            },
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/create-invoice'),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.existingInvoice != null ? 'Edit Invoice' : 'New Invoice'),
        actions: [
          if (_step == 5 && !_isSaving)
            TextButton.icon(
              onPressed: () => _saveInvoice(),
              icon: const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
              label: const Text('Save', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _StepIndicator(steps: steps, current: _step, onTap: (i) { if (i < _step) _goTo(i); }),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _Step1Client(),
          _Step2Details(),
          _Step3Items(),
          _Step4Tax(),
          _Step5Info(),
          _Step6Preview(),
        ],
      ),
      bottomNavigationBar: _BottomNav(),
    );
  }

  Widget _Step1Client() {
    final matched = _selectedClient == null ? null
        : _clients.firstWhere((c) => c.id == _selectedClient!.id, orElse: () => _clients.isEmpty ? _selectedClient! : _clients.first);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card('Select Client', Icons.person_outline_rounded, Column(children: [
          if (_clients.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No clients found.', style: TextStyle(color: Colors.grey)))
          else
            DropdownButtonFormField<Client>(
              value: matched,
              hint: const Text('Search & select client'),
              isExpanded: true,
              items: _clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() {
                _selectedClient = v;
                if (v != null) _currency = v.currency;
              }),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientFormScreen()));
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add New Client'),
          ),
          if (_selectedClient != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.darkBg, 
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withOpacity(0.1), 
                    child: Text(_selectedClient!.name[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18))
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_selectedClient!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                    if (_selectedClient!.contactPerson.isNotEmpty) Text(_selectedClient!.contactPerson, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(_selectedClient!.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ])),
                ]),
                if (_selectedClient!.billingAddress.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${_selectedClient!.billingAddress}, ${_selectedClient!.city}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                    ],
                  ),
                ],
              ]),
            ),
          ],
        ])),
      ]),
    );
  }

  Widget _Step2Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card('Invoice Details', Icons.receipt_outlined, Column(children: [
          TextFormField(
            initialValue: _invoiceNumber,
            decoration: const InputDecoration(labelText: 'Invoice Number', prefixIcon: Icon(Icons.tag_rounded)),
            onChanged: (v) => _invoiceNumber = v,
          ),
          const SizedBox(height: 12),
          _dateTile('Invoice Date', _invoiceDate, (d) => setState(() { _invoiceDate = d; _applyPaymentTerms(_paymentTerms); })),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _paymentTerms,
            decoration: const InputDecoration(labelText: 'Payment Terms', prefixIcon: Icon(Icons.schedule_outlined)),
            items: _paymentTermsList.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) { if (v != null) _applyPaymentTerms(v); },
          ),
          const SizedBox(height: 12),
          _dateTile('Due Date', _dueDate, (d) => setState(() => _dueDate = d)),
          const SizedBox(height: 12),
          const Text('Currency', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(children: ['INR', 'USD'].map((cur) => Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(label: Text(cur), selected: _currency == cur, onSelected: (_) => setState(() => _currency = cur), selectedColor: Colors.indigo.withOpacity(0.15)),
          ))).toList()),
        ])),
      ]),
    );
  }

  Widget _Step3Items() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final listHeight = constraints.maxHeight.isInfinite
            ? 400.0
            : constraints.maxHeight - 80; // 80 for the button area
        return Column(children: [
          SizedBox(
            height: listHeight,
            child: _items.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_shopping_cart_rounded, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('No items yet. Tap + to add.', style: TextStyle(color: Colors.grey.shade500)),
                  ]))
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    itemCount: _items.length,
                    onReorder: (o, n) => setState(() {
                      final item = _items.removeAt(o);
                      _items.insert(n > o ? n - 1 : n, item);
                    }),
                    itemBuilder: (_, i) {
                      final item = _items[i];
                      return Card(
                        key: ValueKey(i),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item.quantity} x $_sym${_fmt(item.price)}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('$_sym${_fmt(item.subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                              onPressed: () => setState(() => _items.removeAt(i)),
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _addItemDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Item'),
            ),
          ),
        ]);
      },
    );
  }

  void _addItemDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final fk = GlobalKey<FormState>();
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Line Item'),
      content: SingleChildScrollView(
        child: Form(key: fk, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Description *', prefixIcon: Icon(Icons.description_outlined)), validator: (v) => v!.trim().isEmpty ? 'Required' : null),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextFormField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Qty *'), keyboardType: TextInputType.number, validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(controller: priceCtrl, decoration: InputDecoration(labelText: 'Unit Price *', prefixText: _sym), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
          ]),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (fk.currentState!.validate()) {
              setState(() => _items.add(LineItem(name: nameCtrl.text.trim(), quantity: int.tryParse(qtyCtrl.text) ?? 1, price: double.tryParse(priceCtrl.text) ?? 0)));
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
          child: const Text('Add'),
        ),
      ],
    ));
  }

  Widget _Step4Tax() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card('Discount', Icons.discount_outlined, Column(children: [
          Row(children: [
            const Text('Type:'),
            const SizedBox(width: 12),
            ChoiceChip(label: const Text('Flat'), selected: _discountType == DiscountType.flat, onSelected: (_) => setState(() => _discountType = DiscountType.flat), selectedColor: AppColors.primary.withOpacity(0.2)),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('%'), selected: _discountType == DiscountType.percentage, onSelected: (_) => setState(() => _discountType = DiscountType.percentage), selectedColor: AppColors.primary.withOpacity(0.2)),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _discountCtrl,
            decoration: InputDecoration(
              labelText: _discountType == DiscountType.flat ? 'Discount Amount ($_sym)' : 'Discount (%)',
              prefixIcon: const Icon(Icons.remove_circle_outline),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => setState(() => _discountValue = double.tryParse(v) ?? 0),
          ),
          const SizedBox(height: 8),
          _summaryRow('Discount', _discountAmount, isNegative: true),
          _summaryRow('Discounted Subtotal', _discountedSubtotal),
        ])),
        const SizedBox(height: 16),
        _card('Tax', Icons.account_balance_outlined, Column(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('GST Applicable'),
            value: _taxApplicable,
            onChanged: (v) => setState(() => _taxApplicable = v),
          ),
          if (_taxApplicable) ...[
            if (_currency == 'INR') ...[
              Row(children: [
                const Text('Tax Type:'),
                const SizedBox(width: 12),
                ChoiceChip(label: const Text('IGST'), selected: _taxType == TaxType.igst, onSelected: (_) => setState(() { _taxType = TaxType.igst; _taxRate = 18; _taxRateCtrl.text = '18'; }), selectedColor: AppColors.primary.withOpacity(0.2)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('CGST+SGST'), selected: _taxType == TaxType.cgstSgst, onSelected: (_) => setState(() { _taxType = TaxType.cgstSgst; _taxRate = 18; _taxRateCtrl.text = '18'; }), selectedColor: AppColors.primary.withOpacity(0.2)),
              ]),
              const SizedBox(height: 12),
              if (_taxType == TaxType.igst)
                TextFormField(controller: _taxRateCtrl, decoration: const InputDecoration(labelText: 'IGST Rate (%)', prefixIcon: Icon(Icons.percent_rounded)), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => setState(() => _taxRate = double.tryParse(v) ?? 18))
              else
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(
                    controller: _taxRateCtrl,
                    decoration: const InputDecoration(labelText: 'Total GST Rate (%)', prefixIcon: Icon(Icons.percent_rounded)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => setState(() => _taxRate = double.tryParse(v) ?? 18),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      Expanded(child: _taxSplitTile('CGST', _taxRate / 2, _discountedSubtotal * (_taxRate / 2 / 100))),
                      Container(width: 1, height: 36, color: AppColors.success.withOpacity(0.2)),
                      Expanded(child: _taxSplitTile('SGST', _taxRate / 2, _discountedSubtotal * (_taxRate / 2 / 100))),
                    ]),
                  ),
                ]),
            ] else
              TextFormField(controller: _taxRateCtrl, decoration: const InputDecoration(labelText: 'Tax Rate (%)', prefixIcon: Icon(Icons.percent_rounded)), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (v) => setState(() => _taxRate = double.tryParse(v) ?? 0)),
            const SizedBox(height: 8),
            _summaryRow('Tax Amount', _taxAmount),
          ],
        ])),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Grand Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
            Text('$_sym${_fmt(_total)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: -1.0)),
          ]),
        ),
      ]),
    );
  }

  Widget _Step5Info() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card('Notes / Memo', Icons.notes_outlined, TextFormField(controller: _notesCtrl, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. Thank you for your business.'))),
        const SizedBox(height: 16),
        _card('Terms & Conditions', Icons.gavel_outlined, TextFormField(controller: _termsCtrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Payment terms and conditions...'))),
        const SizedBox(height: 16),
        _card('Bank Details', Icons.account_balance_outlined, TextFormField(controller: _bankCtrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Bank name, account number, IFSC...'))),
      ]),
    );
  }

  Widget _Step6Preview() {
    if (_selectedClient == null) {
      return const Center(child: Text("Select a client"));
    }
    final fmt = DateFormat('dd MMM yyyy');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color, 
            borderRadius: BorderRadius.circular(24), 
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), 
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Sparks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: -0.5)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('INVOICE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, letterSpacing: 2)),
                const SizedBox(height: 4),
                Text(_invoiceNumber, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
              ]),
            ]),
            const Divider(height: 40, color: Colors.white10),
            // ── FROM / TO SECTION ──────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FROM (Company) — LEFT
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('From:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      const Text('Sparks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      const SizedBox(height: 4),
                      const Text('Welbuilt AI Solutions Pvt Ltd', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const Text('India', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      const Text('contactsparksai@gmail.com', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // TO (Client) — RIGHT BLOCK (label right, content left)
                if (_selectedClient != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'To:',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedClient!.name,
                          softWrap: true,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        if (_selectedClient!.contactPerson.isNotEmpty) ...[
                          Text(_selectedClient!.contactPerson, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                        ],
                        if (_selectedClient!.phone.isNotEmpty) ...[
                          Text('Phone: ${_selectedClient!.phone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                        ],
                        Text('Email: ${_selectedClient!.email}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        if (_selectedClient!.billingAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedClient!.billingAddress}${_selectedClient!.city.isNotEmpty ? ", ${_selectedClient!.city}" : ""}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            softWrap: true,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _infoCol('Invoice Date', fmt.format(_invoiceDate)),
              _infoCol('Due Date', fmt.format(_dueDate)),
              _infoCol('Currency', _currency),
            ]),
            const Divider(height: 40, color: Colors.white10),
            const Text('LINE ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 1.5)),
            const SizedBox(height: 16),
            ..._items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${item.quantity} x $_sym${_fmt(item.price)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ])),
                Text('$_sym${_fmt(item.subtotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
              ]),
            )),
            const Divider(height: 32, color: Colors.white10),
            _previewRow('Subtotal', _subtotal),
            if (_discountValue > 0) _previewRow('Discount', _discountAmount, isNeg: true),
            if (_taxApplicable) _previewRow('Tax (${_taxRate.toStringAsFixed(0)}%)', _taxAmount),
            const SizedBox(height: 12),
            _previewRow('Total', _total, isBold: true),
            if (_notesCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.darkBg, borderRadius: BorderRadius.circular(12)),
                child: Text('Note: ${_notesCtrl.text}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 24),
        if (_isSaving)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: _shareInvoice,
              icon: const Icon(Icons.share_rounded, size: 18),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              label: const Text('Share PDF', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
            const SizedBox(width: 16),
            Expanded(child: ElevatedButton(
              onPressed: () => _saveInvoice(), 
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 56), 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Finalize Invoice', style: TextStyle(fontWeight: FontWeight.bold))
            )),
          ]),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _BottomNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: [
          if (_step > 0)
            Expanded(child: OutlinedButton(onPressed: () => _goTo(_step - 1), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Back'))),
          if (_step > 0) const SizedBox(width: 12),
          if (_step < 5)
            Expanded(child: ElevatedButton(
              onPressed: _canProceed() ? () => _goTo(_step + 1) : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Next'),
            )),
        ]),
      ),
    );
  }

  Widget _card(String title, IconData icon, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color, 
        borderRadius: BorderRadius.circular(24), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1), 
            blurRadius: 10, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.5)),
        ]),
        const SizedBox(height: 20),
        child,
      ]),
    );
  }

  Widget _dateTile(String label, DateTime date, ValueChanged<DateTime> onPick) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context, 
          initialDate: date, 
          firstDate: DateTime(2020), 
          lastDate: DateTime(2030),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: AppColors.darkSurface,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.calendar_today_rounded, size: 18, color: primary),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const Spacer(),
          Icon(Icons.edit_rounded, size: 18, color: AppColors.textMuted.withOpacity(0.5)),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        Text('${isNegative ? "- " : ""}$_sym${_fmt(value)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }

  Widget _previewRow(String label, double value, {bool isBold = false, bool isNeg = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 16 : 14)),
        Text('${isNeg ? "- " : ""}$_sym${_fmt(value)}', style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w600, fontSize: isBold ? 16 : 14, color: isBold ? Colors.indigo : null)),
      ]),
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }
  Widget _taxSplitTile(String label, double rate, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        Text('$label (${rate.toStringAsFixed(1)}%)',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('$_sym${_fmt(amount)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
      ]),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final List<String> steps;
  final int current;
  final ValueChanged<int> onTap;
  const _StepIndicator({required this.steps, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: steps.length,
        itemBuilder: (_, i) {
          final done = i < current;
          final active = i == current;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? primary : done ? AppColors.success.withOpacity(0.1) : AppColors.darkSurface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: active ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
              ),
              child: Row(children: [
                if (done) 
                  const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success)
                else 
                  Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? Colors.white : AppColors.textMuted)),
                const SizedBox(width: 8),
                Text(steps[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? Colors.white : done ? AppColors.success : AppColors.textMuted)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

