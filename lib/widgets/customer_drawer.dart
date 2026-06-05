import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/remember_me_service.dart';

class CustomerDrawer extends StatelessWidget {
  const CustomerDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [

          // 👤 HEADER
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.green,
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 35, color: Colors.green),
            ),
            accountName: Text(
              user?.displayName ?? "Customer",
              style: const TextStyle(fontSize: 16),
            ),
            accountEmail: Text(
              user?.email ?? "No email",
            ),
          ),

          // 🧑 PROFILE
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("My Profile"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/profile");
            },
          ),

          // 📦 ORDERS
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text("My Orders"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/orders");
            },
          ),

          // 🛒 CART
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text("My Cart"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/cart");
            },
          ),

          // 🔔 NOTIFICATIONS
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text("Notifications"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/notifications");
            },
          ),

          const Spacer(),

          const Divider(),

          // 🚪 LOGOUT
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Logout",
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              RememberMeService.markSignedOut();
              await FirebaseAuth.instance.signOut();

              Navigator.pushNamedAndRemoveUntil(
                context,
                "/signin",
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
