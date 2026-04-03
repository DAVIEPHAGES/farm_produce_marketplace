import 'package:flutter/material.dart';
import 'payment_page.dart';
import 'home_page.dart'; // Import to access global cartItems

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text('My Cart'),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {},
              ),
              if (cartItems.isNotEmpty)
                CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(
                    cartItems.length.toString(),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
            ],
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: cartItems.isEmpty
            ? const Center(
                child: Text('Your cart is empty'),
              )
            : Column(
                children: [
                  // Cart Items List
                  Expanded(
                    child: ListView.builder(
                      itemCount: cartItems.length,
                      itemBuilder: (context, index) {
                        final item = cartItems[index];
                        int quantity = int.tryParse(item['quantity'] ?? '1') ?? 1;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: AssetImage(item['image']!),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['name']!,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['price']!,
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          cartItems.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const Divider(height: 12),
                                // Quantity Controls
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: quantity > 1
                                              ? () {
                                                  setState(() {
                                                    cartItems[index]['quantity'] =
                                                        (quantity - 1).toString();
                                                  });
                                                }
                                              : null,
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8.0),
                                          child: Text(
                                            quantity.toString(),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add, size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            setState(() {
                                              cartItems[index]['quantity'] =
                                                  (quantity + 1).toString();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'Qty: $quantity',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(thickness: 1.5),
                  const SizedBox(height: 12),
                  // Total Calculation Section
                  _buildTotalSection(),
                  const SizedBox(height: 12),
                  // Checkout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PaymentPage(cartItems: cartItems)),
                        );
                      },
                      child: const Text(
                        'Proceed to Payment',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                ],
              ),
      ),
    );
  }

  // Helper method to extract numeric price from format "MK X,XXX/ unit"
  int _parsePrice(String priceString) {
    try {
      // Extract numbers and commas, remove "MK" and "/"
      final cleaned = priceString.replaceAll(RegExp(r'[^0-9,]'), '');
      final numericString = cleaned.replaceAll(',', '');
      return int.parse(numericString);
    } catch (e) {
      return 0;
    }
  }

  // Calculate subtotal
  int _calculateSubtotal() {
    int subtotal = 0;
    for (var item in cartItems) {
      int price = _parsePrice(item['price'] ?? '0');
      int quantity = int.tryParse(item['quantity'] ?? '1') ?? 1;
      subtotal += price * quantity;
    }
    return subtotal;
  }

  // Build total section widget
  Widget _buildTotalSection() {
    int subtotal = _calculateSubtotal();
    int total = subtotal;

    return Column(
      children: [
        _buildPriceRow('Subtotal', 'MK ${subtotal.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match.group(1)},').replaceAll(RegExp(r',$'), '')}'),
        const SizedBox(height: 8),
        _buildPriceRow(
          'Total',
          'MK ${total.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match.group(1)},').replaceAll(RegExp(r',$'), '')}',
          isBold: true,
          isTotal: true,
        ),
      ],
    );
  }

  // Widget to build price row
  Widget _buildPriceRow(String label, String amount, {bool isBold = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : 14,
            color: isTotal ? Colors.green[700] : Colors.black,
          ),
        ),
      ],
    );
  }
}