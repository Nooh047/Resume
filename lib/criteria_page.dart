import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class CriteriaPage extends StatefulWidget {
  const CriteriaPage({Key? key}) : super(key: key);

  @override
  _CriteriaPageState createState() => _CriteriaPageState();
}

class _CriteriaPageState extends State<CriteriaPage> {
  final _formKey = GlobalKey<FormState>();
  final _qualificationController = TextEditingController();
  final _skillController = TextEditingController();
  final _experienceController = TextEditingController();
  final _resumesSelectedController = TextEditingController();

  List<PlatformFile> _selectedFiles = [];
  List<dynamic> rankedResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _qualificationController.dispose();
    _skillController.dispose();
    _experienceController.dispose();
    _resumesSelectedController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        _selectedFiles = result.files;
      });
    }
  }

  Future<bool> _uploadResumes() async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://127.0.0.1:8000/upload/'),
    );

    for (var file in _selectedFiles) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'files',
          file.path!,
        ),
      );
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    return response.statusCode == 200;
  }

  Future<void> _rankResumes() async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/rank/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'qualification': _qualificationController.text,
        'skills': _skillController.text,
        'experience': int.parse(_experienceController.text),
        'resumes_selected': int.parse(_resumesSelectedController.text),
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        rankedResults = json.decode(response.body);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ranking completed successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rank resumes: ${response.body}')),
      );
    }
  }

  Future<void> _submitCriteria() async {
    if (_formKey.currentState!.validate() && _selectedFiles.isNotEmpty) {
      setState(() => _isLoading = true);
      final uploadSuccess = await _uploadResumes();
      if (uploadSuccess) {
        await _rankResumes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resume upload failed.')),
        );
      }
      setState(() => _isLoading = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select resumes to upload.')),
      );
    }
  }

  Future<void> _openResume(int resumeId) async {
    final url = 'http://127.0.0.1:8000/resume/$resumeId';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open resume with ID: $resumeId')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resume Ranking System')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _qualificationController,
                          decoration:
                              const InputDecoration(labelText: 'Qualification'),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter qualification'
                              : null,
                        ),
                        TextFormField(
                          controller: _skillController,
                          decoration: const InputDecoration(
                              labelText: 'Skills (comma-separated)'),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter skills'
                              : null,
                        ),
                        TextFormField(
                          controller: _experienceController,
                          decoration: const InputDecoration(
                              labelText: 'Experience (years)'),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter experience'
                              : null,
                        ),
                        TextFormField(
                          controller: _resumesSelectedController,
                          decoration: const InputDecoration(
                              labelText: 'Number of Resumes to Select'),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter number of resumes'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _pickFiles,
                          child: const Text('Select Resumes (PDF)'),
                        ),
                        Text('${_selectedFiles.length} resumes selected'),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submitCriteria,
                          child: const Text('Submit & Rank'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  rankedResults.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ranked Resumes:',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: rankedResults.length,
                              itemBuilder: (context, index) {
                                final candidate = rankedResults[index];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      candidate['name'],
                                      style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                        'Phone: ${candidate['phone']}, Email: ${candidate['email']}, Score: ${candidate['score']}'),
                                    onTap: () => _openResume(candidate['id']),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      : const Text('No ranked results available.'),
                ],
              ),
            ),
    );
  }
}
