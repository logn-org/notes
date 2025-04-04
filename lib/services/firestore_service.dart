import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_model.dart'; // Import the Note model

// --- services/firestore_service.dart ---
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collectionPath = 'notes'; // Define collection path

  // Get a stream of notes for a specific user
  Stream<List<Note>> getNotesStream(String userId) {
    return _db
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        // Order by pinned status first, then by last updated time
        .orderBy('isPinned', descending: true)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => Note.fromFirestore(doc)).toList(),
        )
        .handleError((error) {
          // Basic error handling for the stream
          print("Error fetching notes stream: $error");
          // Potentially return an empty list or rethrow a custom error
          return <Note>[];
        });
  }

  // Add a new note
  Future<void> addNote({
    required String userId,
    String? title,
    required dynamic content, // String or List<ChecklistItem>
    required NoteType noteType,
    bool isPinned = false,
  }) {
    Timestamp now = Timestamp.now();
    // Create a Map directly for Firestore, using the Note model's logic
    Map<String, dynamic> noteData = {
      'userId': userId,
      'title': title,
      'content':
          (noteType == NoteType.checklist && content is List<ChecklistItem>)
              ? content.map((item) => item.toJson()).toList()
              : content,
      'noteType': noteType.toString().split('.').last,
      'isPinned': isPinned,
      'createdAt': now,
      'updatedAt': now,
      'serverTimestamp': FieldValue.serverTimestamp(), // Use server timestamp
    };

    return _db.collection(_collectionPath).add(noteData);
  }

  // Update an existing note (using the Note object)
  Future<void> updateNote(Note note) {
    // Create a Map from the Note object, ensuring updatedAt is current
    Map<String, dynamic> noteData = note.toJson();
    noteData['updatedAt'] = Timestamp.now(); // Ensure updatedAt is fresh
    noteData['serverTimestamp'] =
        FieldValue.serverTimestamp(); // Update server timestamp

    return _db.collection(_collectionPath).doc(note.id).update(noteData);
  }

  // Update only specific fields (like pinning or checklist item state)
  Future<void> updateNoteField(String noteId, Map<String, dynamic> data) {
    // Ensure 'updatedAt' and server timestamp are always updated on any change
    data['updatedAt'] = Timestamp.now();
    data['serverTimestamp'] = FieldValue.serverTimestamp();
    return _db.collection(_collectionPath).doc(noteId).update(data);
  }

  // Delete a note
  Future<void> deleteNote(String noteId) {
    return _db.collection(_collectionPath).doc(noteId).delete();
  }
}
