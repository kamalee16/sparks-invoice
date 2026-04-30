import 'package:flutter/material.dart';
import '../models/client.dart';
import '../services/client_service.dart';
import '../theme/app_colors.dart';

class ClientFormScreen extends StatefulWidget {
  final Client? client;
  const ClientFormScreen({Key? key, this.client}) : super(key: key);
  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ClientService _svc = ClientService();
  bool _isSaving = false;
  bool _isEditing = false;

  late final TextEditingController _name, _contact, _email, _phone,
      _address, _city, _state, _country, _postal, _gst, _notes;
  String _currency = 'INR';

  bool get _isNew => widget.client == null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _name = TextEditingController(text: c?.name ?? '');
    _contact = TextEditingController(text: c?.contactPerson ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _address = TextEditingController(text: c?.billingAddress ?? '');
    _city = TextEditingController(text: c?.city ?? '');
    _state = TextEditingController(text: c?.state ?? '');
    _country = TextEditingController(text: c?.country ?? '');
    _postal = TextEditingController(text: c?.postalCode ?? '');
    _gst = TextEditingController(text: c?.gstNumber ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _currency = c?.currency ?? 'INR';
    _isEditing = _isNew;
  }

  @override
  void dispose() {
    for (final c in [_name, _contact, _email, _phone, _address, _city, _state, _country, _postal, _gst, _notes]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    print("START LOADING");
    setState(() => _isSaving = true);

    try {
      // Duplicate name check
      final isDup = await _svc.isDuplicateName(_name.text.trim(), excludeId: widget.client?.id);
      if (isDup && mounted) {
        setState(() => _isSaving = false);
        print("STOP LOADING");
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A client with this company name already exists.'),
          backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      final client = Client(
        id: widget.client?.id,
        name: _name.text.trim(),
        contactPerson: _contact.text.trim(),
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        billingAddress: _address.text.trim(),
        city: _city.text.trim(),
        state: _state.text.trim(),
        country: _country.text.trim(),
        postalCode: _postal.text.trim(),
        gstNumber: _gst.text.trim(),
        currency: _currency,
        notes: _notes.text.trim(),
      );

      if (_isNew) {
        await _svc.addClient(client);
      } else {
        if (!mounted) return;
        final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Update Client'),
          content: const Text('Updating client details will not affect previously generated invoices. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)), child: const Text('Update')),
          ],
        ));
        if (confirm != true) {
          setState(() => _isSaving = false);
          print("STOP LOADING");
          return;
        }
        await _svc.updateClient(client);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        print("STOP LOADING");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isNew ? 'Client added successfully' : 'Client updated successfully!'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      print("SAVE ERROR: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        print("STOP LOADING");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted && _isSaving) {
        setState(() => _isSaving = false);
        print("STOP LOADING");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Client' : widget.client!.name),
        actions: [
          if (!_isNew && !_isEditing)
            TextButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _section('Company Details', Icons.business_outlined, [
              _field(_name, 'Company Name *', Icons.business_outlined,
                  validator: (v) => v!.trim().isEmpty ? 'Company name is required' : null,
                  enabled: _isEditing),
              _field(_contact, 'Contact Person', Icons.person_outline, enabled: _isEditing),
            ]),
            const SizedBox(height: 16),
            _section('Contact Info', Icons.contact_phone_outlined, [
              _field(_email, 'Email Address *', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v!.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                  enabled: _isEditing),
              _field(_phone, 'Phone Number', Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v!.trim().isNotEmpty && !RegExp(r'^\+?[\d\s\-]{7,15}$').hasMatch(v.trim())) return 'Enter a valid phone number';
                    return null;
                  },
                  enabled: _isEditing),
            ]),
            const SizedBox(height: 16),
            _section('Billing Address', Icons.location_on_outlined, [
              _field(_address, 'Street Address', Icons.home_outlined, enabled: _isEditing),
              Row(children: [
                Expanded(child: _field(_city, 'City', Icons.location_city_outlined, enabled: _isEditing)),
                const SizedBox(width: 12),
                Expanded(child: _field(_state, 'State / Province', Icons.map_outlined, enabled: _isEditing)),
              ]),
              Row(children: [
                Expanded(child: _field(_country, 'Country', Icons.flag_outlined, enabled: _isEditing)),
                const SizedBox(width: 12),
                Expanded(child: _field(_postal, 'Postal Code', Icons.markunread_mailbox_outlined, enabled: _isEditing)),
              ]),
            ]),
            const SizedBox(height: 16),
            _section('Tax & Preferences', Icons.receipt_outlined, [
              _field(_gst, 'GST / Tax Number (Optional)', Icons.numbers_outlined, enabled: _isEditing),
              if (_isEditing) ...[
                const SizedBox(height: 8),
                const Text('Preferred Currency', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(children: ['INR', 'USD'].map((cur) => Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text(cur, style: TextStyle(fontWeight: FontWeight.bold, color: _currency == cur ? Colors.white : AppColors.textSecondary)),
                    selected: _currency == cur,
                    onSelected: (_) => setState(() => _currency = cur),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.darkBg,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ))).toList()),
              ] else
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.currency_exchange_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: const Text('Preferred Currency', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(_currency, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            _section('Notes', Icons.notes_outlined, [
              _field(_notes, 'Notes (Optional)', Icons.notes_outlined, maxLines: 3, enabled: _isEditing),
            ]),
            const SizedBox(height: 28),
            if (_isEditing)
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _save,
                      child: Text(_isNew ? 'Save Client' : 'Update Client'),
                    ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
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
        ...children.map((w) => Padding(padding: const EdgeInsets.only(bottom: 16), child: w)),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator, int maxLines = 1, bool enabled = true}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
