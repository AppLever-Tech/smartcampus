import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class CourseDetailsPage extends StatelessWidget {
  final Map<String, dynamic> course;

  const CourseDetailsPage({
    super.key,
    required this.course,
  });

  Widget buildRow(
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: smcText(
              textToDisplay: label,
              textSize: 15,
              colorOfText:
              ColorConst.textSecondary,
            ),
          ),

          Expanded(
            flex: 4,
            child: smcText(
              textToDisplay: value,
              textSize: 15,
              textBoldness: 5,
              colorOfText:
              ColorConst.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF6F7FB),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const smcText(
          textToDisplay: 'Course Details',
          textSize: 20,
          textBoldness: 5,
          colorOfText:
          ColorConst.textPrimary,
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.circular(20),

            border: Border.all(
              color: const Color(0xFFE3EAF8),
            ),
          ),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              const smcText(
                textToDisplay:
                'Basic Course Information',
                textSize: 24,
                textBoldness: 5,
                colorOfText:
                ColorConst.textPrimary,
              ),

              const SizedBox(height: 30),

              buildRow(
                'Course Code',
                course['courseCode'],
              ),

              buildRow(
                'Course Title',
                course['courseTitle'],
              ),

              buildRow(
                'Course Type',
                course['courseType'],
              ),

              buildRow(
                'Department Offering',
                course['departmentOffering'],
              ),

              buildRow(
                'Curriculum Version',
                course['curriculumVersion'],
              ),
            ],
          ),
        ),
      ),
    );
  }
}