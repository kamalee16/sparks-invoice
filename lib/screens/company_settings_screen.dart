import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/company.dart';
import '../services/company_service.dart';
import '../theme/app_colors.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({Key? key}) : super(key: key);
  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _svc     = CompanyService();
  final _formKey = GlobalKey<FormState>();
  bool _saving   = false;

  File? _pickedLogo;
  File? _pickedAddressImg;

  late final TextEditingController _name, _address, _email, _phone, _website;
  String _logoUrl        = '';
  String _addressImgUrl  = '';

  @override
  void initState() {
    super.initState();
    _name    = TextEditingController();
    _address = TextEditingController();
    _email   = TextEditingController();
    _phone   = TextEditingController();
    _website = TextEditingController();

    _svc.getCompany().first.then((c) {
      if (!mounted) return;
      setState(() {
        _name.text    = c.name;
        _address.text = c.address;
        _email.text   = c.email;
        _phone.text   = c.phone;
        _website.text = c.website;
        _logoUrl       = c.logoUrl;
        _addressImgUrl = c.addressImageUrl;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _email, _phone, _website]) c.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedLogo = File(picked.path));
  }

  Future<void> _pickAddressImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => _pickedAddressImg = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String logoUrl       = _logoUrl;
      String addressImgUrl = _addressImgUrl;

      if (_pickedLogo != null)        logoUrl       = await _svc.uploadLogo(_pickedLogo!);
      if (_pickedAddressImg != null)  addressImgUrl = await _svc.uploadAddressImage(_pickedAddressImg!);

      await _svc.saveCompany(Company(
        name:             _name.text.trim(),
        address:          _address.text.trim(),
        addressImageUrl:  addressImgUrl,
        email:            _email.text.trim(),
        phone:            _phone.text.trim(),
        website:          _website.text.trim(),
        logoUrl:          logoUrl,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Company settings saved!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary  = Theme.of(context).colorScheme.primary;
    final cardBg   = Theme.of(context).cardColor;
    final divColor = Theme.of(context).dividerColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _save,
              child: Text('Save', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
            )
          else
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── Logo section ───────────────────────────────────────────────
            _SectionCard(
              title: 'Company Logo',
              icon: Icons.image_outlined,
              child: Column(children: [
                GestureDetector(
                  onTap: _pickLogo,
                  child: Container(
                    width: double.infinity, height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withOpacity(0.1)),
                    ),
                    child: _pickedLogo != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.file(_pickedLogo!, fit: BoxFit.contain))
                        : _logoUrl.isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(9), child: CachedNetworkImage(imageUrl: _logoUrl, fit: BoxFit.contain, placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)), errorWidget: (_, __, ___) => _placeholder(primary, 'Upload Logo')))
                            : _placeholder(primary, 'Upload Logo'),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.upload_rounded, size: 16),
                  label: Text(_pickedLogo != null || _logoUrl.isNotEmpty ? 'Change Logo' : 'Upload Company Logo'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
                if (_pickedLogo != null) ...[
                  const SizedBox(height: 4),
                  Text('Logo selected — tap Save to upload', style: TextStyle(color: AppColors.success, fontSize: 11), textAlign: TextAlign.center),
                ],
              ]),
            ),
            const SizedBox(height: 16),

            // ── Company details ────────────────────────────────────────────
            _SectionCard(
              title: 'Company Details',
              icon: Icons.business_outlined,
              child: Column(children: [
                _field(_name, 'Company Name *', Icons.business_outlined, validator: (v) => v!.trim().isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                _field(_email, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _field(_phone, 'Phone', Icons.phone_outlined, keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _field(_website, 'Website', Icons.language_outlined),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Address section ────────────────────────────────────────────
            _SectionCard(
              title: 'Company Address',
              icon: Icons.location_on_outlined,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Text address (preferred — used in PDF as text)
                _field(_address, 'Address (text)', Icons.edit_location_alt_outlined, maxLines: 3),
                const SizedBox(height: 8),
                Text(
                  'Text address is used in invoice PDF. If you also have an address image, upload it below.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 14),

                // Address image (optional)
                Text('Address Image (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickAddressImage,
                  child: Container(
                    width: double.infinity, height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: primary.withOpacity(0.1)),
                    ),
                    child: _pickedAddressImg != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.file(_pickedAddressImg!, fit: BoxFit.contain))
                        : _addressImgUrl.isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(9), child: CachedNetworkImage(imageUrl: _addressImgUrl, fit: BoxFit.contain, placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)), errorWidget: (_, __, ___) => _placeholder(primary, 'Upload Address Image')))
                            : _placeholder(primary, 'Upload Address Image (optional)'),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _pickAddressImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  label: Text(_pickedAddressImg != null || _addressImgUrl.isNotEmpty ? 'Change Address Image' : 'Upload Address Image'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
                if (_pickedAddressImg != null) ...[
                  const SizedBox(height: 4),
                  Text('Image selected — tap Save to upload', style: TextStyle(color: AppColors.success, fontSize: 11), textAlign: TextAlign.center),
                ],
                if (_addressImgUrl.isNotEmpty && _address.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Text address will be used in PDF (preferred over image)', style: TextStyle(color: AppColors.success, fontSize: 11))),
                    ]),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save Company Settings'),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _placeholder(Color primary, String label) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.add_photo_alternate_outlined, color: primary, size: 26),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: primary, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
    ],
  );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType, String? Function(String?)? validator, int maxLines = 1}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );
}

// ── Reusable section card ─────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.5)),
        ]),
        const SizedBox(height: 20),
        child,
      ]),
    );
  }
}
