import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FarmerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get uid => _auth.currentUser?.uid;

  Stream<DocumentSnapshot> streamFarmer() {
    if (uid == null) {
      return Stream.error('User not logged in');
    }
    return _firestore.collection('farmers').doc(uid).snapshots();
  }

  Future<void> addProduct(Map<String, dynamic> product) async {
    await _firestore.collection('farmers').doc(uid).update({
      'products': FieldValue.arrayUnion([product])
    });
  }

  Future<void> updateEarnings(double amount) async {
    await _firestore.collection('farmers').doc(uid).update({
      'totalEarnings': FieldValue.increment(amount)
    });
  }
}