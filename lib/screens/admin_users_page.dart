import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUsersPage extends StatelessWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Users'),
          backgroundColor: const Color(0xFF2E7D32),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Customers'),
              Tab(text: 'Farmers'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UserList(userType: 'customer'),
            _UserList(userType: 'farmer'),
          ],
        ),
      ),
    );
  }
}

class _UserList extends StatelessWidget {
  final String userType;
  
  const _UserList({required this.userType});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('userType', isEqualTo: userType)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No ${userType}s found'),
          );
        }
        
        final users = snapshot.data!.docs;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final data = user.data() as Map<String, dynamic>;
            
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    data['name']?.substring(0, 1).toUpperCase() ?? 'U',
                  ),
                ),
                title: Text(data['name'] ?? 'Unknown'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['email'] ?? 'No email'),
                    Text('Phone: ${data['phone'] ?? 'Not provided'}'),
                    Text('Joined: ${_formatDate(data['createdAt'])}'),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
  
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'Recently';
    }
    return 'Recently';
  }
}