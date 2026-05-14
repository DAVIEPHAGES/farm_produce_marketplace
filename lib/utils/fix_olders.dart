// Create this temporary fix page
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FixOrdersWithNames extends StatefulWidget {
  const FixOrdersWithNames({super.key});

  @override
  State<FixOrdersWithNames> createState() => _FixOrdersWithNamesState();
}

class _FixOrdersWithNamesState extends State<FixOrdersWithNames> {
  bool _isFixing = false;
  String _result = '';

  Future<void> _fixOrders() async {
    setState(() {
      _isFixing = true;
      _result = 'Fixing orders...\n';
    });

    try {
      // Get all users (farmers) to create a name-to-UID mapping
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'farmer')
          .get();
      
      final Map<String, String> nameToUid = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final name = data['name']?.toString().toLowerCase();
        final uid = doc.id; // Document ID is the Firebase UID
        if (name != null && name.isNotEmpty) {
          nameToUid[name] = uid;
          _result += '📌 Found farmer: $name → $uid\n';
        }
      }
      
      _result += '\n🔍 Searching for orders with farmer names...\n\n';
      
      // Get all orders with paymentStatus = 'completed'
      final orders = await FirebaseFirestore.instance
          .collection('orders')
          .where('paymentStatus', isEqualTo: 'completed')
          .get();
      
      int fixedCount = 0;
      
      for (var orderDoc in orders.docs) {
        final order = orderDoc.data();
        final farmerIds = order['farmerIds'] as List? ?? [];
        
        if (farmerIds.isEmpty) continue;
        
        // Check if the farmerId is a name (not a UID)
        final firstFarmer = farmerIds.first.toString();
        final isName = firstFarmer.length != 28 && !firstFarmer.contains('@');
        
        if (isName) {
          final farmerName = firstFarmer.toLowerCase();
          final correctUid = nameToUid[farmerName];
          
          if (correctUid != null) {
            await orderDoc.reference.update({
              'farmerIds': [correctUid],
            });
            fixedCount++;
            _result += '✅ Fixed order ${orderDoc.id}: $firstFarmer → $correctUid\n';
          } else {
            _result += '❌ Could not find UID for farmer: $firstFarmer\n';
          }
        }
      }
      
      _result += '\n📊 Summary: Fixed $fixedCount orders\n';
      
      if (fixedCount > 0) {
        _result += '\n🎉 These orders will now show correctly in farmer dashboard!\n';
      }
      
    } catch (e) {
      _result += '\n❌ Error: $e\n';
    } finally {
      setState(() {
        _isFixing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Order Farmer IDs'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'This will replace farmer NAMES with UIDs in existing orders.',
                style: TextStyle(color: Colors.blue),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isFixing ? null : _fixOrders,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isFixing
                  ? const CircularProgressIndicator()
                  : const Text('FIX ORDERS', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _result,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}