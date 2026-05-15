import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../utils/url_utils.dart'
    if (dart.library.html) '../utils/url_utils_web.dart';
import 'package:farm_app/data/cart_data.dart';

import '../widgets/customer_drawer.dart';
import 'cart_page.dart';
import 'my_orders_page.dart';
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
  bool _isShowingAll = false;
  int _selectedBottomNavIndex = 0; // Track selected bottom nav index

  final List<String> categories = const [
    'All',
    'maize',
    'beans',
    'fruits',
    'vegetables',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePayChanguRedirect();
    });
  }

  Future<void> _handlePayChanguRedirect() async {
    final queryParams = Uri.base.queryParameters;
    if (queryParams['paychangu_callback'] != '1') {
      return;
    }

    final status = (queryParams['status'] ?? '').toLowerCase();
    final txRef = queryParams['tx_ref'] ?? queryParams['txRef'];
    final orderId = queryParams['orderId'];

    clearQueryParameters();

    final isSuccessCallback = status == 'success' ||
        (status.isEmpty && orderId != null && txRef != null && txRef.isNotEmpty);

    if (orderId == null || orderId.isEmpty || txRef == null || txRef.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment returned, but the order could not be identified.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (mounted) {
      if (isSuccessCallback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Order placed successfully. You may continue shopping.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'failed' || status == 'cancelled'
                ? 'Payment was not completed. Please try again.'
                : 'Payment returned to the app. Please verify your order status.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  int _getProductsPerPage(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= 1200) {
      return 8;
    } else if (screenWidth >= 800) {
      return 6;
    } else {
      return 4;
    }
  }

  void _resetToInitialView(int productsPerPage) {
    setState(() {
      _visibleProductsCount = productsPerPage;
      _isShowingAll = false;
    });
  }

  void _loadMoreProducts(int productsPerPage, int totalProducts) {
    setState(() {
      if (_visibleProductsCount + productsPerPage >= totalProducts) {
        _visibleProductsCount = totalProducts;
        _isShowingAll = true;
      } else {
        _visibleProductsCount += productsPerPage;
      }
    });
  }

  void _showLessProducts(int productsPerPage) {
    setState(() {
      _visibleProductsCount = productsPerPage;
      _isShowingAll = false;
    });
  }

  bool _isPriceSearch(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return false;

    if (RegExp(r'^\d').hasMatch(trimmed)) return true;
    if (trimmed.contains('-')) return true;
    if (trimmed.startsWith('under') || trimmed.startsWith('below')) return true;
    if (trimmed.startsWith('above') || trimmed.startsWith('over')) return true;

    return false;
  }

  (double? minPrice, double? maxPrice, String? priceStartsWith) _parsePriceQuery(
    String query,
  ) {
    final trimmed = query.trim().toLowerCase();

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return (null, null, trimmed);
    }

    if (trimmed.contains('-')) {
      final parts = trimmed.split('-');
      if (parts.length == 2) {
        final min = double.tryParse(parts[0].trim());
        final max = double.tryParse(parts[1].trim());
        if (min != null && max != null) return (min, max, null);
      }
    }

    final underMatch =
        RegExp(r'(?:under|below)\s*(\d+(?:\.\d+)?)').firstMatch(trimmed);
    if (underMatch != null) {
      final max = double.tryParse(underMatch.group(1)!);
      if (max != null) return (null, max, null);
    }

    final aboveMatch =
        RegExp(r'(?:above|over)\s*(\d+(?:\.\d+)?)').firstMatch(trimmed);
    if (aboveMatch != null) {
      final min = double.tryParse(aboveMatch.group(1)!);
      if (min != null) return (min, null, null);
    }

    return (null, null, null);
  }

  (int crossAxisCount, double childAspectRatio) _getGridConfig(double width) {
    if (width >= 1200) {
      return (4, 0.75);
    } else if (width >= 800) {
      return (3, 0.8);
    } else {
      return (2, 0.85);
    }
  }

  int? _parseStock(Map<String, dynamic> data) {
    final stockValue = data['stock'];
    if (stockValue is num) return stockValue.toInt();
    if (stockValue is String) return int.tryParse(stockValue);

    final quantityValue = data['quantity'];
    if (quantityValue is num) return quantityValue.toInt();
    if (quantityValue is String) return int.tryParse(quantityValue);

    return null;
  }

  void addToCart(Map<String, dynamic> data, String id) {
    final availableStock = _parseStock(data);
    final existingIndex = cartItems.indexWhere((item) => item.productId == id);

    if (availableStock != null && availableStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product is out of stock')),
      );
      return;
    }

    if (existingIndex >= 0) {
      final currentQuantity = cartItems[existingIndex].quantity;
      if (availableStock == null || currentQuantity < availableStock) {
        setState(() {
          cartItems[existingIndex].quantity += 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to cart')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Only $availableStock unit${availableStock == 1 ? '' : 's'} available',
            ),
          ),
        );
      }
      return;
    }

    final farmerId = data['farmerId']?.toString() ?? '';
    final farmerName = data['farmerName']?.toString() ?? 'Farmer';
    final unit = data['sellingUnit']?.toString() ?? 'unit';
    final name = data['name']?.toString() ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = data['imageUrl']?.toString() ?? '';

    setState(() {
      cartItems.add(
        CartItem(
          productId: id,
          name: name,
          price: price,
          quantity: 1,
          imageUrl: imageUrl,
          farmerId: farmerId,
          farmerName: farmerName,
          unit: unit,
          stock: availableStock,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart')),
    );
  }

  Widget _buildCard(Map<String, dynamic> data, String id, QueryDocumentSnapshot doc) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.2,
              child: Stack(
                fit: StackFit.expand,
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
                    child: Image.network(
                      data['imageUrl']?.toString() ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image, size: 40),
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
                        child: const Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MK ${data['price'] ?? 0} / ${data['sellingUnit'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => addToCart(data, id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.shopping_cart, size: 16),
                        label: const Text('Add to Cart', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Colors.grey.shade200)),
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
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                  child: Icon(Icons.security, color: Colors.green.shade800, size: 20),
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
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState:
                _showRefundPolicy ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 12),
                _buildPolicyRule(
                  number: '1',
                  title: 'Payment Release Confirmation',
                  description:
                      'Money will be sent to farmer ONLY if customer confirms that goods ordered have been received.',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 12),
                _buildPolicyRule(
                  number: '2',
                  title: '14-Day Confirmation Period',
                  description:
                      'If you buy a product, make sure you notify us once you have received your produce. Otherwise, money will be released to the produce owner if we receive no message from customer within 14 days.',
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(height: 12),
                _buildPolicyRule(
                  number: '3',
                  title: 'Transportation Issues',
                  description:
                      'Goods not reaching destination due to poor transportation or stealing by transporter will be the farmer\'s responsibility to handle the issue. Money will NOT be released until the issue is solved.',
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
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
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

  @override
  Widget build(BuildContext context) {
    final productsPerPage = _getProductsPerPage(context);
    final user = FirebaseAuth.instance.currentUser;

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
                      _resetToInitialView(productsPerPage);
                    });
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Search by name (e.g., maize) or price (e.g., 1, 10, 100, 1000-5000)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                searchQuery = '';
                                _resetToInitialView(productsPerPage);
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
                          _isPriceSearch(searchQuery) ? Icons.monetization_on : Icons.search,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isPriceSearch(searchQuery)
                              ? 'Searching by price...'
                              : 'Searching by name...',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
                      _resetToInitialView(productsPerPage);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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

                if (_visibleProductsCount == 0 || _visibleProductsCount > _totalProductsCount) {
                  _visibleProductsCount = productsPerPage;
                  _isShowingAll = false;
                }

                final visibleProducts = filtered.take(_visibleProductsCount).toList();
                final hasMore = _visibleProductsCount < _totalProductsCount;
                final hasLess = _visibleProductsCount > productsPerPage;

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPriceSearch
                              ? 'Try: "1", "10", "100", "500-2000", "under 1000", "above 5000"'
                              : 'Try typing a produce name like "maize" or "beans"',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final screenWidth = MediaQuery.of(context).size.width;
                final (crossAxisCount, childAspectRatio) = _getGridConfig(screenWidth);

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
                        childAspectRatio: childAspectRatio,
                      ),
                      itemBuilder: (context, index) {
                        final doc = visibleProducts[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _buildCard(data, doc.id, doc);
                      },
                    ),
                    if (hasMore || hasLess)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasLess)
                                ElevatedButton.icon(
                                  onPressed: () => _showLessProducts(productsPerPage),
                                  icon: const Icon(Icons.expand_less, size: 16),
                                  label: const Text('View Less'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              if (hasMore && hasLess) const SizedBox(width: 12),
                              if (hasMore)
                                ElevatedButton.icon(
                                  onPressed: () => _loadMoreProducts(productsPerPage, _totalProductsCount),
                                  icon: const Icon(Icons.expand_more, size: 16),
                                  label: Text('View More (${_totalProductsCount - _visibleProductsCount})'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Center(
                        child: Text(
                          _isShowingAll
                              ? 'Showing all $_totalProductsCount products'
                              : 'Showing $_visibleProductsCount of $_totalProductsCount products',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ),
                    ),
                    _buildRefundPolicySection(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // ✅ UPDATED: Bottom navigation bar with ONLY 3 items (Home, My Orders, Profile)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedBottomNavIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 1) Navigator.pushNamed(context, '/orders');
          if (index == 2) Navigator.pushNamed(context, '/profile');
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'My Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
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
                  child: Icon(Icons.security,
                      color: Colors.green.shade800, size: 20),
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
                  _showRefundPolicy
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: Colors.green.shade800,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Colors.grey),
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
                  description:
                      'Money will be sent to farmer ONLY if customer confirms that goods ordered have been received.',
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 12),
                _buildPolicyRule(
                  number: '2',
                  title: '14-Day Confirmation Period',
                  description:
                      'If you buy a product, make sure you notify us once you have received your produce. Otherwise, money will be released to the produce owner if we receive no message from customer within 14 days.',
                  icon: Icons.timer_outlined,
                ),
                const SizedBox(height: 12),
                _buildPolicyRule(
                  number: '3',
                  title: 'Transportation Issues',
                  description:
                      "Goods not reaching destination due to poor transportation or stealing by transporter will be the farmer's responsibility to handle the issue. Money will NOT be released until the issue is solved.",
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
                      Icon(Icons.info_outline,
                          color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'For any issues regarding payments or deliveries, please contact our support team immediately.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade800),
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
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.grey.shade200)),
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
                    Icon(icon,
                        size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
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
      final existingIndex =
          cartItems.indexWhere((item) => item.productId == id);

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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart')),
    );
  }

  Widget _buildCard(
    Map<String, dynamic> data,
    String id,
    QueryDocumentSnapshot doc,
  ) {
    return ClipRRect(
      // FIX: ClipRRect prevents any child from painting outside card bounds
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FIX: AspectRatio scales the image proportionally instead of
            //      a hardcoded height that mismatches the grid cell size.
            AspectRatio(
              aspectRatio: 1.2, // wider than tall — adjust to taste (1.0–1.4)
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              ProduceDetailsPage(data: doc),
                        ),
                      );
                    },
                    child: Image.network(
                      data['imageUrl']?.toString() ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image, size: 40),
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
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text + button section grows to fill remaining card space
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MK ${data['price'] ?? 0} / ${data['sellingUnit'] ?? ''}',
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => addToCart(data, id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          tapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.shopping_cart, size: 16),
                        label: const Text('Add to Cart',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}