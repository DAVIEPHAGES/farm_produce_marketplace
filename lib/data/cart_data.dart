class CartItem {
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  final String farmer;

  CartItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
    required this.farmer,
  });
}

// GLOBAL CART LIST
List<CartItem> cartItems = [];