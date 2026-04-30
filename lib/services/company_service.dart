import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/company.dart';

class CompanyService {
  static final CompanyService _instance = CompanyService._internal();
  factory CompanyService() => _instance;
  CompanyService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  Company? _cachedCompany;

  Future<void> init() async {
    try {
      final doc = await _db.collection('company_settings').doc('sparks_ai').get();
      if (doc.exists) {
        _cachedCompany = Company.fromJson(doc.data()!);
      } else {
        final defaultData = {
          'companyName': "Sparks AI",
          'legalName': "Welbuilt AI Solutions Private Limited",
          'country': "India",
          'email': "contactsparksai@gmail.com",
          'website': "sparksai.in",
          'phone': "+91 93453 64408",
          'address': "India",
        };
        await _db.collection('company_settings').doc('sparks_ai').set(defaultData);
        _cachedCompany = Company.fromJson(defaultData);
      }
    } catch (e) {
      print("Error fetching company details: $e");
    }
  }

  Company getCompanyDetails() {
    return _cachedCompany ?? const Company(
      name: "Sparks AI",
      legalName: "Welbuilt AI Solutions Private Limited",
      country: "India",
      email: "contactsparksai@gmail.com",
      website: "sparksai.in",
      phone: "+91 93453 64408",
      address: "India",
    );
  }

  // ── Restore Missing Methods ────────────────────────────────────────────────

  Stream<Company> getCompany() {
    return _db.collection('company_settings').doc('sparks_ai').snapshots().map((doc) {
      if (doc.exists) {
        _cachedCompany = Company.fromJson(doc.data()!);
        return _cachedCompany!;
      }
      return getCompanyDetails();
    });
  }

  Future<void> saveCompany(Company company) async {
    await _db.collection('company_settings').doc('sparks_ai').set(company.toJson());
    _cachedCompany = company;
  }

  Future<String> uploadLogo(File file) async {
    final ref = _storage.ref().child('company/logo.png');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<String> uploadAddressImage(File file) async {
    final ref = _storage.ref().child('company/address_image.png');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}
