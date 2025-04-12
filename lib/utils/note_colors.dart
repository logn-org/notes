import 'package:flutter/material.dart';
import 'dart:math';

class NoteColors {
  static const List<Color> noteColors = [
    Color(0xFFFFFDE7), // Light Yellow
    Color(0xFFE8F5E9), // Light Green
    Color(0xFFE3F2FD), // Light Blue
    Color(0xFFFCE4EC), // Light Pink
    Color(0xFFF1F8E9), // Light Lime
    Color(0xFFF3E5F5), // Light Purple
    Color(0xFFE0F7FA), // Light Cyan
    Color(0xFFFFF8E1), // Light Amber
    Color(0xFFFBE9E7), // Light Orange
    Color(0xFFEDE7F6), // Light Indigo
  ];

  static const Color defaultNoteColor = Color(0xFFFFFDE7);
  static Color getRandomColor() {
    final random = Random();
    int index;
    do {
      index = random.nextInt(noteColors.length);
    } while (noteColors[index] == Colors.white || noteColors[index] == Colors.black);
    return noteColors[index];
  }
}