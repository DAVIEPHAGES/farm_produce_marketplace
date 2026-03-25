import 'package:flutter/material.dart';
import 'home_page.dart'; // to access cartItems

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cart"),
      ),
      body: cartItems.isEmpty
          ? const Center(
              child: Text("Your cart is empty"),
            )
          : ListView.builder(
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];

                return ListTile(
                  leading: Image.asset(item['image']!),
                  title: Text(item['name']!),
                  subtitle: Text(item['price']!),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      cartItems.removeAt(index);
                      (context as Element).markNeedsBuild(); // refresh UI
                    },
                  ),
                );
              },
            ),
    );
  }
}