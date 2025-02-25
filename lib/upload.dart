import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';

class UploadPage extends StatefulWidget {
  @override
  _UploadPageState createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  List<File> _selectedFiles = [];

  void _uploadFiles() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected')),
      );
    } else {
      var uri = Uri.parse('http://127.0.0.1:8000/upload/'); // Backend endpoint
      var request = http.MultipartRequest('POST', uri);

      for (var file in _selectedFiles) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'files', // Must match the backend's expected key
            file.path,
          ),
        );
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Successfully uploaded ${_selectedFiles.length} files')),
        );
        setState(() {
          _selectedFiles.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload files. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Upload Files')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () {
                // Implement file picking and populate _selectedFiles
              },
              child: Text('Select Files'),
            ),
            ElevatedButton(
              onPressed: _uploadFiles,
              child: Text('Upload Files'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() => runApp(MaterialApp(
      home: UploadPage(),
    ));
