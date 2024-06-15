import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NotesScreen(),
    );
  }
}

class NotesScreen extends StatefulWidget {
  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  late Future<ModelNotes> futureNotes;

  @override
  void initState() {
    super.initState();
    futureNotes = fetchNotes();
  }

  Future<ModelNotes> fetchNotes() async {
    final response = await http.get(Uri.parse('http://192.168.120.97/latihan_notes/getNotes.php'));

    if (response.statusCode == 200) {
      return modelNotesFromJson(response.body);
    } else {
      throw Exception('Failed to load notes');
    }
  }

  Future<void> addOrUpdateNote({required Datum note}) async {
    String url = note.id.isEmpty
        ? 'http://192.168.120.97/latihan_notes/addNotes.php'
        : 'http://192.168.120.97/latihan_notes/updateNotes.php';

    final response = await http.post(
      Uri.parse(url),
      body: {
        if (note.id.isNotEmpty) 'id': note.id,
        'judul_note': note.judulNote,
        'isi_note': note.isiNote,
      },
    );

    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);
      if (jsonResponse['value'] == 1) {
        // Update futureNotes to trigger FutureBuilder to rebuild
        setState(() {
          futureNotes = fetchNotes();
        });
        Fluttertoast.showToast(msg: note.id.isEmpty ? 'Note added' : 'Note updated');
      } else {
        Fluttertoast.showToast(msg: jsonResponse['message']);
      }
    } else {
      Fluttertoast.showToast(msg: 'Failed to save note');
    }
  }


  Future<void> deleteNote(String id) async {
    final response = await http.post(
      Uri.parse('http://192.168.120.97/latihan_notes/deleteNotes.php'),
      body: {'id': id},
    );

    if (response.statusCode == 200) {
      // Update futureNotes to trigger FutureBuilder to rebuild
      setState(() {
        futureNotes = fetchNotes();
      });
      Fluttertoast.showToast(msg: 'Note deleted');
    } else {
      Fluttertoast.showToast(msg: 'Failed to delete note');
    }
  }


  void showNoteDetail(Datum note) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(note.judulNote),
          content: Text(note.isiNote),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showNoteDialog(BuildContext context, {Datum? note}) {
    final _formKey = GlobalKey<FormState>();
    final TextEditingController titleController =
    TextEditingController(text: note?.judulNote ?? '');
    final TextEditingController contentController =
    TextEditingController(text: note?.isiNote ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(note == null ? 'Add Note' : 'Edit Note'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: contentController,
                  decoration: InputDecoration(labelText: 'Content'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter content';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(note == null ? 'Add' : 'Update'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  Navigator.of(context).pop();
                  String idToUpdate = note?.id ?? ''; // Ensure idToUpdate is initialized
                  addOrUpdateNote(
                    note: Datum(
                      id: idToUpdate,
                      judulNote: titleController.text,
                      isiNote: contentController.text,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notes'),
      ),
      body: FutureBuilder<ModelNotes>(
        future: futureNotes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Failed to load notes'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.data.length,
              itemBuilder: (context, index) {
                return NoteCard(
                  note: snapshot.data!.data[index],
                  onDelete: () => deleteNote(snapshot.data!.data[index].id),
                  onEdit: () => _showNoteDialog(context, note: snapshot.data!.data[index]),
                  onView: () => showNoteDetail(snapshot.data!.data[index]),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNoteDialog(context), // Menggunakan context dari Scaffold
        child: Icon(Icons.add),
      ),
    );
  }

}

class NoteCard extends StatelessWidget {
  final Datum note;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onView;

  NoteCard({
    required this.note,
    required this.onDelete,
    required this.onEdit,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.judulNote,
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.0),
            Text(
              note.isiNote,
              style: TextStyle(
                fontSize: 16.0,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.visibility),
                  onPressed: onView,
                ),
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Model Notes
ModelNotes modelNotesFromJson(String str) => ModelNotes.fromJson(json.decode(str));

String modelNotesToJson(ModelNotes data) => json.encode(data.toJson());

class ModelNotes {
  bool isSuccess;
  String message;
  List<Datum> data;

  ModelNotes({
    required this.isSuccess,
    required this.message,
    required this.data,
  });

  factory ModelNotes.fromJson(Map<String, dynamic> json) => ModelNotes(
    isSuccess: json["isSuccess"],
    message: json["message"],
    data: List<Datum>.from(json["data"].map((x) => Datum.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "isSuccess": isSuccess,
    "message": message,
    "data": List<dynamic>.from(data.map((x) => x.toJson())),
  };
}

class Datum {
  String id;
  String judulNote;
  String isiNote;

  Datum({
    required this.id,
    required this.judulNote,
    required this.isiNote,
  });

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
    id: json["id"],
    judulNote: json["judul_note"],
    isiNote: json["isi_note"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "judul_note": judulNote,
    "isi_note": isiNote,
  };
}