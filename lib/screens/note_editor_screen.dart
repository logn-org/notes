import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp
import 'package:intl/intl.dart'; // For formatting last edited time

// Import services and models
import '../services/firestore_service.dart';
import '../models/note_model.dart';

// --- screens/note_editor_screen.dart ---
class NoteEditorScreen extends StatefulWidget {
  final String userId;
  final Note? noteToEdit; // Null if creating a new note

  NoteEditorScreen({required this.userId, this.noteToEdit, Key? key}) : super(key: key); // Add Key

  @override
  _NoteEditorScreenState createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>(); // For potential validation

  // Controllers for text fields
  late TextEditingController _titleController;
  late TextEditingController _contentController; // For text notes
  late TextEditingController _newChecklistItemController; // For adding checklist items

  // State for checklist items (using FocusNode for better UX)
  late List<ChecklistItem> _checklistItems;
  late List<FocusNode> _checklistFocusNodes; // Manage focus for checklist items
  late FocusNode _newChecklistItemFocusNode; // Focus for the "Add item" field

  // State for note type and pinning
  late NoteType _noteType;
  late bool _isPinned;

  // State for UI feedback
  bool _isSaving = false; // To show loading indicator on save/delete
  String _lastEdited = ''; // To display last edited time

  @override
  void initState() {
    super.initState();

    // Initialize state based on whether editing or creating
    final note = widget.noteToEdit;
    _titleController = TextEditingController(text: note?.title ?? '');
    _noteType = note?.noteType ?? NoteType.text; // Default to text for new notes
    _isPinned = note?.isPinned ?? false; // Default to false for new notes

    _contentController = TextEditingController();
    _checklistItems = [];
    _checklistFocusNodes = [];
    _newChecklistItemController = TextEditingController();
    _newChecklistItemFocusNode = FocusNode();

    if (note != null) {
      // Populate content based on existing note type
      if (note.noteType == NoteType.text && note.content is String) {
        _contentController.text = note.content as String;
      } else if (note.noteType == NoteType.checklist && note.content is List<ChecklistItem>) {
        // Important: Create a *new* list and corresponding FocusNodes
        _checklistItems = List<ChecklistItem>.from(note.content as List<ChecklistItem>);
        _checklistFocusNodes = List.generate(_checklistItems.length, (index) => FocusNode());
      }
      // Set initial last edited time
      _lastEdited = 'Edited: ${DateFormat.yMd().add_jm().format(note.updatedAt.toDate())}';
    }

    // Add listeners to update last edited time on change (optional)
    _titleController.addListener(_updateLastEdited);
    _contentController.addListener(_updateLastEdited);
    // More complex listener setup needed for checklist items if real-time update is desired
  }

  // Method to update the "Last Edited" timestamp display (debounced if needed)
  void _updateLastEdited() {
    // Basic update, could be debounced for performance if called frequently
    if (mounted) {
      setState(() {
        _lastEdited = 'Edited: ${DateFormat.yMd().add_jm().format(DateTime.now())}';
      });
    }
  }


  @override
  void dispose() {
    // Dispose all controllers and focus nodes to free resources
    _titleController.dispose();
    _contentController.dispose();
    _newChecklistItemController.dispose();
    _newChecklistItemFocusNode.dispose();
    for (var node in _checklistFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // --- Methods for Checklist Management ---
  void _addChecklistItem({String initialText = ''}) {
    final textToAdd = initialText.isNotEmpty ? initialText : _newChecklistItemController.text.trim();
    if (textToAdd.isNotEmpty) {
      setState(() {
        final newItem = ChecklistItem(text: textToAdd);
        final newFocusNode = FocusNode();
        _checklistItems.add(newItem);
        _checklistFocusNodes.add(newFocusNode);
        _newChecklistItemController.clear();
        // Request focus for the newly added item for easy chaining
        WidgetsBinding.instance.addPostFrameCallback((_) {
           FocusScope.of(context).requestFocus(newFocusNode);
        });
         _updateLastEdited(); // Update edited time
      });
    } else {
       // If adding via enter key from "Add item" field, just clear it
       _newChecklistItemController.clear();
    }
     // Keep focus on the "Add item" field after adding
     FocusScope.of(context).requestFocus(_newChecklistItemFocusNode);
  }

  void _toggleChecklistItem(int index) {
    if (index >= 0 && index < _checklistItems.length) {
      setState(() {
        _checklistItems[index].isChecked = !_checklistItems[index].isChecked;
         _updateLastEdited(); // Update edited time
      });
    }
  }

  void _removeChecklistItem(int index) {
     if (index >= 0 && index < _checklistItems.length) {
        setState(() {
          // Dispose the focus node before removing the item
          _checklistFocusNodes[index].dispose();
          _checklistItems.removeAt(index);
          _checklistFocusNodes.removeAt(index);
           _updateLastEdited(); // Update edited time
        });
     }
  }

  void _updateChecklistItemText(int index, String newText) {
     if (index >= 0 && index < _checklistItems.length) {
        // No setState needed here as we are modifying the object directly
        _checklistItems[index].text = newText;
        // _updateLastEdited(); // Optionally update time on text change
     }
  }

  // Handle Enter key press in checklist item text field
  void _onChecklistItemSubmitted(int index, String value) {
     // Insert a new item below the current one
     _insertNewChecklistItemBelow(index);
  }

  // Insert a new checklist item below the specified index and focus it
  void _insertNewChecklistItemBelow(int index) {
     setState(() {
       final newItem = ChecklistItem(text: ''); // Start with empty text
       final newFocusNode = FocusNode();

       if (index + 1 >= _checklistItems.length) {
         // Add to the end
         _checklistItems.add(newItem);
         _checklistFocusNodes.add(newFocusNode);
       } else {
         // Insert in the middle
         _checklistItems.insert(index + 1, newItem);
         _checklistFocusNodes.insert(index + 1, newFocusNode);
       }

       // Request focus for the newly added item
       WidgetsBinding.instance.addPostFrameCallback((_) {
         FocusScope.of(context).requestFocus(newFocusNode);
       });
        _updateLastEdited(); // Update edited time
     });
  }
  // --- End Checklist Management ---


  // --- Save Note Logic ---
  Future<void> _saveNote() async {
    // Basic validation: Check if the note is effectively empty
    bool isTitleEmpty = _titleController.text.trim().isEmpty;
    bool isContentEmpty = (_noteType == NoteType.text && _contentController.text.trim().isEmpty) ||
                           (_noteType == NoteType.checklist && _checklistItems.every((item) => item.text.trim().isEmpty));

    if (isTitleEmpty && isContentEmpty) {
      // Don't save completely empty notes (like Google Keep)
      // If it was an existing note, delete it instead of saving empty.
      if (widget.noteToEdit != null) {
         await _deleteNote(isDiscardingEmpty: true); // Pass flag to avoid confirmation
      } else {
        // If it's a new note, just pop without saving and show message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Empty note discarded.')),
        );
        Navigator.pop(context);
      }
      return; // Exit save process
    }

    // Show loading indicator
    setState(() { _isSaving = true; });

    try {
      dynamic contentToSave;
      if (_noteType == NoteType.checklist) {
        // Filter out any checklist items with only whitespace before saving
        contentToSave = _checklistItems.where((item) => item.text.trim().isNotEmpty).toList();
      } else {
        contentToSave = _contentController.text.trim(); // Trim whitespace for text notes
      }

      // Use appropriate Firestore service method
      if (widget.noteToEdit == null) {
        // Add new note
        await _firestoreService.addNote(
          userId: widget.userId,
          title: _titleController.text.trim(),
          content: contentToSave,
          noteType: _noteType,
          isPinned: _isPinned,
        );
      } else {
        // Update existing note
        // Create a new Note object with updated values to pass to the service
        Note updatedNote = Note(
          id: widget.noteToEdit!.id,
          userId: widget.userId, // Should match noteToEdit's userId
          title: _titleController.text.trim(),
          content: contentToSave,
          noteType: _noteType,
          isPinned: _isPinned,
          createdAt: widget.noteToEdit!.createdAt, // Preserve original creation time
          updatedAt: Timestamp.now(), // Service will update this again, but good practice
        );
        await _firestoreService.updateNote(updatedNote);
      }
      // Go back only if save was successful and widget is still mounted
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error saving note: $e");
      // Show error message if saving failed and widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: ${e.toString()}')),
        );
      }
    } finally {
       // Hide loading indicator if widget is still mounted
       if (mounted) {
         setState(() { _isSaving = false; });
       }
    }
  }
  // --- End Save Note Logic ---

  // --- Delete Note Logic ---
  Future<void> _deleteNote({bool isDiscardingEmpty = false}) async {
    // Only proceed if it's an existing note
    if (widget.noteToEdit == null && !isDiscardingEmpty) {
       // If it's a new note being discarded (not empty), just pop
       Navigator.pop(context);
       return;
    }

    bool confirm = isDiscardingEmpty; // Skip confirmation if discarding empty note

    if (!isDiscardingEmpty) {
      // Show confirmation dialog for regular delete
      confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Note?'),
          content: Text('Are you sure you want to delete this note permanently?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Confirm
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ) ?? false; // Default to false if dialog is dismissed
    }

    // Proceed with deletion if confirmed or discarding empty
    if (confirm && widget.noteToEdit != null) {
      setState(() { _isSaving = true; }); // Show loading indicator
      try {
        await _firestoreService.deleteNote(widget.noteToEdit!.id);
        // Pop twice if discarding empty (once for dialog, once for editor)
        // Otherwise pop once
        if (mounted) {
           Navigator.pop(context); // Pop editor screen
           // Show confirmation snackbar
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(isDiscardingEmpty ? 'Empty note discarded' : 'Note deleted')),
           );
        }
      } catch (e) {
         print("Error deleting note: $e");
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error deleting note: ${e.toString()}')),
           );
         }
      } finally {
         if (mounted) {
           setState(() { _isSaving = false; });
         }
      }
    } else if (confirm && isDiscardingEmpty && widget.noteToEdit == null) {
       // This case is handled in _saveNote, but added for completeness
       if(mounted) Navigator.pop(context);
    }
  }
  // --- End Delete Note Logic ---

  // --- Switch Note Type Logic ---
  void _switchNoteType() {
     setState(() {
       final previousType = _noteType;
       _noteType = (_noteType == NoteType.text) ? NoteType.checklist : NoteType.text;
       _updateLastEdited(); // Update edited time

       // Attempt content conversion (basic)
       if (_noteType == NoteType.checklist && previousType == NoteType.text) {
         // Convert text (split by lines) to checklist items
         final lines = _contentController.text.split('\n').where((line) => line.trim().isNotEmpty);
         _checklistItems = lines.map((line) => ChecklistItem(text: line.trim())).toList();
         _checklistFocusNodes = List.generate(_checklistItems.length, (index) => FocusNode());
         _contentController.clear(); // Clear text field
       } else if (_noteType == NoteType.text && previousType == NoteType.checklist) {
         // Convert checklist items (non-empty) to text lines
         _contentController.text = _checklistItems
             .where((item) => item.text.trim().isNotEmpty)
             .map((item) => item.text)
             .join('\n');
         // Dispose old focus nodes and clear checklist
         for (var node in _checklistFocusNodes) { node.dispose(); }
         _checklistItems.clear();
         _checklistFocusNodes.clear();
       }
       // If switching to checklist and it's empty, ensure focus nodes list is also empty
       if (_noteType == NoteType.checklist && _checklistItems.isEmpty) {
          _checklistFocusNodes.clear();
       }
     });
      // Show a snackbar about potential data loss/change
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note type changed. Review content.')),
     );
  }
  // --- End Switch Note Type Logic ---


  @override
  Widget build(BuildContext context) {
    // Use WillPopScope to handle back button press (save or discard)
    return WillPopScope(
      onWillPop: () async {
        // Trigger save logic when back button is pressed
        await _saveNote();
        // Return true to allow popping, false to prevent it (saveNote handles navigation)
        // Since saveNote pops on success/discard, return false to avoid double pop.
        // If saveNote fails, it stays, so returning false is correct.
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          // Use custom back button to trigger save logic
          leading: IconButton(
             icon: Icon(Icons.arrow_back),
             tooltip: 'Save and back',
             onPressed: _isSaving ? null : _saveNote,
          ),
          title: Text(widget.noteToEdit == null ? 'New Note' : 'Edit Note'),
          backgroundColor: Colors.transparent, // Cleaner look
          elevation: 0,
          foregroundColor: Colors.black87,
          actions: [
            // Pin Toggle Button
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              tooltip: _isPinned ? 'Unpin Note' : 'Pin Note',
              onPressed: _isSaving ? null : () {
                setState(() { _isPinned = !_isPinned; });
                 _updateLastEdited();
              },
            ),
            // Switch Note Type Button
            IconButton(
              icon: Icon(_noteType == NoteType.text ? Icons.check_box_outlined : Icons.notes_outlined),
              tooltip: _noteType == NoteType.text ? 'Convert to Checklist' : 'Convert to Text Note',
              onPressed: _isSaving ? null : _switchNoteType,
            ),
            // Delete Button (only for existing notes)
            if (widget.noteToEdit != null)
              IconButton(
                icon: Icon(Icons.delete_outline),
                tooltip: 'Delete Note',
                onPressed: _isSaving ? null : _deleteNote,
              ),
            // Save Button (explicit save, though back button also saves)
            IconButton(
              icon: _isSaving
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black54))
                  : Icon(Icons.save_outlined),
              tooltip: 'Save Note',
              onPressed: _isSaving ? null : _saveNote,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Adjust top padding
          child: Form(
            key: _formKey,
            child: Column( // Use Column instead of ListView for simpler layout here
              children: [
                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                  ),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null, // Allow title to wrap if needed
                ),
                SizedBox(height: 10),

                // Content Area (takes remaining space)
                Expanded(
                  child: SingleChildScrollView( // Make content area scrollable
                     child: _noteType == NoteType.text
                         ? _buildTextContentField()
                         : _buildChecklistContentField(),
                  ),
                ),

                 // Footer for "Last Edited" time
                 Padding(
                   padding: const EdgeInsets.only(top: 8.0),
                   child: Text(
                     _lastEdited,
                     style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                   ),
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget for the text note content input
  Widget _buildTextContentField() {
    return TextFormField(
      controller: _contentController,
      decoration: InputDecoration(
        hintText: 'Note',
        border: InputBorder.none,
        isDense: true, // Reduce padding
      ),
      maxLines: null, // Allows unlimited lines vertically
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 16), // Standard text size
    );
  }

  // Widget for the checklist note content input
  Widget _buildChecklistContentField() {
    return Column(
      mainAxisSize: MainAxisSize.min, // Take minimum space needed
      children: [
        // --- List of existing checklist items ---
        // Use ListView.builder for potentially long lists (though less likely here)
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(), // Disable inner scrolling
          itemCount: _checklistItems.length,
          itemBuilder: (context, index) {
            final item = _checklistItems[index];
            final focusNode = _checklistFocusNodes[index];
            // Use a Dismissible for swipe-to-delete functionality
            return Dismissible(
              key: ValueKey(item.hashCode + index), // Unique key per item build
              direction: DismissDirection.endToStart, // Swipe left to delete
              onDismissed: (_) => _removeChecklistItem(index),
              background: Container(
                color: Colors.red.shade300, // Softer red
                alignment: Alignment.centerRight,
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Icon(Icons.delete_outline, color: Colors.white),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center, // Center items vertically
                children: [
                  // Checkbox
                  Checkbox(
                    value: item.isChecked,
                    onChanged: _isSaving ? null : (_) => _toggleChecklistItem(index),
                    visualDensity: VisualDensity.compact, // Make checkbox smaller
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                  // Text Input Field
                  Expanded(
                    child: TextFormField(
                      focusNode: focusNode,
                      initialValue: item.text, // Use initialValue with TextFormField
                      // Update model ONLY when editing is complete or focus changes
                      // Using onChanged can be inefficient if not debounced.
                      // onEditingComplete / onFieldSubmitted are better here.
                      onChanged: (newText) => _updateChecklistItemText(index, newText),
                       onFieldSubmitted: (value) => _onChecklistItemSubmitted(index, value),
                      style: TextStyle(
                        fontSize: 15, // Slightly smaller checklist text
                        decoration: item.isChecked ? TextDecoration.lineThrough : null,
                        color: item.isChecked ? Colors.grey.shade600 : null,
                        decorationColor: Colors.grey.shade600,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 0), // Remove extra padding
                        isDense: true,
                      ),
                       textCapitalization: TextCapitalization.sentences,
                       // Move focus to next item or add new on Enter/Done
                       textInputAction: TextInputAction.next, // Or TextInputAction.done if last item
                    ),
                  ),
                  // Remove Button (alternative/supplement to swipe)
                  IconButton(
                    icon: Icon(Icons.clear, size: 20, color: Colors.grey.shade400),
                    tooltip: 'Remove item',
                    onPressed: _isSaving ? null : () => _removeChecklistItem(index),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(), // Remove extra padding around icon
                  ),
                ],
              ),
            );
          },
        ),

        // --- Input field to add a new checklist item ---
        Padding(
          padding: const EdgeInsets.only(top: 4.0), // Add space before add item row
          child: Row(
            children: [
              SizedBox(width: 48), // Align with checkbox space (approx)
              Expanded(
                child: TextField(
                  controller: _newChecklistItemController,
                  focusNode: _newChecklistItemFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Add item',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addChecklistItem(), // Add item on keyboard submit
                   textCapitalization: TextCapitalization.sentences,
                ),
              ),
              // Add button is implicit via keyboard submit, but can add one if desired
              // IconButton(
              //   icon: Icon(Icons.add),
              //   onPressed: _addChecklistItem,
              // ),
            ],
          ),
        ),
      ],
    );
  }
}
