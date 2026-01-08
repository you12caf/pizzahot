import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String body;
  final String payload;
  final DateTime createdAt;
  final bool isRead;

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'payload': payload,
      'timestamp': Timestamp.fromDate(createdAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  factory AppNotification.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final dynamic rawTimestamp = data['timestamp'] ?? data['createdAt'];
    final Timestamp? ts = rawTimestamp is Timestamp ? rawTimestamp : null;
    final DateTime createdAt = ts?.toDate() ?? DateTime.now();
    return AppNotification(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      payload: (data['payload'] ?? '').toString(),
      createdAt: createdAt,
      isRead: data['isRead'] == true,
    );
  }
}
