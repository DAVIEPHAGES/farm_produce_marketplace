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
  bool _showRefundPolicy = false;
  int _visibleProductsCount = 0;
  int _totalProductsCount = 0;

  final List<String> categories = const [
    'All',
    'maize',
    'beans',
    'fruits',
    'vegetables',
  ];

  // Calculate how many products to show based on screen size
  int _getProductsPerPage(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate based on screen size
    if (screenWidth >= 1200) {
      // Desktop - 4 columns
      return 8; // 2 rows of 4
    } else if (screenWidth >= 800) {
      // Tablet - 3 columns
      return 6; // 2 rows of 3
    } else {
      // Mobile - 2 columns
      return 4; // 2 rows of 2
    }
  }

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
    final productsPerPage = _getProductsPerPage(context);
    
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
                      _visibleProductsCount = productsPerPage; // Reset visible count on search
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
                                _visibleProductsCount = productsPerPage;
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
                      _visibleProductsCount = productsPerPage;
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

                  bool matchesSearch = true;
                  
                  if (searchQuery.isNotEmpty) {
                    if (isPriceSearch) {
                      if (priceStartsWith != null) {
                        matchesSearch = priceString.startsWith(priceStartsWith);
                      } else {
                        if (minPrice != null && price < minPrice) {
                          matchesSearch = false;
                        }
                        if (maxPrice != null && price > maxPrice) {
                          matchesSearch = false;
                        }
                      }
                    } else {
                      matchesSearch = name.contains(searchQuery);
                    }
                  }
                  
                  final matchesCategory = selectedCategory == 'All'
                      ? true
                      : name.contains(selectedCategory.toLowerCase());

                  return matchesSearch && matchesCategory;
                }).toList();

                _totalProductsCount = filtered.length;
                
                // Initialize visible count if not set
                if (_visibleProductsCount == 0 || _visibleProductsCount > _totalProductsCount) {
                  _visibleProductsCount = productsPerPage;
                }
                
                final visibleProducts = filtered.take(_visibleProductsCount).toList();
                final hasMore = _visibleProductsCount < _totalProductsCount;

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

                return ListView(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(10),
                      itemCount: visibleProducts.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) {
                        final doc = visibleProducts[index];
                        final data = doc.data() as Map<String, dynamic>;

                        return _buildCard(data, doc.id, doc);
                      },
                    ),
                    
                    // View More Button
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _visibleProductsCount += productsPerPage;
                            });
                          },
                          icon: const Icon(Icons.expand_more),
                          label: Text(
                            'View More (${_totalProductsCount - _visibleProductsCount} remaining)',
                            style: const TextStyle(fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade100,
                            foregroundColor: Colors.green.shade800,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                        ),
                      ),
                    
                    // Show all button when all products are visible
                    if (!hasMore && _totalProductsCount > productsPerPage)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Text(
                          'Showing all ${_totalProductsCount} products',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    
                    // Refund Policy Section
                    _buildRefundPolicySection(),
                  ],
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

  Widget _buildRefundPolicySection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          GestureDetector(
            onTap: () {
              setState(() {
                _showRefundPolicy = !_showRefundPolicy;
              });
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.security,
                    color: Colors.green.shade800,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Refund & Payment Protection Policy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
                Icon(
                  _showRefundPolicy ? Icons.expand_less : Icons.expand_more,
                  color: Colors.green.shade800,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.grey),
          
          // Policy content - expandable
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _showRefundPolicy 
                ? CrossFadeState.showFirst 
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 12),
                _buildPolicyRule(
                  number: '1',
                  title: 'Payment Release Confirmation',
                  description: 'Money will be sent to farmer ONLY if customer confirms that goods ordered have been received.',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 12),
                _buildPolicyRule(
                  number: '2',
                  title: '14-Day Confirmation Period',
                  description: 'If you buy a product, make sure you notify us once you have received your produce. Otherwise, money will be released to the produce owner if we receive no message from customer within 14 days.',
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(height: 12),
                _buildPolicyRule(
                  number: '3',
                  title: 'Transportation Issues',
                  description: 'Goods not reaching destination due to poor transportation or stealing by transporter will be the farmer\'s responsibility to handle the issue. Money will NOT be released until the issue is solved.',
                  icon: Icons.local_shipping_outlined,
                  isLast: true,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'For any issues regarding payments or deliveries, please contact our support team immediately.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyRule({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
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