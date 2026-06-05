import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/cart_data.dart';
// FIXED: Changed 'screan' to 'screen' to prevent navigation errors
import 'payment_processing_screan.dart';
import '../services/local_notification_service.dart';
import '../services/distance_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  bool _isProcessingPayment = false;
  bool _hasAutoProceed = false;
  String? _selectedDeliveryAddress; // Track custom delivery address
  static const double _deliveryRatePerKm = 10.0; // MK per km (adjust as needed)
  double _deliveryDistanceKm = 0.0;
  double _deliveryFee = 0.0;
  String? _deliveryError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        cartItems.isNotEmpty &&
        !_hasAutoProceed &&
        !_isProcessingPayment) {
      _hasAutoProceed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Only auto-proceed if you want the app to jump to payment automatically
        // _proceedToPayment();
      });
    }
  }

  double getTotal() {
    double total = 0;
    for (final item in cartItems) {
      total += item.price * item.quantity;
    }
    return total;
  }

  int? _parseStock(Map<String, dynamic> data) {
    if (data.containsKey('availableQuantity')) {
      return (data['availableQuantity'] as num).toInt();
    }
    if (data.containsKey('quantity')) {
      return (data['quantity'] as num).toInt();
    }
    return null;
  }

  Future<bool> _validateCartStock() async {
    for (final item in cartItems) {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(item.productId)
          .get();

      if (!doc.exists) {
        _showMessage('❌ ${item.name} is no longer available.');
        return false;
      }

      final data = doc.data()!;
      final stock = _parseStock(data);

      if (stock != null && (stock <= 0 || item.quantity > stock)) {
        _showMessage(
          stock <= 0
              ? '❌ Sorry, ${item.name} is out of stock!'
              : '⚠️ Only $stock left of ${item.name}. Please reduce quantity.',
        );
        return false;
      }
    }
    return true;
  }

  String _firstNonEmpty(List<dynamic> values, String fallback) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  String _customerDeliveryLocation(Map<String, dynamic>? userData) {
    return _firstNonEmpty([
      userData?['deliveryLocation'],
      userData?['deliveryAddress'],
      userData?['customerAddress'],
      userData?['address'],
      userData?['location'],
      userData?['fullAddress'],
    ], 'Delivery address not specified');
  }

  String _productPickupLocation(Map<String, dynamic>? productData) {
    return _firstNonEmpty([
      productData?['location'],
      productData?['farmerLocation'],
      productData?['pickupLocation'],
      productData?['pickupAddress'],
    ], '');
  }

  bool _hasCustomerDeliveryLocation(Map<String, dynamic>? userData) {
    return _customerDeliveryLocation(userData) !=
        'Delivery address not specified';
  }

  Future<void> _selectDeliveryAddress() async {
    const districts = [
      "Balaka",
      "Blantyre",
      "Chikwawa",
      "Chiradzulu",
      "Chitipa",
      "Dedza",
      "Dowa",
      "Karonga",
      "Kasungu",
      "Likoma",
      "Lilongwe",
      "Machinga",
      "Mangochi",
      "Mchinji",
      "Mulanje",
      "Mwanza",
      "Mzimba",
      "Neno",
      "Nkhata Bay",
      "Nkhotakota",
      "Nsanje",
      "Ntcheu",
      "Ntchisi",
      "Phalombe",
      "Rumphi",
      "Salima",
      "Thyolo",
      "Zomba"
    ];

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Please login first');
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final defaultAddress = _customerDeliveryLocation(userDoc.data());
    String? selectedDistrict = _selectedDeliveryAddress;

    if (!mounted) return;

    final newAddress = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Delivery District'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select your delivery district:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedDistrict,
                  hint: const Text('Choose a district'),
                  isExpanded: true,
                  items: districts
                      .map((district) => DropdownMenuItem(
                            value: district,
                            child: Text(district),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedDistrict = value);
                  },
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                if (defaultAddress != 'Delivery address not specified')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your default district:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () {
                          setState(() => selectedDistrict = defaultAddress);
                        },
                        child: Text(
                          defaultAddress,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDistrict != null && selectedDistrict!.isNotEmpty) {
                  Navigator.pop(dialogContext, selectedDistrict);
                } else {
                  _showMessage('Please select a district');
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (newAddress != null && newAddress.isNotEmpty) {
      setState(() => _selectedDeliveryAddress = newAddress);
    }
  }

  Future<Map<String, double>> _computeDistanceAndFee(String origin, String destination) async {
    try {
      final distance = await DistanceService.calculateDistanceKm(origin, destination);
      final fee = await DistanceService.calculateDeliveryFee(
        originDistrict: origin,
        destinationDistrict: destination,
        ratePerKm: _deliveryRatePerKm,
      );
      return { 'distance': distance, 'fee': fee };
    } catch (e) {
      // propagate error to UI
      throw Exception('Distance error: $e');
    }
  }

  Future<bool> _ensureCustomerDeliveryLocation(User user) async {
    // If user has selected a custom address, use it
    if (_selectedDeliveryAddress != null && _selectedDeliveryAddress!.isNotEmpty) {
      return true;
    }

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userDoc = await userRef.get();
    if (_hasCustomerDeliveryLocation(userDoc.data())) {
      return true;
    }
    if (!mounted) return false;

    final controller = TextEditingController();
    final deliveryLocation = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delivery Location'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Where should the produce be delivered?',
            hintText: 'Area, town, district, or landmark',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (deliveryLocation == null || deliveryLocation.trim().isEmpty) {
      return false;
    }

    await userRef.set({
      'deliveryLocation': deliveryLocation.trim(),
      'deliveryAddress': deliveryLocation.trim(),
      'location': deliveryLocation.trim(),
    }, SetOptions(merge: true));
    return true;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<DocumentReference<Map<String, dynamic>>?> _createOrder({
    required String paymentMethod,
    required String paymentStatus,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final total = getTotal();
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final productSnapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final item in cartItems) {
      productSnapshots[item.productId] = await FirebaseFirestore.instance
          .collection('products')
          .doc(item.productId)
          .get();
    }

    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    final firstItem = cartItems.isNotEmpty ? cartItems.first : null;
    final farmerIds = cartItems.map((item) => item.farmerId).toSet().toList();
    final userData = userDoc.data();
    final firstProductData = firstItem == null
        ? null
        : productSnapshots[firstItem.productId]?.data();
    final pickupLocation = _firstNonEmpty([
      _productPickupLocation(firstProductData),
      firstItem?.pickupLocation,
    ], 'Pickup location not specified');
    // Use selected delivery address if available, otherwise use user's default
    final deliveryLocation = _selectedDeliveryAddress ?? _customerDeliveryLocation(userData);

    await orderRef.set({
      'orderId': orderRef.id,
      'customerId': user.uid,
      'customerName': userData?['name'] ?? 'Customer',
      'customerEmail': user.email,
      'customerPhone': userData?['phone'] ?? '',
      'farmerIds': farmerIds,
      'pickupLocation': pickupLocation,
      'pickupAddress': pickupLocation,
      'deliveryLocation': deliveryLocation,
      'deliveryAddress': deliveryLocation,
      'imageUrl': firstItem?.imageUrl ?? '',
      'productName': firstItem?.name ?? '',
      'totalPrice': total,
      'totalAmount': total,
      'status': 'Pending',
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });

    for (final item in cartItems) {
      final itemPickupLocation = _firstNonEmpty([
        _productPickupLocation(productSnapshots[item.productId]?.data()),
        item.pickupLocation,
      ], 'Pickup location not specified');

      await orderRef.collection('items').add({
        'productId': item.productId,
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'totalPrice': item.price * item.quantity,
        'imageUrl': item.imageUrl,
        'farmerId': item.farmerId,
        'farmerName': item.farmerName,
        'pickupLocation': itemPickupLocation,
        'unit': item.unit,
      });
    }

    await LocalNotificationService.showNewOrderNotification(
      userData?['name'] ?? 'Customer',
      orderRef.id,
    );

    return orderRef;
  }

  Future<void> _proceedToPayment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showLoginRequiredDialog();
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      if (!await _ensureCustomerDeliveryLocation(user)) {
        setState(() => _isProcessingPayment = false);
        return;
      }

      if (!await _validateCartStock()) {
        setState(() => _isProcessingPayment = false);
        return;
      }

      final orderRef = await _createOrder(
        paymentMethod: 'paychangu',
        paymentStatus: 'pending',
      );

      if (orderRef == null || !mounted) {
        setState(() => _isProcessingPayment = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final customerName = userDoc.data()?['name'] ?? 'Customer';

      if (!mounted) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (context) => PaymentProcessingScreen(
            amount: (getTotal() + _deliveryFee),
            orderId: orderRef.id,
            customerName: customerName,
            customerEmail: user.email ?? '',
            cartItems: cartItems
                .map(
                  (item) => {
                    'productId': item.productId,
                    'name': item.name,
                    'price': item.price,
                    'quantity': item.quantity,
                    'imageUrl': item.imageUrl,
                    'farmerId': item.farmerId,
                    'farmerName': item.farmerName,
                    'pickupLocation': item.pickupLocation,
                    'unit': item.unit,
                  },
                )
                .toList(),
          ),
        ),
      );
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('Please login to complete your purchase.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/signin',
                arguments: {'redirectTo': '/cart'},
              );
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _clearCart() {
    setState(() => cartItems.clear());
    _showMessage('Cart cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        title: Text('Cart (${cartItems.length})'),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              onPressed: _clearCart,
              icon: const Icon(Icons.delete_sweep),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return _buildCartItemTile(item, index);
                    },
                  ),
                ),
                _buildDeliveryAddressSection(),
                _buildSummaryBar(),
              ],
            ),
    );
  }

  Widget _buildDeliveryAddressSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Delivery Address',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            future: _selectedDeliveryAddress == null
                ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid)
                    .get()
                : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null),
            builder: (context, snapshot) {
              String displayAddress = _selectedDeliveryAddress ?? 'Loading...';

              if (_selectedDeliveryAddress == null && snapshot.hasData && snapshot.data != null) {
                displayAddress = _customerDeliveryLocation(
                  snapshot.data!.data(),
                );
              }

              // Determine origin (pickup) and destination (delivery district)
              final originDistrict = cartItems.isNotEmpty
                  ? (cartItems.first.pickupLocation.isNotEmpty ? cartItems.first.pickupLocation : 'Pickup location not specified')
                  : 'Pickup location not specified';
              final destinationDistrict = displayAddress;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayAddress,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Distance & Fee info
                  FutureBuilder<Map<String, double>>(
                    future: (destinationDistrict == 'Delivery address not specified' || originDistrict == 'Pickup location not specified')
                        ? Future.value({'distance': 0.0, 'fee': 0.0})
                        : _computeDistanceAndFee(originDistrict, destinationDistrict),
                    builder: (context, infoSnap) {
                      if (infoSnap.connectionState == ConnectionState.waiting) {
                        return const Text('Calculating distance...', style: TextStyle(fontSize: 13));
                      }
                      if (infoSnap.hasError) {
                        // store error for summary display
                        if (_deliveryError != infoSnap.error.toString()) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) setState(() => _deliveryError = infoSnap.error.toString());
                          });
                        }
                        return Text('Delivery info: ${infoSnap.error}', style: const TextStyle(fontSize: 13, color: Colors.red));
                      }
                      final data = infoSnap.data ?? {'distance': 0.0, 'fee': 0.0};
                      final newDistance = data['distance'] ?? 0.0;
                      final newFee = data['fee'] ?? 0.0;
                      // update state once
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if ((_deliveryDistanceKm - newDistance).abs() > 0.001 || (_deliveryFee - newFee).abs() > 0.001) {
                          setState(() {
                            _deliveryDistanceKm = newDistance;
                            _deliveryFee = newFee;
                            _deliveryError = null;
                          });
                        }
                      });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Origin: $originDistrict', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          Text('Destination: $destinationDistrict', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          Text('Distance: ${newDistance.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          Text('Delivery Fee: MK ${newFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectDeliveryAddress,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Change Address'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(CartItem item, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item.imageUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.image),
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'MK ${item.price} / ${item.unit}\nFarmer: ${item.farmerName}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => setState(() {
                if (item.quantity > 1)
                  item.quantity--;
                else
                  cartItems.removeAt(index);
              }),
            ),
            Text(
              '${item.quantity}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() {
                if (item.stock == null || item.quantity < item.stock!) {
                  item.quantity++;
                } else {
                  _showMessage('Only ${item.stock} available');
                }
              }),
            ),
          ],
        ),
      ),
    );
  }

  //  UPDATED: Small and Centered Checkout Button
  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'MK ${(getTotal() + _deliveryFee).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          if (_deliveryFee > 0 || _deliveryError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _deliveryError == null ? 'Delivery Fee' : 'Delivery Fee (error)',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    _deliveryError == null ? 'MK ${_deliveryFee.toStringAsFixed(2)}' : _deliveryError!,
                    style: TextStyle(
                      fontSize: 14,
                      color: _deliveryError == null ? Colors.black87 : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          //  Small Centered Button
          Center(
            child: SizedBox(
              width: 200, // Specific width to make it small
              height: 45,
              child: ElevatedButton(
                onPressed: _isProcessingPayment ? null : _proceedToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _isProcessingPayment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'PAY NOW',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
