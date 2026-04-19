import 'package:flutter/material.dart';
import 'package:farm_app/data/cart_data.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  void _increment(int index) {
    setState(() => cartItems[index]['quantity']++);
  }

  void _decrement(int index) {
    setState(() {
      if (cartItems[index]['quantity'] <= 1) {
        cartItems.removeAt(index);
      } else {
        cartItems[index]['quantity']--;
      }
    });
  }

  void _remove(int index) {
    setState(() => cartItems.removeAt(index));
  }

  void _clearCart() {
    setState(() => cartItems.clear());
  }

  double get _total => cartItems.fold(
        0,
        (sum, item) =>
            sum +
            (item['price'] as double) * (item['quantity'] as int),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Text("Cart (${cartItems.length})"),
        actions: [
          if (cartItems.isNotEmpty)
            TextButton(
              onPressed: _clearCart,
              child: const Text("Clear", style: TextStyle(color: Colors.white)),
            )
        ],
      ),

      body: cartItems.isEmpty
          ? const Center(child: Text("Cart is empty"))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];

                      return Card(
                        child: ListTile(
                          leading: Image.network(
                            item['imageUrl'],
                            width: 60,
                            height: 60,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.image),
                          ),
                          title: Text(item['name']),
                          subtitle: Text("Farmer: ${item['farmer']}"),
                          trailing: Text(
                            "MK ${(item['price'] * item['quantity']).toStringAsFixed(0)}",
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "Total: MK ${_total.toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            ),
    );
  }
}