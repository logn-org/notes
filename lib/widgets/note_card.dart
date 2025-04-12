import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:provider/provider.dart'; // To access services if needed

// Import models, services, and screens
import '../models/note_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart'; // To get user ID for navigation
import '../screens/note_editor_screen.dart'; // To navigate to editor
import '../utils/note_colors.dart';

// --- widgets/note_card.dart ---
class NoteCard extends StatelessWidget {
  final Note note;
  final int index;
  final FirestoreService _firestoreService = FirestoreService(); // Instance for pinning

  // Initialize index
  NoteCard({required this.note, this.index = 0, super.key}); // Add Key

  @override
  Widget build(BuildContext context) {
    // Get user ID safely - needed for navigating to the editor
    final authService = Provider.of<AuthService>(context, listen: false);
    final String? currentUserId = authService.currentUser?.uid;

    // Determine card background color
    final Color? noteColor = note.color;
    final Color cardColor = noteColor ?? NoteColors.getRandomColor();

    return GestureDetector(
      onTap: () {
        // Ensure user ID is available before navigating
        if (currentUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(
                userId: currentUserId, // Pass the non-null user ID
                noteToEdit: note, // Pass the note to be edited
              ),
            ),
          );
        } else {
          // Handle case where user ID is somehow null (should not happen with AuthWrapper)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Could not identify user.')),
          );
          print("Error: User ID is null when trying to edit note.");
        }
      },
      child: Card(
        elevation: 2.0,
        color: cardColor, // Use determined card color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // Slightly more rounded
          // Add a subtle border (optional)
          // side: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Ensure card takes minimum vertical space
            children: [
              // --- Pin Icon and Title Row ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (takes available space)
                  Expanded(
                    child: (note.title != null && note.title!.isNotEmpty)
                        ? Padding(
                            // Add padding if title exists
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              note.title!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600, // Medium bold
                                color: Theme.of(context).textTheme.titleMedium?.color,
                              ),
                              maxLines: 3, // Allow slightly more lines for title
                              overflow: TextOverflow.ellipsis,
                            ),
                          )
                        : const SizedBox.shrink(), // No title, don't take space
                  ),
                  // Pin Toggle Button (always visible)
                  Material( // Wrap InkWell with Material for correct visual feedback
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        // Toggle pin status using FirestoreService
                        _firestoreService.updateNoteField(
                            note.id, {'isPinned': !note.isPinned});
                         // Optional: Provide haptic feedback
                         // HapticFeedback.mediumImpact();
                      },
                      borderRadius: BorderRadius.circular(20), // Circular ripple effect
                      child: Padding(
                        padding: const EdgeInsets.all(5.0), // Padding inside ripple area
                        child: Icon(
                          note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 22, // Slightly larger icon
                          color: note.isPinned
                              ? Theme.of(context).colorScheme.primary // Use theme color for pinned
                              : Colors.grey.shade600, // Grey for unpinned
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Add space only if title exists
              if (note.title != null && note.title!.isNotEmpty) const SizedBox(height: 8),

              // --- Note Content (Text or Checklist) ---
              // Add some vertical spacing before content
              if (note.title != null && note.title!.isNotEmpty) const SizedBox.shrink() else const SizedBox(height: 4),
              Flexible( // Allow content to take available space within card constraints
                 child: _buildContent(context),
              ),


              // --- Footer: Last Updated Date ---
              const SizedBox(height: 10), // Space before footer
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  // Format timestamp using intl package
                  'Edited: ${DateFormat.yMd().add_jm().format(note.updatedAt.toDate())}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper to build content based on note type
  Widget _buildContent(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bodyColor = textTheme.bodyMedium?.color ?? Colors.black87;
    final subduedColor = Colors.grey.shade600;

    // --- Checklist Content ---
    if (note.noteType == NoteType.checklist && note.content is List<ChecklistItem>) {
      List<ChecklistItem> items = note.content as List<ChecklistItem>;
      if (items.isEmpty) {
        // Handle empty checklist case gracefully
        return Text(
          '[Empty checklist]',
          style: TextStyle(fontSize: 14, color: subduedColor, fontStyle: FontStyle.italic),
        );
      }
      int itemsToShow = 6; // Limit items shown in card preview

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Take minimum space
        children: [
          // Generate list tiles for checklist items
          ...items.take(itemsToShow).map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0), // Adjust spacing
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Align text nicely if it wraps
                children: [
                  // Use Icon for checkbox display (non-interactive in card)
                  Icon(
                    item.isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 18,
                    color: item.isChecked ? subduedColor : bodyColor,
                  ),
                  const SizedBox(width: 8),
                  // Use Expanded to allow text wrapping
                  Expanded(
                    child: Text(
                      item.text,
                      style: TextStyle(
                        fontSize: 14,
                        decoration: item.isChecked ? TextDecoration.lineThrough : null,
                        color: item.isChecked ? subduedColor : bodyColor,
                        decorationColor: subduedColor, // Ensure strikethrough is visible
                      ),
                      maxLines: 2, // Limit lines per item in preview
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
          // Show ellipsis (...) if more items exist
          if (items.length > itemsToShow)
            Padding(
              padding: const EdgeInsets.only(left: 26.0, top: 4.0), // Align with text
              child: Text(
                '...',
                style: TextStyle(fontSize: 14, color: subduedColor),
              ),
            ),
        ],
      );
    }
    // --- Text Content ---
    else if (note.noteType == NoteType.text && note.content is String) {
      String textContent = note.content as String;
      if (textContent.trim().isEmpty) {
         // Handle empty text note case
         return Text(
           '[Empty note]',
           style: TextStyle(fontSize: 14, color: subduedColor, fontStyle: FontStyle.italic),
         );
      }
      return Text(
        textContent,
        style: TextStyle(fontSize: 14, color: bodyColor),
        maxLines: 10, // Limit lines shown in card preview
        overflow: TextOverflow.ellipsis,
      );
    }
    // --- Fallback for Invalid Content ---
    else {
      print("Warning: NoteCard encountered invalid note content type or format for note ID ${note.id}");
      return Text(
        '[Invalid note content]',
        style: TextStyle(fontSize: 14, color: Colors.red.shade700, fontStyle: FontStyle.italic),
      );
    }
  }
}
