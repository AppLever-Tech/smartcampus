class AcademicRecordModel {
  final String? id;
  final String uuid; // Linked via uuid from smcUserMaster
  final String recordType; // 10th Mark Sheet, 12th Mark Sheet, etc.
  final String? description;
  final String? fileUrl;
  final String? fileName;
  final DateTime createdOn;

  AcademicRecordModel({
    this.id,
    required this.uuid,
    required this.recordType,
    this.description,
    this.fileUrl,
    this.fileName,
    required this.createdOn,
  });

  factory AcademicRecordModel.fromFirestore(String id, Map<String, dynamic> data) {
    return AcademicRecordModel(
      id: id,
      uuid: data['uuid'] ?? '',
      recordType: data['recordType'] ?? '',
      description: data['description'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      createdOn: data['createdOn'] != null 
          ? DateTime.parse(data['createdOn']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'recordType': recordType,
      'description': description,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'createdOn': createdOn.toIso8601String(),
    };
  }
}
