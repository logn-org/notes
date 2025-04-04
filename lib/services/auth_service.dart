import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// --- services/auth_service.dart ---
class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream to listen for authentication changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google authentication flow.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Obtain the auth details from the request.
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential for Firebase
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential.
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      notifyListeners(); // Notify listeners about auth change
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle Firebase specific errors
      print("Firebase Auth Error: ${e.message}");
      // Consider showing user-friendly messages via a snackbar or dialog
      return null;
    } catch (e) {
      // Handle other errors
      print("Google Sign-In Error: $e");
      // Consider showing user-friendly messages
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut(); // Sign out from Google
      await _auth.signOut(); // Sign out from Firebase
      notifyListeners(); // Notify listeners
    } catch (e) {
      print("Sign Out Error: $e");
      // Handle potential errors during sign out
    }
  }
}
