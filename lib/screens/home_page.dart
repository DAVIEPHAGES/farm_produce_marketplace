import 'package:flutter/material.dart';

// GLOBAL CART
List<Map<String, String>> cartItems = [];

// SAMPLE DATA (simulate database)
List<Map<String, String>> allProducts = [
  {
    "name": "bananas",
    "price": "MK 2,500/ bunch",
    "image": "assets/banana.png",
    "category": "fruits",
  },
  {
    "name": "maize",
    "price": "MK 50,000/ bag",
    "image": "assets/maize.png",
    "category": "maize",
  },
  {
    "name": "beans",
    "price": "MK 60,000/ bag",
    "image": "assets/beans.png",
    "category": "Beans",
  },
  {
    "name": "irish potato",
    "price": "MK 50,000/ bag",
    "image": "assets/potato.png",
    "category": "vegetables",
  },
  {
    "name": "groundnuts",
    "price": "MK 100,000/ bag",
    "image": "assets/groundnuts.png",
    "category": "Beans",
  },
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = "";
  String selectedCategory = "All";
  String searchQuery = "";

  List<Map<String, String>> get filteredProducts {
    return allProducts.where((product) {
      final matchesCategory = selectedCategory == "All" || product['category'] == selectedCategory;
      final matchesSearch = product['name']!.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP BAR
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.menu),
                  Row(
                    children: [
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_outlined),
                            onPressed: () async {
                              await Navigator.pushNamed(context, '/cart');
                              setState(() {
                                // Rebuild to update cart badge
                              });
                            },
                          ),
                          if (cartItems.isNotEmpty)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  cartItems.length.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/signin');
                        },
                        child: const Chip(label: Text("Sign in")),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // SEARCH
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ProductCard(
                      name: product['name']!,
                      price: product['price']!,
                      image: product['image']!,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ADD TO CART
  void addToCart(QueryDocumentSnapshot data) {
    cartItems.add({
      'name': data['name'],
      'price': (data['price'] as num).toDouble(),
      'quantity': 1,
      'imageUrl': data['imageUrl'],
      'farmer': data['farmerName'] ?? 'Farmer',
    });

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                cartItems.add({
                  'name': name,
                  'price': price,
                  'image': image,
                  'quantity': '1',
                });

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('$name added to cart')));
              },
              child: const Text("add to cart"),
            ),
          ),
        ],
      ),
    );
  }
}