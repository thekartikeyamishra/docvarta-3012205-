import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Stream<Map<String, int>> getDailyStatsStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _firestore
        .collection('appointments')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
          int total = snapshot.docs.length;
          int completed = 0;
          int cancelled = 0;
          int videoCalls = 0;

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status'] as String?;
            final link = data['meetLink'] as String?;

            if (status == 'completed') completed++;
            if (status == 'cancelled') cancelled++;
            if (link != null && link.isNotEmpty) videoCalls++;
          }

          return {
            'total': total,
            'completed': completed,
            'cancelled': cancelled,
            'videoCalls': videoCalls,
          };
        });
  }

  Future<String> generateMonthlyReport({required int month, required int year}) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('generateAdminReport');
      
      final result = await callable.call({
        'month': month,
        'year': year,
        'type': 'pdf', // or 'csv'
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return data['downloadUrl'] as String;
      } else {
        throw Exception(data['message'] ?? 'Report generation failed');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("Cloud Report Error: ${e.message}");
      throw Exception("Failed to generate report: ${e.message}");
    } catch (e) {
      debugPrint("Report Service Error: $e");
      throw Exception("An unexpected error occurred.");
    }
  }


  Future<List<Map<String, dynamic>>> getTopDoctors() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .orderBy('completedCount', descending: true) 
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc.data()['displayName'] ?? 'Unknown',
        'count': doc.data()['completedCount'] ?? 0,
        'rating': doc.data()['rating'] ?? 0.0,
      }).toList();
    } catch (e) {
      debugPrint("Leaderboard Error: $e");
      return [];
    }
  }
}