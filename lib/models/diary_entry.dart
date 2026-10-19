class DiaryEntry {
  final String id;
  String title;
  String content;
  final DateTime dateCreated;
  DateTime dateModified;

  DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.dateCreated,
    required this.dateModified,
  });

  /// Convert to JSON format for local storage or client serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'dateCreated': dateCreated.toIso8601String(),
      'dateModified': dateModified.toIso8601String(),
    };
  }

  /// Payload for POST / PUT API requests
  Map<String, dynamic> toApiJson() {
    return {
      'title': title,
      'content': content,
    };
  }

  /// Factory constructor supporting both MongoDB backend responses and local SharedPreferences
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    // MongoDB returns '_id' and virtual 'id'. SharedPreferences uses 'id'.
    final entryId = json['id']?.toString() ?? json['_id']?.toString() ?? '';

    // Handle createdAt (MongoDB) vs dateCreated (local format)
    DateTime createdDate;
    if (json['createdAt'] != null) {
      createdDate = DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else if (json['dateCreated'] != null) {
      createdDate = DateTime.tryParse(json['dateCreated'].toString()) ?? DateTime.now();
    } else {
      createdDate = DateTime.now();
    }

    // Handle updatedAt (MongoDB) vs dateModified (local format)
    DateTime modifiedDate;
    if (json['updatedAt'] != null) {
      modifiedDate = DateTime.tryParse(json['updatedAt'].toString()) ?? createdDate;
    } else if (json['dateModified'] != null) {
      modifiedDate = DateTime.tryParse(json['dateModified'].toString()) ?? createdDate;
    } else {
      modifiedDate = createdDate;
    }

    return DiaryEntry(
      id: entryId,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      dateCreated: createdDate,
      dateModified: modifiedDate,
    );
  }
}
