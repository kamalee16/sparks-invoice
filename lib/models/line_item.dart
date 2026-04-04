class LineItem {
  final String name;
  final int quantity;
  final double price;

  LineItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  double get subtotal => quantity * price;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }

  factory LineItem.fromFirestore(Map<String, dynamic> firestore) {
    return LineItem(
      name: firestore['name'] ?? '',
      quantity: firestore['quantity'] ?? 0,
      price: firestore['price'] ?? 0.0,
    );
  }
}
