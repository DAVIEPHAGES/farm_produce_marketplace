import 'package:flutter/material.dart';
import '../data/cart_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isPlacingOrder = false;

  double getTotal() {
    double total = 0;
    for (var item in cartItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

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

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.imageUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "MK ${(item.price * item.quantity).toStringAsFixed(2)}",
                                    style:
                                        const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),

                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      if (item.quantity > 1) {
                                        item.quantity--;
                                      } else {
                                        cartItems.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                Text(
                                  "${item.quantity}",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      item.quantity++;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

          const Divider(height: 1),

          // TOTAL
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  "MK ${getTotal().toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // PLACE ORDER BUTTON (UPDATED)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),

                onPressed: cartItems.isEmpty || _isPlacingOrder
                    ? null
                    : () async {
                        final user =
                            FirebaseAuth.instance.currentUser;

                        if (user == null) {
                          Navigator.pushNamed(
                              context, "/signin");
                          return;
                        }

                        setState(() => _isPlacingOrder = true);

                        try {
                          // 🧾 CREATE SINGLE ORDER
                          final orderRef = FirebaseFirestore
                              .instance
                              .collection('orders')
                              .doc();

                          final total = getTotal();

                          await orderRef.set({
                            "customerId": user.uid,
                            "totalPrice": total,
                            "status": "pending",
                            "timestamp":
                                FieldValue.serverTimestamp(),
                          });

                          // 📦 ADD ITEMS AS SUBCOLLECTION
                          for (var item in cartItems) {
                            await orderRef
                                .collection("items")
                                .add({
                              "productId": item.productId,
                              "productName": item.name,
                              "quantity": item.quantity,
                              "price": item.price,
                              "totalPrice":
                                  item.price * item.quantity,
                              "imageUrl": item.imageUrl,
                              "farmerId": item.farmer,
                            });
                          }

                          // 🧹 CLEAR CART
                          cartItems.clear();

                          if (!mounted) return;

                          setState(() {});

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "✅ Order placed successfully"),
                            ),
                          );

                          Navigator.pushReplacementNamed(
                              context, "/orders");
                        } catch (e) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                                content: Text("❌ Error: $e")),
                          );
                        } finally {
                          if (mounted) {
                            setState(
                                () => _isPlacingOrder = false);
                          }
                        }
                      },

                child: _isPlacingOrder
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        "Place Order",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}