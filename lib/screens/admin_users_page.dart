import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_farmer_details_page.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  int _selectedTab = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleVerification(String userId, bool currentStatus) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isVerified': !currentStatus,
        'verifiedAt': !currentStatus ? FieldValue.serverTimestamp() : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Farmer ${!currentStatus ? 'verified' : 'unverified'} successfully!',
            ),
            backgroundColor: !currentStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteUser(
    String userId,
    String userName,
    String userType,
  ) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text(
          'Are you sure you want to delete "$userName"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      try {
        if (userType == 'farmer') {
          final products = await FirebaseFirestore.instance
              .collection('products')
              .where('farmerId', isEqualTo: userId)
              .get();

          for (var product in products.docs) {
            await product.reference.delete();
          }
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$userName deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _showCreateLogisticsCompanyDialog() async {
    final _formKey = GlobalKey<FormState>();
    final companyNameController = TextEditingController();
    final companyAddressController = TextEditingController();
    final companyDescriptionController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSubmitting = false;

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Logistics Company'),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: companyNameController,
                        decoration: const InputDecoration(
                          labelText: 'Company Name',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the company name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: companyAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Company Address',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the company address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Contact Email (Optional)',
                        ),
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            final emailRegex = RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone (Optional)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: companyDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Company Description (Optional)',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => isSubmitting = true);

                          try {
                            final email = emailController.text
                                .trim()
                                .toLowerCase();
                            final cleanedPhone = phoneController.text
                                .trim()
                                .replaceAll(RegExp(r'[^0-9+]'), '');
                            final companyDescription =
                                companyDescriptionController.text.trim();
                            final docRef = FirebaseFirestore.instance
                                .collection('users')
                                .doc();
                            final companyData = <String, dynamic>{
                              'uid': docRef.id,
                              'name': companyNameController.text.trim(),
                              'userType': 'logistics_company',
                              'companyName': companyNameController.text.trim(),
                              'companyAddress': companyAddressController.text
                                  .trim(),
                              'isVerified': true,
                              'verifiedAt': FieldValue.serverTimestamp(),
                              'createdAt': FieldValue.serverTimestamp(),
                            };

                            if (email.isNotEmpty) {
                              companyData['email'] = email;
                            }
                            if (cleanedPhone.isNotEmpty) {
                              companyData['phone'] = cleanedPhone;
                            }
                            if (companyDescription.isNotEmpty) {
                              companyData['companyDescription'] =
                                  companyDescription;
                            }

                            await docRef.set(companyData);

                            if (mounted) {
                              Navigator.of(context).pop(true);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Logistics company created successfully.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setState(() => isSubmitting = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create company: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    companyNameController.dispose();
    companyAddressController.dispose();
    companyDescriptionController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return DefaultTabController(
      length: 5,
      initialIndex: _selectedTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Users'),
          backgroundColor: const Color(0xFF2E7D32),
          actions: [
            if (_selectedTab == 3)
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add Logistics Company',
                onPressed: _isLoading
                    ? null
                    : _showCreateLogisticsCompanyDialog,
              ),
          ],
        ),
        body: Column(
          children: [
            // Tab Bar
            Container(
              color: Colors.white,
              child: TabBar(
                tabs: const [
                  Tab(text: 'All Users', icon: Icon(Icons.people)),
                  Tab(text: 'Customers', icon: Icon(Icons.person)),
                  Tab(text: 'Farmers', icon: Icon(Icons.agriculture)),
                  Tab(text: 'Logistics', icon: Icon(Icons.local_shipping)),
                  Tab(text: 'Drivers', icon: Icon(Icons.directions_car)),
                ],
                labelColor: const Color(0xFF2E7D32),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF2E7D32),
                onTap: (index) {
                  if (mounted) {
                    setState(() {
                      _selectedTab = index;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  }
                },
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            if (mounted) {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            }
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  if (mounted) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  }
                },
              ),
            ),

            // Users List
            Expanded(child: _buildUsersList()),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!mounted) return const SizedBox.shrink();

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No users found',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        var users = snapshot.data!.docs;

        // Filter by tab
        if (_selectedTab == 1) {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['userType'] == 'customer';
          }).toList();
        } else if (_selectedTab == 2) {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['userType'] == 'farmer';
          }).toList();
        } else if (_selectedTab == 3) {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['userType'] == 'logistics_company';
          }).toList();
        } else if (_selectedTab == 4) {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['userType'] == 'driver';
          }).toList();
        }

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? '').toLowerCase();
            final email = (data['email'] ?? '').toLowerCase();
            return name.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No users match your search'
                      : 'No ${_getTabName().toLowerCase()} found',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final data = user.data() as Map<String, dynamic>;
            final userType = data['userType'] ?? 'customer';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              child: ExpansionTile(
                key: ValueKey(user.id),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: userType == 'farmer'
                      ? Colors.orange
                      : userType == 'driver'
                      ? Colors.indigo
                      : userType == 'logistics_company'
                      ? Colors.blue
                      : Colors.green,
                  child: Text(
                    (data['name']?.substring(0, 1).toUpperCase() ?? 'U'),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: userType == 'farmer'
                                ? Colors.orange
                                : Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            userType.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if ((userType == 'farmer' ||
                                userType == 'logistics_company') &&
                            data['isVerified'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'VERIFIED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (userType == 'farmer' || userType == 'logistics_company')
                      IconButton(
                        icon: Icon(
                          data['isVerified'] == true
                              ? Icons.verified
                              : Icons.verified_user,
                          color: data['isVerified'] == true
                              ? Colors.green
                              : Colors.orange,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => _toggleVerification(
                                user.id,
                                data['isVerified'] ?? false,
                              ),
                        tooltip: data['isVerified'] == true
                            ? 'Unverify'
                            : 'Verify',
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: _isLoading
                          ? null
                          : () => _deleteUser(
                              user.id,
                              data['name'] ?? 'User',
                              userType,
                            ),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Information:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('User ID:', user.id),
                        _buildInfoRow('Name:', data['name'] ?? 'Not provided'),
                        _buildInfoRow(
                          'Email:',
                          data['email'] ?? 'Not provided',
                        ),
                        _buildInfoRow(
                          'Phone:',
                          data['phone'] ?? 'Not provided',
                        ),
                        _buildInfoRow('User Type:', userType),
                        _buildInfoRow(
                          'Joined:',
                          _formatDate(data['timestamp'] ?? data['createdAt']),
                        ),

                        if (userType == 'farmer') ...[
                          const Divider(),
                          const Text(
                            'Farm Information:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Farm Name:',
                            data['farmName'] ?? 'Not provided',
                          ),
                          _buildInfoRow(
                            'Address:',
                            data['farmAddress'] ?? 'Not provided',
                          ),
                          _buildInfoRow(
                            'City:',
                            data['farmCity'] ?? 'Not provided',
                          ),
                          _buildInfoRow(
                            'District:',
                            data['farmDistrict'] ?? 'Not provided',
                          ),
                          if (data['farmDescription'] != null &&
                              data['farmDescription'].isNotEmpty)
                            _buildInfoRow(
                              'Description:',
                              data['farmDescription'],
                            ),

                          const Divider(),
                          const Text(
                            'Verification:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Status:',
                            data['isVerified'] == true
                                ? 'Verified ✓'
                                : 'Pending',
                          ),
                          if (data['verifiedAt'] != null)
                            _buildInfoRow(
                              'Verified On:',
                              _formatDate(data['verifiedAt']),
                            ),
                          const SizedBox(height: 16),
                          Center(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.bar_chart),
                              label: const Text('View Sales Details'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AdminFarmerDetailsPage(
                                          farmerId: user.id,
                                          farmerName: data['name'] ?? 'Farmer',
                                        ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        if (userType == 'logistics_company') ...[
                          const Divider(),
                          const Text(
                            'Logistics Company:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Company Name:',
                            data['companyName'] ?? 'Not provided',
                          ),
                          _buildInfoRow(
                            'Address:',
                            data['companyAddress'] ?? 'Not provided',
                          ),
                          if (data['companyDescription'] != null &&
                              data['companyDescription'].isNotEmpty)
                            _buildInfoRow(
                              'Description:',
                              data['companyDescription'],
                            ),
                          const Divider(),
                          const Text(
                            'Verification:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Status:',
                            data['isVerified'] == true
                                ? 'Verified ✓'
                                : 'Pending',
                          ),
                          if (data['verifiedAt'] != null)
                            _buildInfoRow(
                              'Verified On:',
                              _formatDate(data['verifiedAt']),
                            ),
                        ],

                        if (userType == 'driver') ...[
                          const Divider(),
                          const Text(
                            'Driver Details:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'License #:',
                            data['licenseNumber'] ?? 'Not provided',
                          ),
                          _buildInfoRow(
                            'Company Name:',
                            data['companyName'] ?? 'Not provided',
                          ),
                          _buildInfoRow(
                            'Company ID:',
                            data['companyId'] ?? 'Not provided',
                          ),
                          _buildInfoRow('Status:', data['status'] ?? 'active'),
                        ],
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

  String _getTabName() {
    switch (_selectedTab) {
      case 0:
        return 'users';
      case 1:
        return 'customers';
      case 2:
        return 'farmers';
      case 3:
        return 'logistics companies';
      case 4:
        return 'drivers';
      default:
        return 'users';
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'Recently';
  }
}
