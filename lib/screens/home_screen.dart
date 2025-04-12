import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/theme_notifier.dart'; // Import ThemeNotifier
// Import services, models, screens, and widgets
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/note_model.dart';
import '../widgets/note_card.dart'; // Import the NoteCard widget
// Import the NoteEditorScreen
import 'note_editor_screen.dart';

// --- screens/home_screen.dart ---
class HomeScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();

  HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    // Ensure user is not null before proceeding
    if (user == null) {
      // This case should ideally be handled by AuthWrapper redirecting to LoginScreen
      print("Error: HomeScreen built with no user logged in.");
      return const Scaffold(
        body: Center(
          child: Text("Authentication error. Please restart the app."),
        ),
      );
    }

    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logn Notes'), // App name
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        foregroundColor: Colors.black87, // Set icon/text color
        actions: [
          // Add Search Icon (Functionality not implemented here)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search Notes',
            onPressed: () {
              // TODO: Implement search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Search not implemented yet.')),
              );
            },
          ),
          // Sign Out Button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              // Show confirmation dialog before signing out
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: const Text('Sign Out?'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(color: Colors.red),
                          ),
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
          IconButton(
            icon: Icon(
              themeNotifier.themeMode == ThemeMode.light
                  ? Icons.light_mode
                  : Icons.dark_mode,
            ),
            onPressed: () {
              themeNotifier.toggleTheme();
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Note>>(
        stream: _firestoreService.getNotesStream(user.uid),
        builder: (context, snapshot) {
          // Handle loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
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
                  Icon(
                    Icons.note_add_outlined,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notes yet!',
                    style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
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
          return ReorderableListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: notes.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) {
                newIndex -= 1;
              }
              final Note item = notes.removeAt(oldIndex);
              notes.insert(newIndex, item);
            },
            itemBuilder: (context, index) {
              final note = notes[index];
              return NoteCard(
                key: ValueKey<String>(notes[index].id),
                note: note,
              );
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
        backgroundColor: Colors.yellow.shade700, // Keep-like color
        foregroundColor: Colors.black87,
        elevation: 4.0,
        child: const Icon(Icons.add), // Add some elevation
      ),
      // Suggested code may be subject to a license. Learn more: ~LicenseLog:1309068226.
    );
  }
}
