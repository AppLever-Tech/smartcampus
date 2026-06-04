import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:smartcampus/screens/shared/student_import_preview_page.dart';
import '../data/student_model.dart';
import '../services/student_firestore_service.dart';
import '../models/student_import_row.dart';
import '../services/student_import_validator.dart';
import 'package:flutter_dropzone/flutter_dropzone.dart';

class StudentImportDialog extends StatefulWidget {
  final String orgId;
  final String deptId;


  const StudentImportDialog({
    super.key,
    required this.orgId,
    required this.deptId,
  });

  @override
  State<StudentImportDialog> createState() =>
      _StudentImportDialogState();
}

class _StudentImportDialogState
    extends State<StudentImportDialog> {
  bool importing = false;

  double progress = 0;
  DropzoneViewController? dropController;

  List<StudentImportRow> rows = [];

  bool loading = false;
  List<String> validateStudent(
      StudentModel student,
      ) {
    List<String> errors = [];

    if (student.studentId.trim().isEmpty) {
      errors.add("Missing Student ID");
    }

    if (student.fullName.trim().isEmpty) {
      errors.add("Missing Name");
    }

    if (student.email.trim().isEmpty) {
      errors.add("Missing Email");
    }

    if (student.mobile.trim().isEmpty) {
      errors.add("Missing Mobile");
    }

    return errors;
  }

  int get totalRows =>
      rows.length;

  int get validRows =>
      rows
          .where(
            (e) =>
        e.errors.isEmpty &&
            !e.existsInSystem,
      )
          .length;

  int get overwriteRows =>
      rows
          .where(
            (e) =>
        e.existsInSystem &&
            e.overwrite,
      )
          .length;

  int get skippedRows =>
      rows
          .where(
            (e) =>
        !e.selected ||
            e.hasError,
      )
          .length;

  Future<void> downloadTemplate() async {

    final workbook =
    excel.Excel.createExcel();

    final sheet =
    workbook['Students'];

    sheet.appendRow([

      'Student ID',

      'Full Name',

      'Gender',

      'Date Of Birth',

      'Aadhaar Number',

      'Category',

      'Nationality',

      'Blood Group',

      'Mobile Number',

      'Email Address',

      'Permanent Address',

      'Correspondence Address',

      'Emergency Contact Name',

      'Emergency Contact Relation',

      'Emergency Contact Mobile',
    ]);

    sheet.appendRow([

      '1AB22CS001',

      'Rahul Kumar',

      'Male',

      '2004-05-15',

      '123456789012',

      'OBC',

      'Indian',

      'O+',

      '9876543210',

      'rahul@gmail.com',

      'Bangalore',

      'Bangalore',

      'Rajesh Kumar',

      'Father',

      '9876543211',
    ]);

    final bytes =
    workbook.encode();

    if(bytes == null) return;

    await FileSaver.instance.saveFile(
      name: 'Student_Import_Template',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );

    if(!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Template Downloaded',
        ),
      ),
    );
  }
  Future<void> exportErrors() async {

    final workbook =
    excel.Excel.createExcel();

    final sheet =
    workbook['Errors'];

    sheet.appendRow([
      'Student ID',
      'Name',
      'Errors',
    ]);

    for(final row in rows){

      if(row.hasError){

        sheet.appendRow([

          row.student.studentId,

          row.student.fullName,

          row.errors.join(', '),

        ]);
      }
    }

    final bytes =
    workbook.encode();

    if(bytes == null) return;

    await FileSaver.instance.saveFile(
      name: 'Import_Errors',
      bytes: Uint8List.fromList(bytes),
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );

    if(!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Error Report Downloaded',
        ),
      ),
    );
  }
  Future<void> processExcelBytes(
      Uint8List bytes,
      ) async {
    setState(() {
      loading = true;
    });
    final workbook =
    excel.Excel.decodeBytes(bytes);

    final sheet =
        workbook.tables.values.first;

    List<StudentImportRow> imported = [];

    final service =
    StudentFirestoreService();
    final existingStudents =
    await service.listStudentsForOrg(
      widget.orgId,
    );

    final existingIds =
    existingStudents
        .map((e) => e.studentId)
        .toSet();
    for(int i = 1;
    i < sheet.rows.length;
    i++) {

      final row = sheet.rows[i];

      final student = StudentModel(

        studentId:
        row[0]?.value.toString() ?? '',

        fullName:
        row[1]?.value.toString() ?? '',

        gender:
        row[2]?.value.toString() ?? '',

        dateOfBirth:
        row[3]?.value.toString() ?? '',

        aadhaarNumber:
        row[4]?.value.toString() ?? '',

        category:
        row[5]?.value.toString() ?? '',

        nationality:
        row[6]?.value.toString() ?? '',

        bloodGroup:
        row[7]?.value.toString() ?? '',

        mobile:
        row[8]?.value.toString() ?? '',

        email:
        row[9]?.value.toString() ?? '',

        permanentAddress:
        row[10]?.value.toString() ?? '',

        correspondenceAddress:
        row[11]?.value.toString() ?? '',

        emergencyContactName:
        row[12]?.value.toString() ?? '',

        emergencyContactRelation:
        row[13]?.value.toString() ?? '',

        emergencyContactMobile:
        row[14]?.value.toString() ?? '',

        orgId: widget.orgId,

        deptId: widget.deptId,

        createdOn:
        DateTime.now()
            .toIso8601String(),
      );

      final errors =
      validateStudent(student);

      // final existing =
      // await service.findStudent(
      //   orgId: widget.orgId,
      //   studentId:
      //   student.studentId,
      // );

      imported.add(

        StudentImportRow(

          student: student,

          errors: errors,

          existsInSystem:
          existingIds.contains(
            student.studentId,
          ),
        ),
      );
    }
    setState(() {
      loading = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentImportPreviewScreen(
          rows: imported,
          orgId: widget.orgId,
          deptId: widget.deptId,
        ),
      ),
    );
  }

  Future<void> pickExcel() async {
    final result =
    await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result == null) return;

    final bytes =
    result.files.single.bytes!;

    await processExcelBytes(
      bytes,
    );
  }

  // Future<void> importStudents() async {
  //   setState(() {
  //
  //     importing = true;
  //
  //     progress = 0;
  //
  //   });
  //   final confirm =
  //   await showDialog<bool>(
  //     context: context,
  //     builder: (_) =>
  //         AlertDialog(
  //
  //           title: const Text(
  //             "Confirm Import",
  //           ),
  //
  //           content: Text(
  //             """
  //               New Records : $validRows
  //
  //               Overwrite : $overwriteRows
  //
  //               Skipped : $skippedRows
  //
  //               Continue?
  //               """,
  //           ),
  //
  //           actions: [
  //
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.pop(
  //                   context,
  //                   false,
  //                 );
  //               },
  //               child: const Text(
  //                 "Cancel",
  //               ),
  //             ),
  //
  //             ElevatedButton(
  //               onPressed: () {
  //                 Navigator.pop(
  //                   context,
  //                   true,
  //                 );
  //               },
  //               child: const Text(
  //                 "Import",
  //               ),
  //             ),
  //           ],
  //         ),
  //   );
  //
  //   if (confirm != true) {
  //
  //     setState(() {
  //       importing = false;
  //     });
  //
  //     return;
  //   }
  //   final service =
  //   StudentFirestoreService();
  //
  //   int imported = 0;
  //
  //   int overwritten = 0;
  //
  //   int skipped = 0;
  //
  //   for(
  //   int i = 0;
  //   i < rows.length;
  //   i++
  //   ){final row = rows[i];
  //     if (!row.selected) {
  //       skipped++;
  //
  //       continue;
  //     }
  //
  //     if (row.hasError) {
  //       skipped++;
  //
  //       continue;
  //     }
  //
  //     final existing =
  //     await service.findStudent(
  //       orgId: widget.orgId,
  //       studentId:
  //       row.student.studentId,
  //     );
  //
  //     if (existing != null) {
  //       if (row.overwrite) {
  //         await service.updateStudent(
  //           documentId:
  //           existing.documentId!,
  //           updated: row.student,
  //         );
  //
  //         overwritten++;
  //       } else {
  //         skipped++;
  //       }
  //     } else {
  //       await service.createStudent(
  //         row.student,
  //       );
  //
  //       imported++;
  //     }
  //   setState(() {
  //     if(rows.isNotEmpty) {
  //       progress =
  //           (i + 1) /
  //               rows.length;
  //     }
  //   });
  //   }
  //
  //   if (!mounted) return;
  //   setState(() {
  //
  //     importing = false;
  //
  //   });
  //   Navigator.pop(context);
  //
  //   ScaffoldMessenger.of(context)
  //       .showSnackBar(
  //
  //     SnackBar(
  //       content: Text(
  //         """
  //         Import Completed
  //
  //         Imported : $imported
  //
  //         Overwritten : $overwritten
  //
  //         Skipped : $skipped
  //         """,
  //       ),
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 1000,
        height: 600,
        child: Column(
          children: [

            const SizedBox(height: 20),

            Container(
              height: 220,
              margin: const EdgeInsets.all(12),

              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey.shade400,
                ),
                borderRadius:
                BorderRadius.circular(12),
              ),

              child: Stack(
                children: [

                  DropzoneView(
                    onCreated: (ctrl) {
                      dropController = ctrl;
                    },

                    onDropFile: (file) async {

                      final bytes =
                      await dropController!
                          .getFileData(file);

                      await processExcelBytes(
                        bytes,
                      );
                    },
                  ),

                  Center(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,

                      children: [

                        const Icon(
                          Icons.cloud_upload,
                          size: 40,
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          "Drop XLS/XLSX File Here",
                        ),

                        const SizedBox(height: 8),

                        ElevatedButton(
                          onPressed: pickExcel,
                          child: const Text(
                            "Choose File",
                          ),
                        ),
                        const SizedBox(height: 8),

                        OutlinedButton.icon(

                          onPressed: downloadTemplate,

                          icon: const Icon(
                            Icons.download,
                          ),

                          label: const Text(
                            "Download Template",
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if(
            rows.any(
                  (e) => e.hasError,
            )
            )

              OutlinedButton.icon(

                onPressed: exportErrors,

                icon: const Icon(
                  Icons.error_outline,
                ),

                label: const Text(
                  "Export Errors",
                ),
              ),
            const SizedBox(height: 20),

            Expanded(
              child: loading
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : const Center(
                child: Text(
                  "Upload an Excel file to preview students",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                ),
              ),
            )

            // Container(
            //   margin: const EdgeInsets.all(12),
            //   padding: const EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     border: Border.all(
            //       color: Colors.grey.shade300,
            //     ),
            //     borderRadius:
            //     BorderRadius.circular(12),
            //   ),
            //   child: Column(
            //     children: [
            //
            //       Text(
            //         "Total Records : $totalRows",
            //       ),
            //
            //       Text(
            //         "New Records : $validRows",
            //       ),
            //
            //       Text(
            //         "Overwrite : $overwriteRows",
            //       ),
            //
            //       Text(
            //         "Skipped : $skippedRows",
            //       ),
            //     ],
            //   ),
            // ),

            ,if(importing)

              Padding(
                padding:
                const EdgeInsets.all(12),

                child: Column(

                  children: [

                    LinearProgressIndicator(
                      value: progress,
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "${(progress * 100).toStringAsFixed(0)} %",
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.end,
                children: [

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "Cancel",
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ElevatedButton(
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: Colors.blue,
                  //     foregroundColor: Colors.white,
                  //   ),
                  //   onPressed: () {
                  //     // action here
                  //   },
                  //   child: const Text(
                  //     "View Preview Files",
                  //   ),
                  // )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}