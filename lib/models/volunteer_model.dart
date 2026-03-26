import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerModel {
  final String uid;
  final String name;
  final String phone;
  final int age;
  final String city;
  final List<String> skills;
  final String status; // 'pending', 'approved', 'rejected'
  final String? genre; // Medical, Physical, Rescue, etc.
  final String? id_64; // Base64 ID (Blueprint: id_64)
  final String? skill_64; // Base64 Certificate (Blueprint: skill_64)
  final String bloodGroup;
  final DateTime appliedAt;

  VolunteerModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.age,
    required this.city,
    required this.skills,
    required this.status,
    this.genre,
    this.id_64,
    this.skill_64,
    required this.bloodGroup,
    required this.appliedAt,
  });

  factory VolunteerModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VolunteerModel(
      uid: data['uid'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      age: data['age'] ?? 0,
      city: data['city'] ?? '',
      skills: List<String>.from(data['skills'] ?? []),
      status: data['status'] ?? 'pending',
      genre: data['genre'],
      id_64: data['id_64'],
      skill_64: data['skill_64'],
      bloodGroup: data['blood_group'] ?? '',
      appliedAt: (data['applied_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'age': age,
      'city': city,
      'skills': skills,
      'status': status,
      'genre': genre,
      'id_64': id_64,
      'skill_64': skill_64,
      'blood_group': bloodGroup,
      'applied_at': FieldValue.serverTimestamp(),
    };
  }
}
