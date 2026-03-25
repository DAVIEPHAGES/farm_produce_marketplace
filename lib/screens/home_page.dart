import 'package:flutter/material.dart';

// GLOBAL CART
List<Map<String, String>> cartItems = [];

// SAMPLE DATA (simulate database)
List<Map<String, String>> allProducts = [
  {"name": "bananas", "price": "MK 2,500/ bunch", "image": "assets/banana.png", "category": "fruits"},
  {"name": "maize", "price": "MK 50,000/ bag", "image": "assets/maize.png", "category": "maize"},
  {"name": "beans", "price": "MK 60,000/ bag", "image": "assets/beans.png", "category": "Beans"},
  {"name": "irish potato", "price": "MK 50,000/ bag", "image": "assets/potato.png", "category": "vegetables"},
  {"name": "groundnuts", "price": "MK 100,000/ bag", "image": "assets/groundnuts.png", "category": "Beans"},
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
                            onPressed: () {
                              Navigator.pushNamed(context, '/cart');
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
                                  style: const TextStyle(color: Colors.white, fontSize: 10),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      const Chip(label: Text("Sign in"))
                    ],
                  )
                ],
              ),

              const SizedBox(height: 10),

              // SEARCH
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search),
                    hintText: "search for maize, groundnuts etc",
                    border: InputBorder.none,
                  ),
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                "Buy Farm Produce Delivered To You",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              // CATEGORIES
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    categoryChip("All"),
                    categoryChip("maize"),
                    categoryChip("Beans"),
                    categoryChip("fruits"),
                    categoryChip("vegetables"),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // GRID (handles many items)
              Expanded(
                child: GridView.builder(
                  itemCount: filteredProducts.length,
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
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget categoryChip(String label) {
    final isSelected = selectedCategory == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green : Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black),
        ),
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final String name;
  final String price;
  final String image;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: AssetImage(image),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          const SizedBox(height: 5),

          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(price),

          const SizedBox(height: 5),

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
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$name added to cart')),
                );
              },
              child: const Text("add to cart"),
            ),
          )
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: const Center(
        child: Text(
          'Welcome to Farm Produce Marketplace!',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}