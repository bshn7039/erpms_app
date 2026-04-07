import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String title;
  final String summary;
  final String source;
  final String category; // Weather, Environment, Health, Welfare
  final String? url;
  final Timestamp timestamp;
  final String? district;
  final String? state;

  ReportModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.category,
    this.url,
    required this.timestamp,
    this.district,
    this.state,
  });

  factory ReportModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      summary: data['summary'] ?? '',
      source: data['source'] ?? 'Official Source',
      category: data['category'] ?? 'General',
      url: data['url'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      district: data['district'],
      state: data['state'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'summary': summary,
      'source': source,
      'category': category,
      'url': url,
      'timestamp': timestamp,
      'district': district,
      'state': state,
    };
  }
}
