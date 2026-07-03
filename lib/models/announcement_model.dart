import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartcampus/data/org_field.dart';

class AnnouncementModel {
  final String id;
  final String orgId;
  final String deptId;
  final String title;
  final String description;
  final String category;
  final List<String> targetSchemes; // Empty means all students
  final DateTime publishDate;
  final String attachmentUrl;
  final String attachmentName;
  final DateTime createdAt;
  final DateTime? updatedAt;

  static const List<String> categories = [
    'General',
    'Exam',
    'Holiday',
    'Event',
    'Placement',
    'Emergency',
  ];

  AnnouncementModel({
    required this.id,
    required this.orgId,
    required this.deptId,
    required this.title,
    required this.description,
    required this.category,
    required this.targetSchemes,
    required this.publishDate,
    this.attachmentUrl = '',
    this.attachmentName = '',
    required this.createdAt,
    this.updatedAt,
  });

  factory AnnouncementModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AnnouncementModel(
      id: id,
      orgId: OrgField.readOrgId(data),
      deptId: OrgField.readDeptId(data),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? 'General',
      targetSchemes: (data['targetSchemes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      publishDate: (data['publishDate'] is Timestamp
          ? (data['publishDate'] as Timestamp).toDate()
          : DateTime.now()),
      attachmentUrl: data['attachmentUrl'] ?? '',
      attachmentName: data['attachmentName'] ?? '',
      createdAt: (data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now()),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      ...OrgField.orgIdWrite(orgId),
      if (OrgField.normalize(deptId).isNotEmpty) OrgField.deptIdKey: OrgField.normalize(deptId),
      'title': title,
      'description': description,
      'category': category,
      'targetSchemes': targetSchemes,
      'publishDate': Timestamp.fromDate(publishDate),
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? orgId,
    String? deptId,
    String? title,
    String? description,
    String? category,
    List<String>? targetSchemes,
    DateTime? publishDate,
    String? attachmentUrl,
    String? attachmentName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      deptId: deptId ?? this.deptId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      targetSchemes: targetSchemes ?? this.targetSchemes,
      publishDate: publishDate ?? this.publishDate,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
