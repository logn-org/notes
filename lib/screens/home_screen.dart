import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart'; // For Masonry layout

// Import services, models, screens, and widgets
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart'; // Import the NoteCard widget
import 'note_editor_screen.dart'; // Import the NoteEditorScreen

// --- screens/home_screen.dart ---
class HomeScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    // Ensure user is not null before proceeding
    if (user == null) {
      // This case should ideally be handled by AuthWrapper redirecting to LoginScreen
      print("Error: HomeScreen built with no user logged in.");
      return Scaffold(
        body: Center(
          child: Text("Authentication error. Please restart the app."),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Keep'), // App name
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow
        foregroundColor: Colors.black87, // Set icon/text color
        actions: [
          // Add Search Icon (Functionality not implemented here)
          IconButton(
            icon: Icon(Icons.search),
            tooltip: 'Search Notes',
            onPressed: () {
              // TODO: Implement search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Search not implemented yet.')),
              );
            },
          ),
          // Sign Out Button
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              // Show confirmation dialog before signing out
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Sign Out?'),
                  content: Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                 await authService.signOut();
                 // Navigation is handled by AuthWrapper
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: _firestoreService.getNotesStream(user.uid),
        builder: (context, snapshot) {
          // Handle loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          // Handle stream error state
          if (snapshot.hasError) {
            print("Firestore Stream Error: ${snapshot.error}");
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading notes. Please check your connection or restart the app.\n(${snapshot.error})',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            );
          }
          // Handle no data state (successful fetch, but no notes)
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.note_add_outlined, size: 60, color: Colors.grey.shade400),
                  SizedBox(height: 16),
                  Text(
                    'No notes yet!',
                    style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                  ),
                   SizedBox(height: 8),
                   Text(
                    'Tap the + button to add your first note.',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          // Data available, display notes
          final notes = snapshot.data!;

          // Use MasonryGridView for the Keep-like layout
          return MasonryGridView.count(
            crossAxisCount: 2, // Number of columns (adjust for screen size if needed)
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            padding: EdgeInsets.all(12.0), // Add more padding around the grid
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              // Use the dedicated NoteCard widget
              return NoteCard(note: note);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to NoteEditorScreen to add a new note
          Navigator.push(
            context,
            MaterialPageRoute(
              // Pass the necessary userId for creating a new note
              builder: (context) => NoteEditorScreen(userId: user.uid),
            ),
          );
        },
        tooltip: 'Add Note',
        child: Icon(Icons.add),
        backgroundColor: Colors.yellow.shade700, // Keep-like color
        foregroundColor: Colors.black87,
        elevation: 4.0, // Add some elevation
      ),
    );
  }
}
