import 'package:billeasy/widgets/connectivity_banner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePage<T> {
  const FirestorePage({
    required this.items,
    required this.hasMore,
    this.cursor,
  });

  final List<T> items;
  final bool hasMore;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cursor;
}

extension QueryPageExtension on Query<Map<String, dynamic>> {
  Future<FirestorePage<T>> fetchPage<T>({
    required T Function(Map<String, dynamic> data, String docId) fromMap,
    int limit = 25,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    Query<Map<String, dynamic>> query = limit <= 0
        ? this
        : this.limit(limit + 1);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    if (ConnectivityService.instance.isOffline) {
      snapshot = await query.get(const GetOptions(source: Source.cache));
    } else {
      try {
        snapshot = await query.get().timeout(const Duration(seconds: 4));
      } catch (_) {
        snapshot = await query.get(const GetOptions(source: Source.cache));
      }
    }
    final docs = snapshot.docs;
    final hasMore = limit > 0 && docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;

    return FirestorePage<T>(
      items: pageDocs
          .map((doc) => fromMap(doc.data(), doc.id))
          .toList(growable: false),
      hasMore: hasMore,
      cursor: pageDocs.isEmpty ? startAfterDocument : pageDocs.last,
    );
  }
}
