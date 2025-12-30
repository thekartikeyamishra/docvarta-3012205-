// G:\docvartaa\lib\screens\search_doctors_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';
import 'doctor_profile_screen.dart';

class SearchDoctorsScreen extends StatefulWidget {
  const SearchDoctorsScreen({super.key});

  @override
  State<SearchDoctorsScreen> createState() => _SearchDoctorsScreenState();
}

class _SearchDoctorsScreenState extends State<SearchDoctorsScreen> {
  final _keywordCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _specCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    // Use tokenized search to avoid composite queries.
    final token = _keywordCtrl.text.trim().toLowerCase();
    final spec = _specCtrl.text.trim().toLowerCase();
    final city = _cityCtrl.text.trim().toLowerCase();

    try {
      if (token.isNotEmpty) {
        // token search — single-field array-contains, no composite index required
        return _db.collection('doctors').where('searchKeywords', arrayContains: token).limit(50).snapshots();
      }

      // If token empty but spec or city provided, prefer single-field queries individually (no composite)
      if (spec.isNotEmpty && city.isEmpty) {
        return _db.collection('doctors').where('specializationLower', isEqualTo: spec).limit(50).snapshots();
      }

      if (city.isNotEmpty && spec.isEmpty) {
        return _db.collection('doctors').where('cityLower', isEqualTo: city).limit(50).snapshots();
      }

      // If both spec & city provided we fallback to server small page & client filter (avoids composite index).
      // Server returns first 50 docs (small cost) and client filters them.
      return _db.collection('doctors').orderBy('displayName').limit(50).snapshots();
    } on FirebaseException catch (e) {
      // fallback to streaming entire small page with defensive error logging
      return Stream.error(e);
    }
  }

  bool _matchesClientFilter(Map<String, dynamic> doc) {
    final token = _keywordCtrl.text.trim().toLowerCase();
    final spec = _specCtrl.text.trim().toLowerCase();
    final city = _cityCtrl.text.trim().toLowerCase();

    final name = (doc['displayName'] ?? '').toString().toLowerCase();
    final special = (doc['specialization'] ?? '').toString().toLowerCase();
    final cityField = (doc['city'] ?? '').toString().toLowerCase();

    if (token.isNotEmpty && !(name.contains(token) || special.contains(token) || cityField.contains(token))) return false;
    if (spec.isNotEmpty && !special.contains(spec)) return false;
    if (city.isNotEmpty && !cityField.contains(city)) return false;
    return true;
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    _specCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _clearAll() {
    _keywordCtrl.clear();
    _specCtrl.clear();
    _cityCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Find a doctor')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            CustomCard(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextFormField(controller: _keywordCtrl, decoration: const InputDecoration(labelText: 'Name / any keyword (e.g. "cardio")')),
                const SizedBox(height: 8),
                TextFormField(controller: _specCtrl, decoration: const InputDecoration(labelText: 'Specialization (optional)')),
                const SizedBox(height: 8),
                TextFormField(controller: _cityCtrl, decoration: const InputDecoration(labelText: 'City (optional)')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: PrimaryButton(label: 'Search', onPressed: () => setState(() {}))),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _clearAll, child: const Text('Clear')),
                ])
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _buildStream(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    final err = snap.error;
                    if (err is FirebaseException && err.code == 'failed-precondition') {
                      // Firestore says an index is required — show helpful message but continue
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Text(
                            'Query needs an index to run server-side. We avoided that by using token-search.\n\n'
                            'If you still see this message, please create the index from Firebase Console (Firestore > Indexes).',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                  final docs = snap.data!.docs.map((d) => d.data()..['uid'] = d.id).toList();
                  // If we used fallback server query, apply client-side filter to avoid composite index
                  final filtered = docs.where((d) => _matchesClientFilter(d)).toList();

                  if (filtered.isEmpty) return const Center(child: Text('No doctors found'));

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final name = doc['displayName'] ?? '';
                      final spec = doc['specialization'] ?? '';
                      final city = doc['city'] ?? '';
                      final kyc = doc['kycVerified'] == true;
                      final uid = doc['uid'] as String;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: CustomCard(
                          padding: const EdgeInsets.all(12),
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorProfileScreen(), settings: RouteSettings(arguments: uid))),
                            leading: CircleAvatar(child: const Icon(Icons.person)),
                            title: Row(children: [
                              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (kyc) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Text('Verified', style: TextStyle(color: Colors.green))),
                            ]),
                            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(spec),
                              const SizedBox(height: 4),
                              Text('$city', style: theme.textTheme.bodySmall),
                            ]),
                            trailing: ElevatedButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DoctorProfileScreen(), settings: RouteSettings(arguments: uid))), child: const Text('View')),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ]),
        ),
      ),
    );
  }
}
