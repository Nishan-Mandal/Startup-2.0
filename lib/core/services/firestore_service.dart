import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> addContribution(Map<String, dynamic> data) async {
    await _db.collection('contributions').add(data);
  }

  Stream<QuerySnapshot> getContributions() {
    return _db
        .collection('contributions')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
