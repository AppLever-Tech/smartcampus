import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class PersonDetailPage extends StatefulWidget {
  final dynamic person; // Can be StudentModel or FacultyModel
  final bool isStudent;

  const PersonDetailPage({
    super.key,
    required this.person,
    required this.isStudent,
  });

  @override
  State<PersonDetailPage> createState() => _PersonDetailPageState();
}

class _PersonDetailPageState extends State<PersonDetailPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final String name = widget.isStudent 
        ? (widget.person as StudentModel).fullName 
        : (widget.person as FacultyModel).fullName;
    final String id = widget.isStudent 
        ? (widget.person as StudentModel).studentId 
        : (widget.person as FacultyModel).facultyId;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: ColorConst.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            smcText(
              textToDisplay: name,
              textSize: 16,
              textBoldness: 5,
              colorOfText: Colors.white,
            ),
            smcText(
              textToDisplay: '${widget.isStudent ? "USN" : "Faculty ID"}: $id',
              textSize: 12,
              colorOfText: Colors.white.withOpacity(0.8),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Basic Details', 0),
                  const SizedBox(width: 10),
                  _buildFilterChip('Achievements', 1),
                  const SizedBox(width: 10),
                  _buildFilterChip('Publications', 2),
                ],
              ),
            ),
          ),
          Expanded(child: _buildSelectedView()),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1967D2) : const Color(0xFFD1D5DB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: Color(0xFF1967D2)),
              const SizedBox(width: 6),
            ],
            smcText(
              textToDisplay: label,
              textSize: 13,
              textBoldness: isSelected ? 4 : 3,
              colorOfText: isSelected ? const Color(0xFF1967D2) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedView() {
    switch (_selectedIndex) {
      case 0:
        return _buildBasicDetails();
      case 1:
        return _buildAchievements();
      case 2:
        return _buildPublications();
      default:
        return _buildBasicDetails();
    }
  }

  Widget _buildBasicDetails() {
    final Map<String, String> details = {};
    if (widget.isStudent) {
      final s = widget.person as StudentModel;
      details['Full Name'] = s.fullName;
      details['USN'] = s.studentId;
      details['Email'] = s.email;
      details['Mobile'] = s.mobile;
      details['Gender'] = s.gender;
      details['DOB'] = s.dateOfBirth;
      details['Category'] = s.category;
      details['Aadhaar'] = s.aadhaarNumber;
      details['Permanent Address'] = s.permanentAddress;
      details['Correspondence Address'] = s.correspondenceAddress;
    } else {
      final f = widget.person as FacultyModel;
      details['Full Name'] = f.fullName;
      details['Faculty ID'] = f.facultyId;
      details['Email'] = f.email;
      details['Mobile'] = f.mobile;
      details['Gender'] = f.gender;
      details['DOB'] = f.dateOfBirth;
      details['Aadhaar'] = f.aadhaarNumber;
      details['PAN'] = f.panNumber;
      details['Permanent Address'] = f.permanentAddress;
      details['Current Address'] = f.currentAddress;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE3EAF8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: details.entries.map((e) => _buildDetailRow(e.key, e.value)).toList(),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: smcText(
              textToDisplay: label,
              textSize: 13,
              textBoldness: 4,
              colorOfText: ColorConst.textSecondary,
            ),
          ),
          Expanded(
            child: smcText(
              textToDisplay: value.isEmpty ? '—' : value,
              textSize: 13,
              textBoldness: 3,
              colorOfText: ColorConst.textPrimary,
              maxLines: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievements() {
    return const Center(
      child: smcText(
        textToDisplay: 'No achievements recorded yet.',
        textSize: 14,
        colorOfText: ColorConst.textSecondary,
      ),
    );
  }

  Widget _buildPublications() {
    return const Center(
      child: smcText(
        textToDisplay: 'No publications recorded yet.',
        textSize: 14,
        colorOfText: ColorConst.textSecondary,
      ),
    );
  }
}
