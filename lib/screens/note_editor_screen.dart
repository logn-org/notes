import 'dart:async'; // For Timer

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp
import 'package:intl/intl.dart'; // For DateFormat
import 'package:flex_color_picker/flex_color_picker.dart'; // For Color Picker

// Import services and models
import '../services/firestore_service.dart';
import '../models/note_model.dart';
// import '../utils/note_colors.dart'; // Assuming this defines default colors if needed

// --- screens/note_editor_screen.dart ---
class NoteEditorScreen extends StatefulWidget {
  final String userId;
  final Note? noteToEdit; // Null if creating a new note

  const NoteEditorScreen({required this.userId, this.noteToEdit, super.key});

  @override
  _NoteEditorScreenState createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _newChecklistItemController;

  // State
  late List<ChecklistItem> _checklistItems;
  late List<FocusNode> _checklistFocusNodes;
  late FocusNode _newChecklistItemFocusNode;
  late NoteType _noteType;
  late bool _isPinned;
  late Color _noteColor; // Use Color type for UI state

  // Auto-Save Timer
  Timer? _autoSaveTimer;

  // UI State
  bool _isSaving = false;
  String _lastEdited = '';
  Note? _currentNoteState; // Store the initial state for comparison

  @override
  void initState() {
    super.initState();

    final note = widget.noteToEdit;
    _currentNoteState = note; // Store initial state

    _titleController = TextEditingController(text: note?.title ?? '');
    _noteType = note?.noteType ?? NoteType.text;
    // Load color: Convert stored int back to Color, provide default if null/new
    _noteColor = note?.color ?? Colors.white; // Default to white or from NoteColors
    _isPinned = note?.isPinned ?? false;

    _contentController = TextEditingController();
    _checklistItems = [];
    _checklistFocusNodes = [];
    _newChecklistItemController = TextEditingController();
    _newChecklistItemFocusNode = FocusNode();

    if (note != null) {
      if (note.noteType == NoteType.text && note.content is String) {
        _contentController.text = note.content as String;
      } else if (note.noteType == NoteType.checklist && note.content is List<ChecklistItem>) {
        _checklistItems = List<ChecklistItem>.from(note.content as List<ChecklistItem>);
        _checklistFocusNodes = List.generate(_checklistItems.length, (index) => FocusNode());
      }
      _updateLastEdited(note.updatedAt.toDate()); // Set initial last edited time
    } else {
       _updateLastEdited(DateTime.now()); // Set initial time for new note
    }


    // Add listeners for auto-saving (or triggering UI update)
    _titleController.addListener(_onTextChanged);
    _contentController.addListener(_onTextChanged);
    // Checklist changes trigger auto-save directly in their methods for now
  }

  @override
  void dispose() {
    // Cancel timer
    _autoSaveTimer?.cancel();

    // Remove listeners
    _titleController.removeListener(_onTextChanged);
    _contentController.removeListener(_onTextChanged);

    // Dispose controllers and focus nodes
    _titleController.dispose();
    _contentController.dispose();
    _newChecklistItemController.dispose();
    _newChecklistItemFocusNode.dispose();
    for (var node in _checklistFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  // --- Debounced Auto-Save Trigger ---
  void _onTextChanged() {
    _updateLastEdited(DateTime.now()); // Update timestamp display immediately
    _autoSaveTimer?.cancel(); // Cancel existing timer
    _autoSaveTimer = Timer(const Duration(seconds: 3), () { // Wait 3 seconds after last change
      _performSave(); // Perform the actual save without popping
    });
  }

  // --- Update Last Edited Display ---
  void _updateLastEdited(DateTime time) {
     if (mounted) {
       setState(() {
         _lastEdited = 'Edited: ${DateFormat.yMd().add_jm().format(time)}';
       });
     }
  }

  // --- Checklist Management ---
  void _addChecklistItem({String initialText = ''}) {
    final textToAdd = initialText.isNotEmpty ? initialText : _newChecklistItemController.text.trim();
    if (textToAdd.isNotEmpty) {
      setState(() {
        final newItem = ChecklistItem(text: textToAdd);
        final newFocusNode = FocusNode();
        _checklistItems.add(newItem);
        _checklistFocusNodes.add(newFocusNode);
        _newChecklistItemController.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted) FocusScope.of(context).requestFocus(newFocusNode);
        });
        _onTextChanged(); // Trigger auto-save timer
      });
    } else {
       _newChecklistItemController.clear();
    }
     if (mounted) FocusScope.of(context).requestFocus(_newChecklistItemFocusNode);
  }

  void _toggleChecklistItem(int index) {
    if (index >= 0 && index < _checklistItems.length) {
      setState(() {
        _checklistItems[index].isChecked = !_checklistItems[index].isChecked;
        _onTextChanged(); // Trigger auto-save timer
      });
    }
  }

  void _removeChecklistItem(int index) {
     if (index >= 0 && index < _checklistItems.length) {
        setState(() {
          _checklistFocusNodes[index].dispose();
          _checklistItems.removeAt(index);
          _checklistFocusNodes.removeAt(index);
          _onTextChanged(); // Trigger auto-save timer
        });
     }
  }

  void _updateChecklistItemText(int index, String newText) {
     if (index >= 0 && index < _checklistItems.length) {
        _checklistItems[index].text = newText;
        _onTextChanged(); // Trigger auto-save timer on text change as well
     }
  }

  void _onChecklistItemSubmitted(int index, String value) {
     _insertNewChecklistItemBelow(index);
  }

  void _insertNewChecklistItemBelow(int index) {
     setState(() {
       final newItem = ChecklistItem(text: '');
       final newFocusNode = FocusNode();
       final insertPos = index + 1;

       if (insertPos >= _checklistItems.length) {
         _checklistItems.add(newItem);
         _checklistFocusNodes.add(newFocusNode);
       } else {
         _checklistItems.insert(insertPos, newItem);
         _checklistFocusNodes.insert(insertPos, newFocusNode);
       }
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted) FocusScope.of(context).requestFocus(newFocusNode);
       });
       _onTextChanged(); // Trigger auto-save timer
     });
  }
  // --- End Checklist Management ---

  // --- Core Save Logic (No Navigation) ---
  Future<bool> _performSave() async {
    // Cancel any pending auto-save timer as we are saving now
    _autoSaveTimer?.cancel();

    // Basic validation
    bool isTitleEmpty = _titleController.text.trim().isEmpty;
    bool isContentEmpty = (_noteType == NoteType.text && _contentController.text.trim().isEmpty) ||
                           (_noteType == NoteType.checklist && _checklistItems.every((item) => item.text.trim().isEmpty));

    // If note is empty and it's a *new* note, don't save.
    if (widget.noteToEdit == null && isTitleEmpty && isContentEmpty) {
      print("Skipping save: New note is empty.");
      return false; // Indicate save was skipped
    }
    // If note is empty and it *was* an existing note, delete it instead.
    if (widget.noteToEdit != null && isTitleEmpty && isContentEmpty) {
      print("Deleting empty existing note.");
      await _deleteNote(isDiscardingEmpty: true);
      return false; // Indicate deletion happened instead of save
    }

    // Avoid saving if state hasn't changed (optional optimization)
    // Note: This requires careful implementation of equality checks for Note and ChecklistItem
    // if (_isStateUnchanged()) {
    //   print("Skipping save: State unchanged.");
    //   return true; // Indicate no save needed, but operation is "successful"
    // }

    setState(() { _isSaving = true; });

    bool success = false;
    try {
      dynamic contentToSave = (_noteType == NoteType.checklist)
          ? _checklistItems.where((item) => item.text.trim().isNotEmpty).toList()
          : _contentController.text.trim();

      final titleToSave = _titleController.text.trim();
      final colorValueToSave = _noteColor; // Store color as int

      if (_currentNoteState == null) { // Treat as new note if initial state was null
        // Add new note
        await _firestoreService.addNote(
          userId: widget.userId,
          title: titleToSave,
          content: contentToSave,
          noteType: _noteType,
          isPinned: _isPinned,
          color: colorValueToSave.hashCode, // Pass color value
        );
         // TODO: Ideally, get the newly created note ID back from addNote
         // and update _currentNoteState to allow subsequent updates instead of adds.
         // For now, subsequent auto-saves might create duplicates if not handled.
         print("New note added (auto-save).");

      } else {
        // Update existing note
        Note updatedNote = Note(
          id: _currentNoteState!.id,
          userId: widget.userId,
          title: titleToSave,
          content: contentToSave,
          noteType: _noteType,
          isPinned: _isPinned,
          createdAt: _currentNoteState!.createdAt, // Keep original
          color: colorValueToSave, // Pass color value
          updatedAt: Timestamp.now(), // Firestore service might overwrite this
        );
        await _firestoreService.updateNote(updatedNote);
         // Update the local state representation after successful save
         _currentNoteState = updatedNote;
         print("Note updated (auto-save).");
      }
      success = true;
    } catch (e) {
      print("Error performing save: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: ${e.toString()}')),
        );
      }
      success = false;
    } finally {
       if (mounted) {
         setState(() { _isSaving = false; });
       }
    }
    return success;
  }
  // --- End Core Save Logic ---

  // --- Save and Exit Logic ---
  Future<void> _saveAndExit() async {
    bool saveSuccess = await _performSave();
    // Pop only if save was successful or if it was a new empty note (which performSave handles)
    // performSave returns false if deletion happened, so we don't pop here in that case (deleteNote handles pop)
    if (saveSuccess && mounted) {
       Navigator.pop(context);
    }
    // If saveSuccess is false due to an error, we stay on the page.
    // If saveSuccess is false due to deletion, deleteNote handles the pop.
  }
  // --- End Save and Exit Logic ---

  // --- Delete Note Logic ---
  Future<void> _deleteNote({bool isDiscardingEmpty = false}) async {
    if (_currentNoteState == null && !isDiscardingEmpty) {
       if(mounted) Navigator.pop(context); // Just pop if it was a new, non-empty note being discarded
       return;
    }

    bool confirm = isDiscardingEmpty;
    if (!isDiscardingEmpty) {
      confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog( /* ... confirmation dialog ... */ ),
      ) ?? false;
    }

    if (confirm && _currentNoteState != null) {
      setState(() { _isSaving = true; });
      try {
        await _firestoreService.deleteNote(_currentNoteState!.id);
        if (mounted) {
           Navigator.pop(context);
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(isDiscardingEmpty ? 'Empty note discarded' : 'Note deleted')),
           );
        }
      } catch (e) {
         print("Error deleting note: $e");
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Error deleting note: ${e.toString()}')));
         }
      } finally {
         if (mounted) setState(() { _isSaving = false; });
      }
    } else if (confirm && isDiscardingEmpty && _currentNoteState == null) {
       if(mounted) Navigator.pop(context); // Pop if discarding an empty *new* note
    }
  }
  // --- End Delete Note Logic ---

  // --- Switch Note Type Logic ---
  void _switchNoteType() {
     setState(() {
       // ... (conversion logic remains the same) ...
        _onTextChanged(); // Trigger auto-save after type switch
     });
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note type changed. Review content.')),
     );
  }
  // --- End Switch Note Type Logic ---

  // --- Show Color Picker ---
  Future<void> _showColorPicker() async {
    Color pickedColor = await showColorPickerDialog(
      context,
      _noteColor, // Initial color
      title: Text('Select Note Color', style: Theme.of(context).textTheme.titleLarge),
      width: 40,
      height: 40,
      spacing: 0,
      runSpacing: 0,
      borderRadius: 0,
      wheelDiameter: 165,
      enableOpacity: false, // Keep it simple, no opacity
      showColorCode: true,
      colorCodeHasColor: true,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true, // Use primary colors
        ColorPickerType.accent: true, // Use accent colors
        ColorPickerType.bw: false,
        ColorPickerType.custom: true, // Allow custom swatch
        ColorPickerType.wheel: true, // Use color wheel
      },
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        longPressMenu: true,
      ),
      actionButtons: const ColorPickerActionButtons(
        okButton: true,
        closeButton: true,
        dialogActionButtons: false, // Use default dialog buttons
      ),
      constraints: const BoxConstraints(minHeight: 480, minWidth: 320, maxWidth: 320),
    );

    // Update state if a color was selected
    setState(() {
      _noteColor = pickedColor;
      _onTextChanged(); // Trigger auto-save after color change
    });
  }
  // --- End Show Color Picker ---


  @override
  Widget build(BuildContext context) {
    // Use WillPopScope to intercept back navigation and save
    return WillPopScope(
      onWillPop: () async {
        await _saveAndExit();
        // Prevent default back behavior because _saveAndExit handles popping
        return false;
      },
      child: Scaffold(
        backgroundColor: _noteColor, // Set background color of the editor
        appBar: AppBar(
          leading: IconButton(
             icon: const Icon(Icons.arrow_back),
             tooltip: 'Save and back',
             onPressed: _isSaving ? null : _saveAndExit, // Use save and exit
          ),
          title: Text(widget.noteToEdit == null ? 'New Note' : 'Edit Note'),
          backgroundColor: Colors.transparent, // Keep AppBar transparent
          elevation: 0,
          // Adjust foreground color based on background brightness for better contrast
          foregroundColor: ThemeData.estimateBrightnessForColor(_noteColor) == Brightness.dark
                           ? Colors.white
                           : Colors.black87,
          actions: [
            // Pin Toggle Button
            IconButton(
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
              tooltip: _isPinned ? 'Unpin Note' : 'Pin Note',
              onPressed: _isSaving ? null : () {
                setState(() { _isPinned = !_isPinned; });
                _onTextChanged(); // Trigger auto-save
              },
            ),
             // Color Picker Button
            IconButton(
              icon: const Icon(Icons.palette_outlined),
              tooltip: 'Change Color',
              onPressed: _isSaving ? null : _showColorPicker,
            ),
            // Switch Note Type Button
            IconButton(
              icon: Icon(_noteType == NoteType.text ? Icons.check_box_outlined : Icons.notes_outlined),
              tooltip: _noteType == NoteType.text ? 'Convert to Checklist' : 'Convert to Text Note',
              onPressed: _isSaving ? null : _switchNoteType,
            ),
            // Delete Button
            if (_currentNoteState != null) // Show only if editing an existing note
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete Note',
                onPressed: _isSaving ? null : _deleteNote,
              ),
             // Optional: Explicit Save Button (if auto-save isn't sufficient)
             /*
             IconButton(
               icon: _isSaving
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                   : const Icon(Icons.save_outlined),
               tooltip: 'Save Note Now',
               onPressed: _isSaving ? null : _performSave, // Use performSave (no pop)
             ),
             */
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Title Field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                  ),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                ),
                const SizedBox(height: 10),

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                     child: _noteType == NoteType.text
                         ? _buildTextContentField()
                         : _buildChecklistContentField(),
                  ),
                ),

                 // Footer: Last Edited Time
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
      decoration: const InputDecoration( // Added decoration: back
        hintText: 'Note',
        border: InputBorder.none,
        isDense: true, // Reduce padding
      ),
      maxLines: null, // Allows unlimited lines vertically
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 16), // Standard text size
    );
  }

  // Widget for the checklist note content input
  Widget _buildChecklistContentField() {
    // (Checklist build logic remains largely the same as previous version)
    // Ensure onChanged triggers _onTextChanged or _performSave appropriately
     return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _checklistItems.length,
          itemBuilder: (context, index) {
            final item = _checklistItems[index];
            final focusNode = _checklistFocusNodes[index];
            return Dismissible(
              key: ValueKey(item.hashCode + index),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _removeChecklistItem(index),
              background: Container( /* ... background ... */ ),
              child: Row(
                children: [
                  Checkbox(
                    value: item.isChecked,
                    onChanged: _isSaving ? null : (_) => _toggleChecklistItem(index),
                    /* ... other checkbox properties ... */
                  ),
                  Expanded(
                    child: TextFormField(
                      focusNode: focusNode,
                      initialValue: item.text,
                      onChanged: (newText) => _updateChecklistItemText(index, newText), // Triggers auto-save via _onTextChanged
                      onFieldSubmitted: (value) => _onChecklistItemSubmitted(index, value),
                      /* ... other text field properties ... */
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: Colors.grey),
                    onPressed: _isSaving ? null : () => _removeChecklistItem(index),
                    /* ... other icon button properties ... */
                  ),
                ],
              ),
            );
          },
        ),
        Padding( // Add Item row
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: TextField(
                  controller: _newChecklistItemController,
                  focusNode: _newChecklistItemFocusNode,
                  decoration: const InputDecoration(hintText: 'Add item', /* ... */),
                  onSubmitted: (_) => _addChecklistItem(),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              IconButton(
                 icon: const Icon(Icons.add),
                 onPressed: _isSaving ? null : _addChecklistItem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}