import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// --- models/note_model.dart ---

// Enum to represent the type of note
enum NoteType { text, checklist }

// Represents a single item in a checklist
class ChecklistItem {
  String text;
  bool isChecked;

  ChecklistItem({required this.text, this.isChecked = false});

  // Convert ChecklistItem to a Map for Firestore
  Map<String, dynamic> toJson() => {
        'text': text,
        'isChecked': isChecked,
      };

  // Create ChecklistItem from a Map from Firestore
  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
     // Provide default values if fields are missing or null
     return ChecklistItem(
        text: json['text'] as String? ?? '',
        isChecked: json['isChecked'] as bool? ?? false,
      );
  }

  // Optional: Override equality operator and hashCode if needed for comparisons
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChecklistItem &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          isChecked == other.isChecked;

  @override
  int get hashCode => text.hashCode ^ isChecked.hashCode;
}

// Represents a single note
class Note {
  final String id; // Document ID from Firestore
  final String userId; // Firebase Auth User ID
  String? title; // Optional title
  dynamic content; // String for text note, List<ChecklistItem> for checklist
  NoteType noteType;
  bool isPinned;
  Timestamp createdAt;
  Timestamp updatedAt;
  Color? color; // Add color field
  int order;

  Note({
    required this.id,
    required this.userId,
    this.title,
    required this.content,
    required this.noteType,
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
    this.color, // Default color white
    this.order = 0,
  });

  // Convert Note object to a Map for Firestore
  // Note: This is primarily used by the updateNote method in FirestoreService.
  // addNote in FirestoreService now creates the Map directly.
  Map<String, dynamic> toJson() {
    dynamic contentJson;
    if (noteType == NoteType.checklist && content is List<ChecklistItem>) {
      // Convert list of ChecklistItem objects to list of Maps
      contentJson = (content as List<ChecklistItem>).map((item) => item.toJson()).toList();
    } else {
      // Assume content is String for text notes
      contentJson = content;
    }

    return {
      'userId': userId,
      'title': title,
      'content': contentJson,
      // Store enum as string for better readability in Firestore
      'noteType': noteType.toString().split('.').last,
      'isPinned': isPinned,
      'createdAt': createdAt,
      'updatedAt': updatedAt, // This will be overwritten by FirestoreService on update
      // serverTimestamp is handled directly by FirestoreService
      'color': color, // Add color to the map
      'order': order, // Add order to the map
    };
  }

  // Create Note object from Firestore DocumentSnapshot
  factory Note.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    NoteType type = NoteType.text; // Default to text
    String noteTypeStr = data['noteType'] as String? ?? 'text';
    if (noteTypeStr == 'checklist') {
      type = NoteType.checklist;
    }

    dynamic parsedContent;
    if (type == NoteType.checklist && data['content'] is List) {
      // Parse list of Maps back into list of ChecklistItem objects
      var contentList = data['content'] as List;
      // Add error handling in case item is not a Map
      parsedContent = contentList
          .map((item) => item is Map<String, dynamic> ? ChecklistItem.fromJson(item) : ChecklistItem(text: 'Error: Invalid item data'))
          .toList();
    } else {
      // Assume String content for text notes
      parsedContent = data['content'] as String? ?? ''; // Handle potential null/missing content
    }

    return Note(
      id: doc.id,
      userId: data['userId'] as String? ?? '', // Handle potential null/missing userId
      title: data['title'] as String?, // Title is optional
      content: parsedContent,
      noteType: type,
      isPinned: data['isPinned'] as bool? ?? false, // Default to false if missing/null
      // Handle potential null Timestamps, provide default using current time
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: data['updatedAt'] as Timestamp? ?? Timestamp.now(),
      // Retrieve color as int, convert to Color, default to white
      color: (data['color'] as int?) != null
          ? Color(data['color'] as int)
          : Colors.white,
      order: data['order'] as int? ?? 0,
    );
  }
}
