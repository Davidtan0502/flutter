import 'package:intl/intl.dart';

class IncidentData {
  final String id;
  final String? incidentType;
  final String? address;
  final String? name;
  final String? contactNumber;
  final String? description;
  final String status;
  final DateTime? timestamp;
  final List<dynamic> imageUrls;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  IncidentData({
    required this.id,
    required this.incidentType,
    required this.address,
    required this.name,
    required this.contactNumber,
    required this.description,
    required this.status,
    required this.timestamp,
    required this.imageUrls,
    this.createdAt,
    this.updatedAt,
  });

  

  factory IncidentData.fromMap(Map<String, dynamic> data, String id) {
    return IncidentData(
      id: id,
      incidentType: data['incident_type']?.toString(),
      address: data['address']?.toString(),
      name: data['name']?.toString(),
      contactNumber: data['contact_number']?.toString(),
      description: data['description']?.toString(),
      status: (data['status'] ?? 'pending').toString(),
      timestamp: data['timestamp'] != null 
          ? DateTime.parse(data['timestamp'])
          : null,
      imageUrls: data['image_urls'] as List<dynamic>? ?? [],
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at'])
          : null,
      updatedAt: data['updated_at'] != null 
          ? DateTime.parse(data['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incident_type': incidentType,
      'address': address,
      'name': name,
      'contact_number': contactNumber,
      'description': description,
      'status': status,
      'timestamp': timestamp?.toIso8601String(),
      'image_urls': imageUrls,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}