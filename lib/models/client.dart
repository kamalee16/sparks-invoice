class Client {
  final String? id;
  final String name;           // Company Name
  final String contactPerson;
  final String email;
  final String phone;
  final String billingAddress;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String gstNumber;
  final String currency;       // INR or USD
  final String notes;
  final bool isArchived;

  Client({
    this.id,
    required this.name,
    this.contactPerson = '',
    required this.email,
    this.phone = '',
    this.billingAddress = '',
    this.city = '',
    this.state = '',
    this.country = '',
    this.postalCode = '',
    this.gstNumber = '',
    this.currency = 'INR',
    this.notes = '',
    this.isArchived = false,
  });

  Client copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? email,
    String? phone,
    String? billingAddress,
    String? city,
    String? state,
    String? country,
    String? postalCode,
    String? gstNumber,
    String? currency,
    String? notes,
    bool? isArchived,
  }) {
    return Client(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      billingAddress: billingAddress ?? this.billingAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      country: country ?? this.country,
      postalCode: postalCode ?? this.postalCode,
      gstNumber: gstNumber ?? this.gstNumber,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'contactPerson': contactPerson,
        'email': email,
        'phone': phone,
        'billingAddress': billingAddress,
        'city': city,
        'state': state,
        'country': country,
        'postalCode': postalCode,
        'gstNumber': gstNumber,
        'currency': currency,
        'notes': notes,
        'isArchived': isArchived,
      };

  factory Client.fromFirestore(Map<String, dynamic> d, String id) => Client(
        id: id,
        name: d['name'] ?? '',
        contactPerson: d['contactPerson'] ?? '',
        email: d['email'] ?? '',
        phone: d['phone'] ?? '',
        billingAddress: d['billingAddress'] ?? '',
        city: d['city'] ?? '',
        state: d['state'] ?? '',
        country: d['country'] ?? '',
        postalCode: d['postalCode'] ?? '',
        gstNumber: d['gstNumber'] ?? '',
        currency: d['currency'] ?? 'INR',
        notes: d['notes'] ?? '',
        isArchived: d['isArchived'] ?? false,
      );

  @override
  bool operator ==(Object other) => other is Client && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
