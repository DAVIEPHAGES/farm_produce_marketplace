import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminFarmersPage extends StatefulWidget {
  const AdminFarmersPage({super.key});

  @override
  State<AdminFarmersPage> createState() => _AdminFarmersPageState();
}

class _AdminFarmersPageState extends State<AdminFarmersPage> {
  Future<void> _toggleFarmerVerification(String farmerId, bool currentStatus) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(farmerId)
        .update({
          'isVerified': !currentStatus,
          'verifiedAt': !currentStatus ? FieldValue.serverTimestamp() : null,
        });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Farmer ${!currentStatus ? 'verified' : 'unverified'}'),
        backgroundColor: !currentStatus ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: 'farmer')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No farmers registered yet'),
          );
        }
        
        final farmers = snapshot.data!.docs;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: farmers.length,
          itemBuilder: (context, index) {
            final farmer = farmers[index];
            final data = farmer.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: data['isVerified'] == true
                      ? Colors.green
                      : Colors.orange,
                  child: Text(
                    data['name']?.substring(0, 1).toUpperCase() ?? 'F',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  data['name'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['email'] ?? 'No email'),
                    if (data['isVerified'] == true)
                      const Chip(
                        label: Text('Verified'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white, fontSize: 10),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Farm Details
                        const Text(
                          'Farm Details:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Farm Name: ${data['farmName'] ?? 'N/A'}'),
                        Text('Address: ${data['farmAddress'] ?? 'N/A'}'),
                        Text('City: ${data['farmCity'] ?? 'N/A'}'),
                        Text('District: ${data['farmDistrict'] ?? 'N/A'}'),
                        
                        const Divider(),
                        
                        // Contact Info
                        const Text(
                          'Contact Information:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Email: ${data['email'] ?? 'N/A'}'),
                        Text('Phone: ${data['phone'] ?? 'N/A'}'),
                        
                        const Divider(),
                        
                        // Stats
                        const Text(
                          'Statistics:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Products: ${data['totalProducts'] ?? 0}'),
                        Text('Total Sales: MK ${data['totalSales'] ?? 0}'),
                        Text('Rating: ${data['rating'] ?? 0.0} ⭐'),
                        
                        const Divider(),
                        
                        // Actions
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _toggleFarmerVerification(
                                  farmer.id,
                                  data['isVerified'] ?? false,
                                ),
                                icon: Icon(
                                  data['isVerified'] == true
                                      ? Icons.verified
                                      : Icons.verified_user,
                                ),
                                label: Text(
                                  data['isVerified'] == true
                                      ? 'Unverify'
                                      : 'Verify Farmer',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: data['isVerified'] == true
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}