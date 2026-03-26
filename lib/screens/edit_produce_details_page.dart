// screens/edit_produce_page.dart
import 'package:flutter/material.dart';

class EditProducePage extends StatefulWidget {
  final ProduceItem? produceItem;

  const EditProducePage({super.key, this.produceItem});

  @override
  State<EditProducePage> createState() => _EditProducePageState();
}

class _EditProducePageState extends State<EditProducePage> {
  // Sample data - in real app, this would come from your backend/database
  late ProduceItem _produceItem;

  // Controllers for editing
  late TextEditingController _priceController;
  late TextEditingController _quantityController;
  late TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    // Initialize with passed item or create sample data
    _produceItem = widget.produceItem ??
        ProduceItem(
          id: '1',
          name: 'Fresh Tomatoes',
          price: 2.99,
          quantity: '50 kg',
          location: 'Nairobi, Kenya',
          description: 'Fresh organic tomatoes from local farm',
          imageUrl: 'assets/tomatoes.jpg',
        );

    _priceController =
        TextEditingController(text: _produceItem.price.toString());
    _quantityController = TextEditingController(text: _produceItem.quantity);
    _locationController = TextEditingController(text: _produceItem.location);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showEditOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.delete_outline,
                title: 'Delete Produce',
                color: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation();
                },
              ),
              _buildOptionTile(
                icon: Icons.edit,
                title: 'Modify Price',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog('Price', _priceController, (value) {
                    setState(() {
                      _produceItem.price = double.parse(value);
                      _priceController.text = value;
                    });
                  });
                },
              ),
              _buildOptionTile(
                icon: Icons.inventory_2_outlined,
                title: 'Modify Quantity',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog('Quantity', _quantityController, (value) {
                    setState(() {
                      _produceItem.quantity = value;
                      _quantityController.text = value;
                    });
                  });
                },
              ),
              _buildOptionTile(
                icon: Icons.location_on_outlined,
                title: 'Change Location',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog('Location', _locationController, (value) {
                    setState(() {
                      _produceItem.location = value;
                      _locationController.text = value;
                    });
                  });
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showEditDialog(
      String field, TextEditingController controller, Function(String) onSave) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Edit $field'),
          content: TextField(
            controller: controller,
            keyboardType:
                field == 'Price' ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: 'Enter new $field',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onSave(controller.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$field updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Produce'),
          content: const Text(
              'Are you sure you want to delete this produce item? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Produce deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
                // Navigate back to home or previous page
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'EDIT FARM PRODUCE DETAILS',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Produce Image Section
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: AssetImage(_produceItem.imageUrl),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) => null,
                ),
              ),
              child: _produceItem.imageUrl.isEmpty
                  ? const Icon(Icons.image_not_supported,
                      size: 50, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 20),

            // Produce Name Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Produce Name',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _produceItem.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Price Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '\$${_produceItem.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        _showEditOptions();
                      },
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Quantity Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _produceItem.quantity,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        _showEditOptions();
                      },
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Location Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              _produceItem.location,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        _showEditOptions();
                      },
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _produceItem.description,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Edit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _showEditOptions,
                icon: const Icon(Icons.edit, size: 20),
                label: const Text(
                  'EDIT PRODUCE DETAILS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Model class for Produce Item
class ProduceItem {
  final String id;
  final String name;
  double price;
  String quantity;
  String location;
  final String description;
  final String imageUrl;

  ProduceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.location,
    required this.description,
    required this.imageUrl,
  });
}
