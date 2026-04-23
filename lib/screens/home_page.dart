import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:farm_app/data/cart_data.dart';

import '../widgets/customer_drawer.dart';
import 'cart_page.dart';
import 'produce_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = '';
  String selectedCategory = 'All';

  final List<String> categories = const [
    'All',
    'maize',
    'beans',
    'fruits',
    'vegetables',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomerDrawer(),
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'FarmApp',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const CartPage()),
                  );
                },
              ),
              if (cartItems.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      cartItems.length.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              if (user == null) {
                return TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signin'),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(color: Colors.black),
                  ),
                );
              }

              return IconButton(
                icon: const CircleAvatar(
                  radius: 14,
                  child: Icon(Icons.person, size: 18),
                ),
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'search for maize, beans etc',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade300,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = selectedCategory == category;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Fresh Today',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData) {
                  return const Center(child: Text('No products'));
                }

                final docs = snapshot.data!.docs;
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();

                  final matchesSearch = name.contains(searchQuery);
                  final matchesCategory = selectedCategory == 'All'
                      ? true
                      : name.contains(selectedCategory);

                  return matchesSearch && matchesCategory;
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return _buildCard(data, doc.id, doc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void addToCart(Map<String, dynamic> data, String id) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Navigator.pushNamed(context, '/signin');
      return;
    }

    setState(() {
      cartItems.add(
        CartItem(
          productId: id,
          name: data['name']?.toString() ?? '',
          price: (data['price'] as num?)?.toDouble() ?? 0,
          quantity: 1,
          imageUrl: data['imageUrl']?.toString() ?? '',
          farmer: data['farmerName']?.toString() ?? 'Farmer',
        ),
      );
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to cart')));
  }

  Widget _buildCard(
    Map<String, dynamic> data,
    String id,
    QueryDocumentSnapshot doc,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ProduceDetailsPage(data: doc),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Image.network(
                      data['imageUrl']?.toString() ?? '',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.image, size: 36)),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => addToCart(data, id),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name']?.toString() ?? ''),
                Text('MK ${data['price'] ?? 0}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
