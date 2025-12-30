// lib/screens/patient_search_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_card.dart';
import '../widgets/primary_button.dart';
import 'doctor_profile_screen.dart';

class PatientSearchScreen extends StatefulWidget {
  const PatientSearchScreen({super.key});

  @override
  State<PatientSearchScreen> createState() => _PatientSearchScreenState();
}

class _PatientSearchScreenState extends State<PatientSearchScreen> {
  final _keywordCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _specCtrl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  
  // ✅ New State for Fallback Logic
  bool _showFallback = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    final token = _keywordCtrl.text.trim().toLowerCase();
    final spec = _specCtrl.text.trim().toLowerCase();
    final city = _cityCtrl.text.trim().toLowerCase();

    // 1. Fallback Mode: Show 10 Active Doctors if search failed
    if (_showFallback) {
      return _db.collection('doctors')
          .where('available', isEqualTo: true)
          .limit(10)
          .snapshots();
    }

    // 2. Standard Search Mode
    try {
      if (token.isNotEmpty) {
        // Priority 1: Search by keywords (name, etc.)
        return _db.collection('doctors')
            .where('searchKeywords', arrayContains: token)
            .limit(50)
            .snapshots();
      }

      // If token empty but spec or city provided, prefer single-field queries
      if (spec.isNotEmpty && city.isEmpty) {
        return _db.collection('doctors')
            .where('specializationLower', isEqualTo: spec)
            .limit(50)
            .snapshots();
      }

      if (city.isNotEmpty && spec.isEmpty) {
        return _db.collection('doctors')
            .where('cityLower', isEqualTo: city)
            .limit(50)
            .snapshots();
      }

      // Default: Show all doctors sorted by name
      return _db.collection('doctors')
          .orderBy('displayName')
          .limit(50)
          .snapshots();
          
    } on FirebaseException catch (e) {
      return Stream.error(e);
    }
  }

  bool _matchesClientFilter(Map<String, dynamic> doc) {
    // If in fallback mode, we don't apply the strict search filters
    if (_showFallback) return true;

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

  void _navigateToProfile(String uid) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DoctorProfileScreen(),
        settings: RouteSettings(arguments: uid),
      ),
    );
  }

  void _search() {
    // Reset fallback when user triggers a new search
    setState(() { 
      _showFallback = false; 
    });
  }

  void _clearAll() {
    _keywordCtrl.clear();
    _specCtrl.clear();
    _cityCtrl.clear();
    setState(() { _showFallback = false; });
  }

  @override
  void dispose() {
    _keywordCtrl.dispose();
    _specCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find a doctor')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // Search Filters
            CustomCard(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                TextFormField(
                  controller: _keywordCtrl, 
                  decoration: const InputDecoration(labelText: 'Name / Keyword (e.g. "cardio")'),
                  onFieldSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _specCtrl, 
                      decoration: const InputDecoration(labelText: 'Specialization'),
                      onFieldSubmitted: (_) => _search(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _cityCtrl, 
                      decoration: const InputDecoration(labelText: 'City'),
                      onFieldSubmitted: (_) => _search(),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: PrimaryButton(label: 'Search', onPressed: _search)),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _clearAll, child: const Text('Clear')),
                ])
              ]),
            ),
            
            const SizedBox(height: 12),
            
            // Fallback Notice
            if (_showFallback)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text('No exact matches found. Showing currently active doctors:', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),

            // Doctor List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _buildStream(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs.map((d) => d.data()..['uid'] = d.id).toList();
                  final filtered = docs.where((d) => _matchesClientFilter(d)).toList();

                  // ✅ AUTOMATIC FALLBACK LOGIC
                  // If filters returned nothing, and we aren't already in fallback mode,
                  // and the user actually typed something (so it's not just an initial empty state)
                  if (filtered.isEmpty && !_showFallback && (_keywordCtrl.text.isNotEmpty || _specCtrl.text.isNotEmpty || _cityCtrl.text.isNotEmpty)) {
                     WidgetsBinding.instance.addPostFrameCallback((_) {
                       if (mounted) setState(() => _showFallback = true);
                     });
                     return const Center(child: CircularProgressIndicator());
                  }

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No doctors found', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final doc = filtered[i];
                      final name = doc['displayName'] ?? 'Unknown Doctor';
                      final spec = doc['specialization'] ?? 'General';
                      final city = doc['city'] ?? 'Unknown City';
                      final kyc = doc['kycVerified'] == true;
                      final available = doc['available'] == true; // ✅ Check availability
                      final uid = doc['uid'] as String;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _navigateToProfile(uid),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 28,
                                        backgroundColor: available ? Colors.green.shade50 : Colors.blue.shade50,
                                        child: Icon(Icons.person, color: available ? Colors.green : Colors.blue),
                                      ),
                                      if (available)
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 12, height: 12,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                          ),
                                        )
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                            if (kyc) ...[
                                              const SizedBox(width: 6),
                                              const Icon(Icons.verified, color: Colors.blue, size: 16),
                                            ]
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text("$spec • $city", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  if (available)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                      child: const Text('Active', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
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