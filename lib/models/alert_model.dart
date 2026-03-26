import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  final String title;
  final String district;
  final GeoPoint location;
  final bool isOfficial;
  final String severity; // Critical, Warning, Info
  final String status; // active, engaged, resolved
  final String visibility; // public, personal, private
  final String type; // Fire, Flood, Medical, Physical, Transport, etc.
  final String createdBy;
  final String? engagedBy;
  final Timestamp timestamp;
  final String? description;
  final String? detailedAddress;
  final List<String>? aiActions;
  final bool isPublicized;
  final bool isSOS;
  final String? imageBase64;

  AlertModel({
    required this.id,
    required this.title,
    required this.district,
    required this.location,
    required this.isOfficial,
    required this.severity,
    required this.status,
    required this.visibility,
    required this.type,
    required this.createdBy,
    this.engagedBy,
    required this.timestamp,
    this.description,
    this.detailedAddress,
    this.aiActions,
    this.isPublicized = false,
    this.isSOS = false,
    this.imageBase64,
  });

  factory AlertModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AlertModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Alert',
      district: data['district'] as String? ?? '',
      location: data['location'] as GeoPoint? ?? const GeoPoint(0, 0),
      isOfficial: data['isOfficial'] as bool? ?? false,
      severity: data['severity'] as String? ?? 'Info',
      status: data['status'] as String? ?? 'active',
      visibility: data['visibility'] as String? ?? 'public',
      type: data['type'] as String? ?? 'General',
      createdBy: data['createdBy'] as String? ?? '',
      engagedBy: data['engagedBy'] as String?,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      description: data['description'] as String?,
      detailedAddress: data['detailedAddress'] as String?,
      aiActions: data['ai_actions'] != null
          ? List<String>.from(data['ai_actions'])
          : null,
      isPublicized: data['isPublicized'] as bool? ?? (data['visibility'] == 'public'),
      isSOS: data['isSOS'] as bool? ?? false,
      imageBase64: data['imageBase64'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'district': district,
      'location': location,
      'isOfficial': isOfficial,
      'severity': severity,
      'status': status,
      'visibility': visibility,
      'isPublicized': isPublicized,
      'isSOS': isSOS,
      'type': type,
      'createdBy': createdBy,
      'engagedBy': engagedBy,
      'timestamp': timestamp,
      'description': description,
      'detailedAddress': detailedAddress,
      'ai_actions': aiActions,
      'imageBase64': imageBase64,
    };
  }
}
