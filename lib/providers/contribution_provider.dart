import 'package:flutter/material.dart';
import 'package:startup_20/core/services/firestore_service.dart';
import 'package:startup_20/data/models/contribution_model.dart';

class ContributionProvider with ChangeNotifier {
  final FirestoreService _service = FirestoreService();

  Stream<List<Contribution>> getContributions() {
    return _service.getContributions().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Contribution.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> addContribution(Contribution contribution) async {
    await _service.addContribution(contribution.toFirestore());
  }
}
