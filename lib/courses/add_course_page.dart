import 'package:flutter/material.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddCoursePage extends StatefulWidget {


  const AddCoursePage({
    super.key,

  });

  @override
  State<AddCoursePage> createState() => _AddCoursePageState();
}

class _AddCoursePageState extends State<AddCoursePage> {

  final _formKey = GlobalKey<FormState>();

  String? selectedBatch;
  String? selectedSemester;
  String? selectedCourseType;

  final TextEditingController courseTitleController =
  TextEditingController();

  final TextEditingController facultyController =
  TextEditingController();

  final TextEditingController courseCodeController =
  TextEditingController();

  final TextEditingController creditsController =
  TextEditingController();

  final TextEditingController syllabusController =
  TextEditingController();

  InputDecoration inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE4E8F0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF5F7FB),

      appBar: AppBar(
        title: const Text('Add Course'),
        backgroundColor: Colors.white,
      ),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(24),

        child: Form(

          key: _formKey,

          child: Container(

            padding: const EdgeInsets.all(24),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Column(

              children: [

                Row(
                  children: [

                    Expanded(
                      child: DropdownButtonFormField<String>(

                        value: selectedBatch,

                        decoration:
                        inputDecoration('Batch'),

                        items: [
                          '2023-25',
                          '2024-26',
                          '2025-27'
                        ].map((e) {

                          return DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          );

                        }).toList(),

                        onChanged: (value) {
                          setState(() {
                            selectedBatch = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(width: 20),

                    Expanded(
                      child: DropdownButtonFormField<String>(

                        value: selectedSemester,

                        decoration:
                        inputDecoration('Semester'),

                        items: [
                          'I',
                          'II',
                          'III',
                          'IV'
                        ].map((e) {

                          return DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          );

                        }).toList(),

                        onChanged: (value) {
                          setState(() {
                            selectedSemester = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: courseTitleController,
                  decoration:
                  inputDecoration('Course Title'),
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: facultyController,
                  decoration:
                  inputDecoration('Faculty'),
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: courseCodeController,
                  decoration:
                  inputDecoration('Course Code'),
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: creditsController,
                  decoration:
                  inputDecoration('No. of Credits'),
                ),

                const SizedBox(height: 20),

                DropdownButtonFormField<String>(

                  value: selectedCourseType,

                  decoration:
                  inputDecoration('Course Type'),

                  items: [
                    'IPCC',
                    'PCC',
                    'PCCL',
                    'AEC',
                    'BSC',
                  ].map((e) {

                    return DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    );

                  }).toList(),

                  onChanged: (value) {

                    setState(() {
                      selectedCourseType = value;
                    });
                  },
                ),

                const SizedBox(height: 20),

                TextFormField(
                  controller: syllabusController,
                  decoration:
                  inputDecoration('Syllabus Link'),
                ),

                const SizedBox(height: 30),

                SizedBox(

                  width: double.infinity,

                  height: 55,

                  child: ElevatedButton(

                    onPressed: () async{

                      await FirebaseFirestore.instance
                          .collection(CourseFirestoreService.collection)
                          .add({

                        'batch': selectedBatch,
                        'semester': selectedSemester,
                        'courseTitle':
                        courseTitleController.text,

                        'faculty':
                        facultyController.text,

                        'courseCode':
                        courseCodeController.text,

                        'credits':
                        creditsController.text,

                        'courseType':
                        selectedCourseType,

                        'syllabus':
                        syllabusController.text,
                      });

                      Navigator.pop(context);
                    },


                    child: const Text(
                      'Save Course',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}