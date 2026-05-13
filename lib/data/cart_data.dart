class CartItem {
  final String productId; // ✅ added
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  final String farmer;
  final String unit; // ✅ added
  final int? stock;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.farmer,
    required this.unit,
    this.stock,
  });
}

// GLOBAL CART LIST
List<CartItem> cartItems = [];
