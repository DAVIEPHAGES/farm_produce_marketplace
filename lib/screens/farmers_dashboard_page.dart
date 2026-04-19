import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_produce_page.dart';

class FarmersDashboardPage extends StatefulWidget {
  const FarmersDashboardPage({super.key});

  @override
  State<FarmersDashboardPage> createState() => _FarmersDashboardPageState();
}

class _FarmersDashboardPageState extends State<FarmersDashboardPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Text("Farmers Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddProducePage(),
                ),
              );
            },
          )
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('produces')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No products yet.\nTap + to add produce.",
                textAlign: TextAlign.center,
              ),
            );
          }

          final products = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: products.length,
            itemBuilder: (context, index) {

              final data = products[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: data['image_url'] != null
                      ? Image.network(
                          data['image_url'],
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image),

                  title: Text(data['name'] ?? 'No name'),

                  subtitle: Text(
                    "Price: MWK ${data['price'] ?? 0}\nQty: ${data['quantity'] ?? 0}",
                  ),

                  trailing: const Icon(Icons.arrow_forward_ios),
                ),
              );
            },
          );
        },
      ),
    );
  }
}