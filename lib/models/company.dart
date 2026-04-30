class Company {
  final String name;
  final String legalName;
  final String address;
  final String addressImageUrl;
  final String email;
  final String phone;
  final String website;
  final String logoUrl;
  final String country;

  const Company({
    this.name = '',
    this.legalName = '',
    this.address = '',
    this.addressImageUrl = '',
    this.email = '',
    this.phone = '',
    this.website = '',
    this.logoUrl = '',
    this.country = '',
  });

  Map<String, dynamic> toJson() => {
        'companyName': name,
        'legalName': legalName,
        'address': address,
        'addressImageUrl': addressImageUrl,
        'email': email,
        'phone': phone,
        'website': website,
        'logoUrl': logoUrl,
        'country': country,
      };

  factory Company.fromJson(Map<String, dynamic> d) => Company(
        name: d['companyName'] ?? d['name'] ?? '',
        legalName: d['legalName'] ?? '',
        address: d['address'] ?? '',
        addressImageUrl: d['addressImageUrl'] ?? '',
        email: d['email'] ?? '',
        phone: d['phone'] ?? '',
        website: d['website'] ?? '',
        logoUrl: d['logoUrl'] ?? '',
        country: d['country'] ?? '',
      );

  static const empty = Company();
}
