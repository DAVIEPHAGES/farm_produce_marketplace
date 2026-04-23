import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/cart_data.dart';

class ProduceDetailsPage extends StatefulWidget {
  final QueryDocumentSnapshot<Object?> data;

  const ProduceDetailsPage({super.key, required this.data});

  @override
  State<ProduceDetailsPage> createState() => _ProduceDetailsPageState();
}

class _ProduceDetailsPageState extends State<ProduceDetailsPage> {
  int quantity = 1;

  Map<String, dynamic> get produceData =>
      widget.data.data() as Map<String, dynamic>;

  void addToCart() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushNamed(context, '/signin');
      return;
    }

    final data = produceData;

    cartItems.add(
      CartItem(
        productId: widget.data.id,
        name: data['name']?.toString() ?? 'Unknown',
        price: (data['price'] as num?)?.toDouble() ?? 0,
        quantity: quantity,
        imageUrl: data['imageUrl']?.toString() ?? '',
        farmer: data['farmerName']?.toString() ?? 'Farmer',
      ),
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to cart')));
  }

  @override
  Widget build(BuildContext context) {
    final data = produceData;
    final farmerName = data['farmerName']?.toString() ?? 'Unknown';
    final farmerPhone = data['farmerPhone']?.toString() ?? 'Not set';
    final farmerLocation = data['farmerLocation']?.toString() ?? 'Not set';
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = data['imageUrl']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image, size: 100),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MK ${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Farmer Details',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Name: $farmerName')),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Location: $farmerLocation'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Phone: $farmerPhone')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Text(
                              'Quantity',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      if (quantity > 1) {
                                        setState(() {
                                          quantity -= 1;
                                        });
                                      }
                                    },
                                  ),
                                  Text(quantity.toString()),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      setState(() {
                                        quantity += 1;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: addToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add to Cart - MK ${(price * quantity).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
