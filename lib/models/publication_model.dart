class PublicationModel {
  final String? id;
  final String uuid;
  final String title;
  final String type; // Journal, Conference, Research Paper, Book Chapter, Patent
  final String authors;
  final String publisher; // Journal/Conference Name
  final String date;
  final String abstract;
  final String? pdfUrl;
  final String? pdfFileName;
  final DateTime createdOn;

  PublicationModel({
    this.id,
    required this.uuid,
    required this.title,
    required this.type,
    required this.authors,
    required this.publisher,
    required this.date,
    required this.abstract,
    this.pdfUrl,
    this.pdfFileName,
    required this.createdOn,
  });

  factory PublicationModel.fromFirestore(String id, Map<String, dynamic> data) {
    return PublicationModel(
      id: id,
      uuid: data['uuid'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      authors: data['authors'] ?? '',
      publisher: data['publisher'] ?? '',
      date: data['date'] ?? '',
      abstract: data['abstract'] ?? '',
      pdfUrl: data['pdfUrl'],
      pdfFileName: data['pdfFileName'],
      createdOn: data['createdOn'] != null 
          ? DateTime.parse(data['createdOn']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'title': title,
      'type': type,
      'authors': authors,
      'publisher': publisher,
      'date': date,
      'abstract': abstract,
      'pdfUrl': pdfUrl,
      'pdfFileName': pdfFileName,
      'createdOn': createdOn.toIso8601String(),
    };
  }
}
