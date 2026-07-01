import 'package:cloud_firestore/cloud_firestore.dart';

class UseFirebase<T> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final T Function(Map<String, dynamic> data, String documentId) fromJson;

  final Map<String, dynamic> Function(T model) toJson;

  UseFirebase({required this.fromJson, required this.toJson});

  Future<void> add(String collection, T model) async {
    await _firestore.collection(collection).add(toJson(model));
  }

  Future<void> addWithUid(String collection, String uid, T model) async {
    await _firestore.collection(collection).doc(uid).set(toJson(model));
  }

  Future<List<T>> getAll(String collection) async {
    final snap = await _firestore.collection(collection).get();
    return snap.docs.map((doc) => fromJson(doc.data(), doc.id)).toList();
  }

  Future<T?> getById(String collection, String docId) async {
    final doc = await _firestore.collection(collection).doc(docId).get();
    if (!doc.exists) return null;
    return fromJson(doc.data()!, doc.id);
  }

  Future<void> update(String collection, String docId, T model) async {
    await _firestore.collection(collection).doc(docId).update(toJson(model));
  }

  Future<void> delete(String collection, String docId) async {
    await _firestore.collection(collection).doc(docId).delete();
  }

  Stream<List<T>> streamAll(String collection) {
    return _firestore.collection(collection).snapshots().map((snap) =>
        snap.docs.map((doc) => fromJson(doc.data(), doc.id)).toList());
  }

  /// Streams documents from [collection] after applying a server-side query
  /// (e.g. a `where` filter), so callers don't have to pull the whole
  /// collection and filter client-side.
  Stream<List<T>> streamWhere(
    String collection,
    Query<Map<String, dynamic>> Function(
            CollectionReference<Map<String, dynamic>> ref)
        buildQuery,
  ) {
    return buildQuery(_firestore.collection(collection)).snapshots().map(
        (snap) =>
            snap.docs.map((doc) => fromJson(doc.data(), doc.id)).toList());
  }
}

extension UseFirebaseSubcollection<T> on UseFirebase<T> {
  Future<void> addToSubcollection(
    String parentCollection,
    String parentId,
    String subcollection,
    String docId,
    T model,
  ) async {
    await FirebaseFirestore.instance
        .collection(parentCollection)
        .doc(parentId)
        .collection(subcollection)
        .doc(docId)
        .set(toJson(model));
  }

  Future<void> deleteFromSubcollection(
    String parentCollection,
    String parentId,
    String subcollection,
    String docId,
  ) async {
    await FirebaseFirestore.instance
        .collection(parentCollection)
        .doc(parentId)
        .collection(subcollection)
        .doc(docId)
        .delete();
  }

  Future<List<T>> getSubcollection(
    String parentCollection,
    String parentId,
    String subcollection,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection(parentCollection)
        .doc(parentId)
        .collection(subcollection)
        .get();

    return snap.docs.map((doc) => fromJson(doc.data(), doc.id)).toList();
  }
}
