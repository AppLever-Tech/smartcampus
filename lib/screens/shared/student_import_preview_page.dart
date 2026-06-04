import 'package:flutter/material.dart';

import 'package:smartcampus/models/student_import_row.dart';
import 'package:smartcampus/services/student_firestore_service.dart';
import 'package:smartcampus/services/user_master_firestore_service.dart';

class StudentImportPreviewScreen extends StatefulWidget {
  final List<StudentImportRow> rows;
  final String orgId;
  final String deptId;


  const StudentImportPreviewScreen({
    super.key,
    required this.rows,
    required this.orgId,
    required this.deptId,
  });

  @override
  State<StudentImportPreviewScreen> createState() =>
      _StudentImportPreviewScreenState();
}

class _StudentImportPreviewScreenState
    extends State<StudentImportPreviewScreen> {

  bool importing = false;

  double progress = 0;
  String filterType = 'all';

  late List<StudentImportRow> rows;

  int get totalRows => rows.length;

  int get validRows =>
      rows.where(
            (e) =>
        e.errors.isEmpty &&
            !e.existsInSystem,
      ).length;

  int get overwriteRows =>
      rows.where(
            (e) =>
        e.existsInSystem &&
            e.overwrite,
      ).length;

  int get skippedRows =>
      rows.where(
            (e) =>
        !e.selected ||
            e.hasError,
      ).length;

  int get errorRows =>
      rows.where(
            (e) => e.hasError,
      ).length;
  List<StudentImportRow> get filteredRows {

    if (filterType == 'new') {
      return rows.where(
            (e) => !e.existsInSystem,
      ).toList();
    }

    if (filterType == 'existing') {
      return rows.where(
            (e) => e.existsInSystem,
      ).toList();
    }

    return rows;
  }

  Future<void> saveImport() async {
    setState(() {

      importing = true;

      progress = 0;

    });
    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(

            title: const Text(
              "Confirm Import",
            ),

            content: Text(
              """
                New Records : $validRows
                
                Overwrite : $overwriteRows
                
                Skipped : $skippedRows
                
                Continue?
                """,
            ),

            actions: [

              TextButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    false,
                  );
                },
                child: const Text(
                  "Cancel",
                ),
              ),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    true,
                  );
                },
                child: const Text(
                  "Import",
                ),
              ),
            ],
          ),
    );

    if (confirm != true) {

      setState(() {
        importing = false;
      });

      return;
    }
    final service =
    StudentFirestoreService();

    int imported = 0;

    int overwritten = 0;

    int skipped = 0;

    for(
    int i = 0;
    i < rows.length;
    i++
    ){final row = rows[i];
    if (!row.selected) {
      skipped++;

      continue;
    }

    if (row.hasError) {
      skipped++;

      continue;
    }

    final existing =
    await service.findStudent(
      orgId: widget.orgId,
      studentId:
      row.student.studentId,
    );

    if (existing != null) {
      if (row.overwrite) {
        await service.updateStudent(
          documentId:
          existing.documentId!,
          updated: row.student,
        );

        overwritten++;
      } else {
        skipped++;
      }
    } else {
      await service.createStudent(
        row.student,
      );
      await UserMasterFirestoreService().syncFromStudent(row.student);

      imported++;
    }
    setState(() {
      if(rows.isNotEmpty) {
        progress =
            (i + 1) /
                rows.length;
      }
    });
    }

    if (!mounted) return;
    setState(() {

      importing = false;

    });
    Navigator.of(context).pop(true);

    ScaffoldMessenger.of(context)
        .showSnackBar(

      SnackBar(
        content: Text(
          """
          Import Completed
          
          Imported : $imported
          
          Overwritten : $overwritten
          
          Skipped : $skipped
          """,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    rows = widget.rows;
  }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
          appBar: AppBar(
            title: const Text(
              "Student Import Preview",
            ),

            actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  "${rows.length} Records",
                ),
              ),
            ),
          ],
          ),
        body: Column(
          children: [

            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blue.shade50,
              child: Row(
                children: [

                  Text("Total : $totalRows"),

                  const SizedBox(width: 20),

                  Text("New : $validRows"),

                  const SizedBox(width: 20),

                  Text("Overwrite : $overwriteRows"),

                  const SizedBox(width: 20),

                  Text("Errors : $errorRows"),

                  const Spacer(),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        for (var row in rows) {
                          row.selected = true;
                        }
                      });
                    },
                    child: const Text("Select All"),
                  ),

                  const SizedBox(width: 10),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        for (var row in rows) {
                          row.selected = false;
                        }
                      });
                    },
                    child: const Text("Deselect All"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child: Row(
                children: [

                  ElevatedButton(
                    // style: ElevatedButton.styleFrom(
                    //   backgroundColor:
                    //   filterType == 'new'
                    //       ? Colors.white
                    //       : Colors.grey.shade300,
                    // ),
                    onPressed: () {
                      setState(() {
                        filterType = 'new';
                      });
                    },
                    child: Text(
                      "New Records (${rows.where((e) => !e.existsInSystem).length})",
                    ),
                  ),

                  const SizedBox(width: 10),

                  ElevatedButton(
                    // style: ElevatedButton.styleFrom(
                      // backgroundColor:
                      // filterType == 'existing'
                      //     ? Colors.white
                      //     : Colors.grey.shade300,
                    // ),
                    onPressed: () {
                      setState(() {
                        filterType = 'existing';
                      });
                    },

                    child: Text(
                      "Existing Records (${rows.where((e) => e.existsInSystem).length})",
                    ),
                  ),

                  const SizedBox(width: 10),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        filterType = 'all';
                      });
                    },
                    child: const Text(
                      "Show All",
                    ),
                  ),
                ],
              ),
            ),


            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text("USN")),
                      DataColumn(label: Text("Name")),
                      DataColumn(label: Text("Gender")),
                      DataColumn(label: Text("DOB")),
                      DataColumn(label: Text("Mobile")),
                      DataColumn(label: Text("Email")),
                      DataColumn(label: Text("Batch")),
                      DataColumn(label: Text("Aadhaar")),
                      DataColumn(label: Text("Category")),
                      DataColumn(label: Text("Nationality")),
                      DataColumn(label: Text("Blood Group")),
                      DataColumn(label: Text("Permanent Address")),
                      DataColumn(label: Text("Correspondence Address")),
                      DataColumn(label: Text("Emergency Name")),
                      DataColumn(label: Text("Emergency Relation")),
                      DataColumn(label: Text("Emergency Mobile")),
                      DataColumn(label: Text("Select")),
                      DataColumn(label: Text("Exists")),
                      DataColumn(label: Text("Overwrite")),
                      DataColumn(label: Text("Errors")),
                    ],
                    rows: filteredRows.map((row) {
                      return DataRow(
                          color: WidgetStateProperty.all(

                            row.hasError
                                ? Colors.red.shade50

                                : row.existsInSystem
                                ? Colors.orange.shade50

                                : Colors.green.shade50,

                          ),
                        cells: [
                          DataCell(Text(row.student.studentId)),
                          DataCell(Text(row.student.fullName)),
                          DataCell(Text(row.student.gender)),
                          DataCell(Text(row.student.dateOfBirth)),
                          DataCell(Text(row.student.mobile)),
                          DataCell(Text(row.student.email)),
                          DataCell(Text(row.student.batch)),
                          DataCell(Text(row.student.aadhaarNumber)),
                          DataCell(Text(row.student.category)),
                          DataCell(Text(row.student.nationality)),
                          DataCell(Text(row.student.bloodGroup)),
                          DataCell(Text(row.student.permanentAddress)),
                          DataCell(Text(row.student.correspondenceAddress)),
                          DataCell(Text(row.student.emergencyContactName)),
                          DataCell(Text(row.student.emergencyContactRelation)),
                          DataCell(Text(row.student.emergencyContactMobile)),


                          DataCell(
                            Checkbox(
                              value: row.selected,
                              onChanged: (v) {
                                setState(() {
                                  row.selected = v ?? false;
                                });
                              },
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: row.existsInSystem
                                    ? Colors.orange.shade100
                                    : Colors.green.shade100,
                                borderRadius:
                                BorderRadius.circular(12),
                              ),
                              child: Text(
                                row.existsInSystem
                                    ? "Existing"
                                    : "New",
                                style: TextStyle(
                                  color: row.existsInSystem
                                      ? Colors.orange.shade900
                                      : Colors.green.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          DataCell(
                            row.existsInSystem
                                ? Checkbox(
                              value: row.overwrite,
                              onChanged: (v) {
                                setState(() {
                                  row.overwrite =
                                      v ?? false;
                                });
                              },
                            )
                                : const SizedBox(),
                          ),

                          DataCell(
                            Text(
                              row.errors.join(", "),
                              style: const TextStyle(
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            if (importing)
              Padding(
                padding: const EdgeInsets.all(12),
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
              child: ElevatedButton(
                onPressed: saveImport,
                child: const Text(
                  "Save Import",
                ),
              ),
            ),
          ],
        )
      );
    }

  }