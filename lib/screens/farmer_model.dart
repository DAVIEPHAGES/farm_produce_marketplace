class Farmer {
  final String name;
  final String location;
  final String phone; // ✅ ADD THIS
  final double totalEarnings;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> orders;

  Farmer({
    required this.name,
    required this.location,
    required this.phone, 
    required this.totalEarnings,
    required this.products,
    required this.orders,
  });

  factory Farmer.fromMap(Map<String, dynamic> data) {
    return Farmer(
      name: data['name'] ?? '',
      location: data['location'] ?? '',
      phone: data['phone'] ?? '', // ✅ ADD THIS
      totalEarnings: (data['totalEarnings'] ?? 0).toDouble(),
      products: List<Map<String, dynamic>>.from(data['products'] ?? []),
      orders: List<Map<String, dynamic>>.from(data['orders'] ?? []),
    );
  }
}