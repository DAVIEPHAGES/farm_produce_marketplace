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

  // Check if search query is a price search (starts with number or contains price operators)
  bool _isPriceSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;
    
    // Check if it starts with a number (for partial price search)
    if (RegExp(r'^\d').hasMatch(trimmed)) return true;
    
    // Check for price range (contains dash)
    if (trimmed.contains('-')) return true;
    
    // Check for "under X" or "below X"
    if (trimmed.startsWith('under') || trimmed.startsWith('below')) return true;
    
    // Check for "above X" or "over X"
    if (trimmed.startsWith('above') || trimmed.startsWith('over')) return true;
    
    return false;
  }

  // Parse price search query for filtering
  (double? minPrice, double? maxPrice, String? priceStartsWith) _parsePriceQuery(String query) {
    final trimmed = query.trim().toLowerCase();
    
    // Check if it's a partial price (starts with digits only)
    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      // Single digit or number - search for prices starting with these digits
      return (null, null, trimmed);
    }
    
    // Price range with dash (e.g., "1000-5000")
    if (trimmed.contains('-')) {
      final parts = trimmed.split('-');
      if (parts.length == 2) {
        final min = double.tryParse(parts[0].trim());
        final max = double.tryParse(parts[1].trim());
        if (min != null && max != null) {
          return (min, max, null);
        }
      }
    }
    
    // Under/Below (e.g., "under 1000" or "below 500")
    final underMatch = RegExp(r'(?:under|below)\s*(\d+(?:\.\d+)?)').firstMatch(trimmed);
    if (underMatch != null) {
      final max = double.tryParse(underMatch.group(1)!);
      if (max != null) {
        return (null, max, null);
      }
    }
    
    // Above/Over (e.g., "above 1000" or "over 5000")
    final aboveMatch = RegExp(r'(?:above|over)\s*(\d+(?:\.\d+)?)').firstMatch(trimmed);
    if (aboveMatch != null) {
      final min = double.tryParse(aboveMatch.group(1)!);
      if (min != null) {
        return (min, null, null);
      }
    }
    
    return (null, null, null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomerDrawer(),
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by name (e.g., maize) or price (e.g., 1, 10, 100, 1000-5000)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade300,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (searchQuery.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          _isPriceSearch(searchQuery) 
                              ? Icons.monetization_on 
                              : Icons.search,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isPriceSearch(searchQuery) 
                              ? 'Searching by price...' 
                              : 'Searching by name...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 45,
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
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
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
                
                final isPriceSearch = _isPriceSearch(searchQuery);
                final (minPrice, maxPrice, priceStartsWith) = _parsePriceQuery(searchQuery);
                
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final price = (data['price'] as num?)?.toDouble() ?? 0;
                  final priceString = price.toString();

                  // Search logic
                  bool matchesSearch = true;
                  
                  if (searchQuery.isNotEmpty) {
                    if (isPriceSearch) {
                      // Search by price
                      if (priceStartsWith != null) {
                        // Partial price search - prices starting with the digits
                        matchesSearch = priceString.startsWith(priceStartsWith);
                      } else {
                        // Range or comparison search
                        if (minPrice != null && price < minPrice) {
                          matchesSearch = false;
                        }
                        if (maxPrice != null && price > maxPrice) {
                          matchesSearch = false;
                        }
                      }
                    } else {
                      // Search by name
                      matchesSearch = name.contains(searchQuery);
                    }
                  }
                  
                  // Category filter
                  final matchesCategory = selectedCategory == 'All'
                      ? true
                      : name.contains(selectedCategory.toLowerCase());

                  return matchesSearch && matchesCategory;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPriceSearch
                              ? 'Try: "1", "10", "100", "500-2000", "under 1000", "above 5000"'
                              : 'Try typing a produce name like "maize" or "beans"',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final screenWidth = MediaQuery.of(context).size.width;

                int crossAxisCount = 2;

                if (screenWidth >= 1200) {
                  crossAxisCount = 4;
                } else if (screenWidth >= 800) {
                  crossAxisCount = 3;
                } else {
                  crossAxisCount = 2;
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.black,
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/orders');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'profile',
          ),
        ],
      ),
    );
  }

  void addToCart(Map<String, dynamic> data, String id) {
    setState(() {
      final existingIndex = cartItems.indexWhere(
        (item) => item.productId == id,
      );

      if (existingIndex >= 0) {
        cartItems[existingIndex].quantity += 1;
      } else {
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
      }
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
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
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
                          const Center(child: Icon(Icons.image)),
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
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('MK ${data['price'] ?? 0} / ${data['quantity'] ?? ''}'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => addToCart(data, id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.shopping_cart, size: 18),
                    label: const Text('Add to Cart'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}