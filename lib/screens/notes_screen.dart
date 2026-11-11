import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_repository.dart';
import '../data/notes_repository.dart';
import '../models/note.dart';
import 'add_note_dialog.dart';

/// Part 4: the signed-in user's notes, live from Firestore.
///
/// - AppBar title 'My Notes'; an IconButton (tooltip 'Sign out', Icons.logout)
///   that calls AuthRepository.signOut().
/// - A FloatingActionButton (tooltip 'Add note') that opens AddNoteDialog and
///   calls NotesRepository.addNote. On ArgumentError show a SnackBar 'A title is required.'
/// - Body: a StreamBuilder over _notes:
///     error                -> Text('Could not load notes.')
///     no data yet          -> CircularProgressIndicator
///     empty list           -> Text('No notes yet')
///     otherwise            -> a ListView of ListTile(title, subtitle: body), each inside a
///                             Dismissible (key: ValueKey(note.id)) that calls deleteNote.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, required this.uid});

  final String uid;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  // Created once, not in build (Week 6: a new stream on every rebuild restarts it). Given.
  late final Stream<List<Note>> _notes = context.read<NotesRepository>().watchNotes(widget.uid);

  Future<void> _add() async {
    final notesRepo = context.read<NotesRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const AddNoteDialog(),
    );
    if (result != null) {
      try {
        await notesRepo.addNote(widget.uid, result.$1, result.$2);
      } on ArgumentError {
        messenger.showSnackBar(
          const SnackBar(content: Text('A title is required.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Notes'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthRepository>().signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add note',
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Note>>(
        stream: _notes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load notes.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notes = snapshot.data!;
          if (notes.isEmpty) {
            return const Center(child: Text('No notes yet'));
          }
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return Dismissible(
                key: ValueKey(note.id),
                onDismissed: (_) {
                  context.read<NotesRepository>().deleteNote(widget.uid, note.id);
                },
                child: ListTile(
                  title: Text(note.title),
                  subtitle: note.body.isNotEmpty ? Text(note.body) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
