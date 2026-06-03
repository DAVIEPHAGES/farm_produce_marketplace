class CartItem {
  final String productId; // ✅ added
  final String name;
  final double price;
  int quantity;
  final String imageUrl;
  final String unit; // ✅ added
  final int? stock;
  final String farmerId; // ✅ added
  final String farmerName; // ✅ added
  final String pickupLocation;

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,

    required this.unit,
    required this.farmerId,
    required this.farmerName,
    required this.pickupLocation,
    this.stock,
  });
}

// GLOBAL CART LIST
List<CartItem> cartItems = [];
