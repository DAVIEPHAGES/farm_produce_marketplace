import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Check if current user is admin
  static Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final doc = await _firestore.collection('Admins').doc(user.uid).get();
    return doc.exists;
  }

  // Get admin role
  static Future<String?> getAdminRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final doc = await _firestore.collection('Admins').doc(user.uid).get();
    if (!doc.exists) return null;
    
    return doc.data()?['role'];
  }

  // Get admin data
  static Future<Map<String, dynamic>?> getCurrentAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final doc = await _firestore.collection('Admins').doc(user.uid).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }
}