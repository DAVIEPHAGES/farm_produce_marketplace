import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:farm_app/data/cart_data.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = "";
  String selectedCategory = "All";

  final List<String> categories = [
    "All",
    "maize",
    "beans",
    "fruits",
    "vegetables"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,

      // ⭐ UBER / E-COMMERCE STYLE APP BAR
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,

        // LEFT: CART ICON
        leading: IconButton(
          icon: const Icon(Icons.shopping_cart),
          onPressed: () => Navigator.pushNamed(context, "/cart"),
        ),

        title: const Text(
          "FarmApp",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),

        // RIGHT: AUTH STATE (SIGN IN OR PROFILE)
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              // NOT LOGGED IN → SIGN IN BUTTON
              if (user == null) {
                return TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, "/signin");
                  },
                  child: const Text(
                    "Sign In",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              // LOGGED IN → PROFILE ICON
              return IconButton(
                icon: const CircleAvatar(
                  radius: 14,
                  child: Icon(Icons.person, size: 18),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, "/profile");
                },
              );
            },
          )
        ],
      ),

      body: Column(
        children: [
          // SEARCH
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              onChanged: (value) =>
                  setState(() => searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: "search for maize, beans etc",
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

          // CATEGORY
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = selectedCategory == cat;

                return GestureDetector(
                  onTap: () => setState(() => selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
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

          // PRODUCTS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                final filtered = docs.where((doc) {
                  final name = (doc['name'] ?? '').toString().toLowerCase();

                  final matchesSearch = name.contains(searchQuery);
                  final matchesCategory =
                      selectedCategory == "All" ||
                      name.contains(selectedCategory);

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("No matching produce"));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    return _buildCard(filtered[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ADD TO CART
  void addToCart(QueryDocumentSnapshot data) {
    cartItems.add(
      CartItem(
        name: data['name'],
        price: (data['price'] as num).toDouble(),
        quantity: 1,
        imageUrl: data['imageUrl'],
        farmer: data['farmerName'] ?? 'Farmer',
      ),
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Added to cart")));
  }

  // CARD
  Widget _buildCard(QueryDocumentSnapshot data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(15)),
            child: Image.network(
              data['imageUrl'],
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image, size: 80),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['name'] ?? ''),
                const SizedBox(height: 4),
                Text(
                  "MK ${data['price']}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => addToCart(data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("add to cart"),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}