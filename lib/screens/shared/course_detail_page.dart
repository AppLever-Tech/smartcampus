import 'dart:typed_data';
import 'package:smartcampus/screens/shared/course_enrollment_excel_review_page.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/course_model.dart';
import 'package:smartcampus/services/course_firestore_service.dart';
import 'package:smartcampus/widgets/course_enroll_search_dialog.dart';
import 'package:smartcampus/widgets/pdf_preview.dart';
import 'package:smartcampus/widgets/smc_text.dart';
import 'package:url_launcher/url_launcher.dart';

class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({
    super.key,
    required this.course,
    this.allStudents = const [],
    this.assignedFaculty = const [],
    this.enrolledStudents = const [],
    this.studentAvatarBuilder,
    this.embedded = false,
    this.embeddedMaximized = false,
    this.onClose,
    this.onMaximize,
    this.onBackFromMaximized,
    this.onCourseUpdated,
    this.readOnly = false,
  });

  final CourseModel course;
  final List<StudentModel> allStudents;
  final List<FacultyModel> assignedFaculty;
  final List<StudentModel> enrolledStudents;
  final StudentAvatarBuilder? studentAvatarBuilder;
  final bool embedded;
  final bool embeddedMaximized;
  final VoidCallback? onClose;
  final VoidCallback? onMaximize;
  final VoidCallback? onBackFromMaximized;
  final ValueChanged<CourseModel>? onCourseUpdated;
  final bool readOnly;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  int _selectedIndex = 0;
  bool _uploadingSyllabus = false;
  bool _enrollingStudents = false;
  late String _syllabusPdfUrl;
  late String _syllabusPdfName;
  final CourseFirestoreService _courseService = CourseFirestoreService();
  final TextEditingController _enrolledSearchController = TextEditingController();
  int _enrolledCurrentPage = 1;
  int _enrolledRowsPerPage = 25;

  static const List<String> _tabLabels = [
    'Course Details',
    'Syllabus',
    'Assigned Faculties',
    'Enrolled Students',
  ];

  CourseModel get _course => widget.course;

  @override
  void initState() {
    super.initState();
    _syllabusPdfUrl = widget.course.syllabusPdfUrl;
    _syllabusPdfName = widget.course.syllabusPdfName;
  }

  @override
  void dispose() {
    _enrolledSearchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CourseDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.id != widget.course.id ||
        oldWidget.course.syllabusPdfUrl != widget.course.syllabusPdfUrl ||
        oldWidget.course.syllabusPdfName != widget.course.syllabusPdfName) {
      _syllabusPdfUrl = widget.course.syllabusPdfUrl;
      _syllabusPdfName = widget.course.syllabusPdfName;
    }
  }

  int get _weeklyTeachingHours =>
      _course.lectureHrs +
      _course.tutorialHrs +
      _course.practicalHrs +
      _course.othersHrs;

  String _studentKey(StudentModel student) {
    return student.documentId?.isNotEmpty == true
        ? student.documentId!
        : student.studentId;
  }

  List<StudentModel> get _enrolledStudentsList {
    final Set<String> enrolledIds = _course.enrolledStudentIds.toSet();
    if (enrolledIds.isEmpty) {
      return widget.enrolledStudents;
    }
    return widget.allStudents
        .where((student) => enrolledIds.contains(_studentKey(student)))
        .toList();
  }

  List<StudentModel> get _availableStudentsForEnrollment {
    final Set<String> enrolledIds = _course.enrolledStudentIds.toSet();
    return widget.allStudents
        .where((student) => !enrolledIds.contains(_studentKey(student)))
        .toList();
  }

  Widget _buildStudentAvatar(StudentModel student, {double radius = 18}) {
    if (widget.studentAvatarBuilder != null) {
      return widget.studentAvatarBuilder!(student, radius: radius);
    }
    final String initial = student.fullName.trim().isEmpty
        ? '?'
        : student.fullName.trim().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        initial,
        style: const TextStyle(
          color: ColorConst.primaryBlue,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTabBar(),
        Expanded(child: _buildSelectedView()),
      ],
    );

    if (widget.embedded) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: widget.embeddedMaximized
              ? BorderRadius.zero
              : BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3EAF8)),
        ),
        child: ClipRRect(
          borderRadius: widget.embeddedMaximized
              ? BorderRadius.zero
              : BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEmbeddedHeader(),
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

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
              textToDisplay: _displayText(_course.courseTitle),
              textSize: 16,
              textBoldness: 5,
              colorOfText: Colors.white,
              maxLines: 1,
            ),
            smcText(
              textToDisplay: 'Course Code: ${_displayText(_course.courseCode)}',
              textSize: 12,
              colorOfText: Colors.white.withValues(alpha: 0.8),
              maxLines: 1,
            ),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildEmbeddedHeader() {
    final bool isMaximized = widget.embeddedMaximized;

    return Container(
      color: ColorConst.primaryBlue,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              isMaximized ? Icons.arrow_back_rounded : Icons.close_rounded,
              color: Colors.white,
            ),
            tooltip: isMaximized ? 'Back' : 'Close',
            onPressed: isMaximized
                ? widget.onBackFromMaximized
                : widget.onClose,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                smcText(
                  textToDisplay: _displayText(_course.courseTitle),
                  textSize: 15,
                  textBoldness: 5,
                  colorOfText: Colors.white,
                  maxLines: 1,
                ),
                smcText(
                  textToDisplay:
                      'Course Code: ${_displayText(_course.courseCode)}',
                  textSize: 11,
                  colorOfText: Colors.white.withValues(alpha: 0.85),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          if (!isMaximized && widget.onMaximize != null)
            IconButton(
              icon: const Icon(Icons.open_in_new, color: Colors.white),
              tooltip: 'Maximize',
              onPressed: widget.onMaximize,
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < _tabLabels.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _buildFilterChip(_tabLabels[i], i),
            ],
          ],
        ),
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
            color: isSelected
                ? const Color(0xFF1967D2)
                : const Color(0xFFD1D5DB),
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
              colorOfText:
                  isSelected ? const Color(0xFF1967D2) : const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedView() {
    switch (_tabLabels[_selectedIndex.clamp(0, _tabLabels.length - 1)]) {
      case 'Syllabus':
        return _buildSyllabus();
      case 'Assigned Faculties':
        return _buildAssignedFaculty();
      case 'Enrolled Students':
        return _buildEnrolledStudents();
      case 'Course Details':
      default:
        return _buildCourseDetails();
    }
  }

  Widget _buildCourseDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDetailsSection(
            title: 'Course Information',
            icon: Icons.menu_book_outlined,
            children: [
              _buildDetailRow('Scheme / Batch', _course.batch),
              _buildDetailRow('Semester', _course.semester),
              _buildDetailRow('Course Type', _course.courseType),
              _buildDetailRow('Course Code', _course.courseCode),
              _buildDetailRow('Course Title', _course.courseTitle),
              _buildDetailRow('Credits', _course.credits),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Teaching Hours / Week',
            icon: Icons.access_time_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailField('Lecture', '${_course.lectureHrs}'),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDetailField('Tutorial', '${_course.tutorialHrs}'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailField('Practical', '${_course.practicalHrs}'),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDetailField('Others', '${_course.othersHrs}'),
                    ),
                  ],
                ),
              ),
              _buildDetailRow('Total Weekly Hours', '$_weeklyTeachingHours'),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailsSection(
            title: 'Examination Scheme',
            icon: Icons.assignment_outlined,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailField('CIE Marks', '${_course.cieMarks}'),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDetailField(
                        'SEE Exam Duration',
                        _displayText(_course.seeExamDuration),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildDetailField(
                        'SEE Theory Marks',
                        '${_course.seeTheoryMarks}',
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDetailField(
                        'SEE Lab Marks',
                        '${_course.seeLabMarks}',
                      ),
                    ),
                  ],
                ),
              ),
              _buildDetailRow('Total Marks', '${_course.totalMarks}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabus() {
    final bool hasPdf = _syllabusPdfUrl.trim().isNotEmpty;
    final String displayName = _syllabusPdfName.trim().isNotEmpty
        ? _syllabusPdfName.trim()
        : '${_course.courseCode.isNotEmpty ? _course.courseCode : 'course'}_syllabus.pdf';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3EAF8)),
            ),
            child: Row(
              children: [
                if (!widget.readOnly)
                  ElevatedButton.icon(
                    onPressed: _uploadingSyllabus ? null : _uploadSyllabusPdf,
                    icon: _uploadingSyllabus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded, size: 18, color: Colors.white),
                    label: smcText(
                      textToDisplay:
                          _uploadingSyllabus ? 'Uploading...' : 'Upload Syllabus',
                      textSize: 13,
                      textBoldness: 4,
                      colorOfText: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConst.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                if (!widget.readOnly) const SizedBox(width: 12),
                if (hasPdf) ...[
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: ColorConst.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: smcText(
                      textToDisplay: displayName,
                      textSize: 13,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _downloadSyllabusPdf,
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const smcText(
                      textToDisplay: 'Download',
                      textSize: 12,
                      textBoldness: 4,
                      colorOfText: ColorConst.primaryBlue,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ColorConst.primaryBlue,
                      side: const BorderSide(color: ColorConst.primaryBlue),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ] else
                  const Expanded(
                    child: smcText(
                      textToDisplay: 'No syllabus PDF uploaded yet.',
                      textSize: 13,
                      colorOfText: ColorConst.textSecondary,
                      maxLines: 1,
                    ),
                  ),
              ],
            ),
          ),
          if (hasPdf) ...[
            const SizedBox(height: 16),
            buildPdfPreview(_syllabusPdfUrl),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadSyllabusPdf() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final PlatformFile file = result.files.single;
      final Uint8List? bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read the selected PDF.')),
        );
        return;
      }

      setState(() => _uploadingSyllabus = true);

      final String safeCode = _course.courseCode.trim().isEmpty
          ? _course.id
          : _course.courseCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final String fileName = file.name.trim().isNotEmpty
          ? file.name.trim()
          : '${safeCode}_syllabus.pdf';

      final Reference ref = FirebaseStorage.instance
          .ref()
          .child('course_syllabi')
          .child('${safeCode}_${DateTime.now().millisecondsSinceEpoch}.pdf');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
      final String downloadUrl = await ref.getDownloadURL();

      await _courseService.updateCourseFields(_course.id, {
        'syllabus_pdf_url': downloadUrl,
        'syllabus_pdf_name': fileName,
      });

      if (!mounted) return;

      setState(() {
        _uploadingSyllabus = false;
        _syllabusPdfUrl = downloadUrl;
        _syllabusPdfName = fileName;
      });

      widget.onCourseUpdated?.call(
        _course.copyWith(
          syllabusPdfUrl: downloadUrl,
          syllabusPdfName: fileName,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syllabus uploaded successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingSyllabus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload syllabus: $e')),
      );
    }
  }

  Future<void> _downloadSyllabusPdf() async {
    final String url = _syllabusPdfUrl.trim();
    if (url.isEmpty) {
      return;
    }

    final String fileName = _syllabusPdfName.trim().isNotEmpty
        ? _syllabusPdfName.trim()
        : 'course_syllabus.pdf';
    final String baseName = fileName.toLowerCase().endsWith('.pdf')
        ? fileName.substring(0, fileName.length - 4)
        : fileName;

    try {
      if (kIsWeb) {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, webOnlyWindowName: '_blank');
        }
        return;
      }

      Uint8List? bytes;
      if (url.contains('firebasestorage.googleapis.com') || url.startsWith('gs://')) {
        final Reference ref = FirebaseStorage.instance.refFromURL(url);
        bytes = await ref.getData(15 * 1024 * 1024);
      }

      if (bytes != null && bytes.isNotEmpty) {
        await FileSaver.instance.saveFile(
          name: baseName,
          bytes: bytes,
          ext: 'pdf',
          mimeType: MimeType.pdf,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Syllabus downloaded.')),
        );
        return;
      }

      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download syllabus: $e')),
      );
    }
  }

  Widget _buildAssignedFaculty() {
    final List<FacultyModel> faculty = widget.assignedFaculty;
    if (faculty.isEmpty) {
      return _buildEmptyState(
        _course.faculty.trim().isEmpty
            ? 'No faculty assigned yet.'
            : 'Assigned faculty: ${_course.faculty}',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: faculty.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final FacultyModel f = faculty[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3EAF8)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFEAF0FF),
                child: smcText(
                  textToDisplay: f.fullName.trim().isEmpty
                      ? '?'
                      : f.fullName.trim().substring(0, 1).toUpperCase(),
                  textSize: 16,
                  textBoldness: 5,
                  colorOfText: ColorConst.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    smcText(
                      textToDisplay: _displayText(f.fullName),
                      textSize: 14,
                      textBoldness: 4,
                      colorOfText: ColorConst.textPrimary,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    smcText(
                      textToDisplay:
                          'Faculty ID: ${_displayText(f.facultyId)}',
                      textSize: 12,
                      colorOfText: ColorConst.textSecondary,
                      maxLines: 1,
                    ),
                    if (f.email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      smcText(
                        textToDisplay: f.email,
                        textSize: 12,
                        colorOfText: ColorConst.textSecondary,
                        maxLines: 1,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnrolledStudents() {
    final List<StudentModel> enrolled = _enrolledStudentsList;
    final String searchTerm = _enrolledSearchController.text.trim().toLowerCase();
    final List<StudentModel> searched = enrolled.where((s) {
      if (searchTerm.isEmpty) return true;
      return '${s.studentId} ${s.fullName} ${s.email} ${s.mobile} ${s.batch} ${s.gender}'
          .toLowerCase()
          .contains(searchTerm);
    }).toList()
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

    final int totalRows = searched.length;
    final int totalPages = totalRows == 0 ? 1 : ((totalRows - 1) ~/ _enrolledRowsPerPage) + 1;
    final int safePage = _enrolledCurrentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * _enrolledRowsPerPage;
    final int endIndex = (startIndex + _enrolledRowsPerPage).clamp(0, totalRows);
    final List<StudentModel> pageRows =
        totalRows == 0 ? <StudentModel>[] : searched.sublist(startIndex, endIndex);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const smcText(
                textToDisplay: 'Enrolled Students',
                textSize: 16,
                textBoldness: 5,
                colorOfText: Color(0xFF1F2F52),
                maxLines: 1,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: smcText(
                  textToDisplay: '${enrolled.length}',
                  textSize: 12,
                  textBoldness: 4,
                  colorOfText: ColorConst.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _enrolledSearchController,
                    onChanged: (_) => setState(() => _enrolledCurrentPage = 1),
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF8A96B2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColorConst.primaryBlue),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _enrolledSearchController.clear();
                      _enrolledCurrentPage = 1;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const smcText(
                    textToDisplay: 'Reset',
                    textSize: 12,
                    textBoldness: 3,
                    colorOfText: Color(0xFF4F5E7D),
                  ),
                ),
              ),
              if (!widget.readOnly) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _enrollingStudents ? null : _showEnrollStudentsOptions,
                  icon: _enrollingStudents
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
                  label: smcText(
                    textToDisplay:
                        _enrollingStudents ? 'Enrolling...' : 'Enroll Students',
                    textSize: 13,
                    textBoldness: 4,
                    colorOfText: Colors.white,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorConst.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE3EAF8)),
              ),
              child: totalRows == 0
                  ? const Center(
                      child: smcText(
                        textToDisplay: 'No students enrolled yet.',
                        textSize: 13,
                        colorOfText: Color(0xFF8A96B2),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double tableWidth = constraints.maxWidth;
                              return SingleChildScrollView(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(minWidth: tableWidth),
                                    child: DataTable(
                                      showCheckboxColumn: false,
                                      headingRowHeight: 50,
                                      dataRowMinHeight: 52,
                                      dataRowMaxHeight: 58,
                                      horizontalMargin: 0,
                                      columnSpacing: 0,
                                      dividerThickness: 1,
                                      border: TableBorder.all(
                                        color: const Color(0xFFE3EAF8),
                                        width: 1,
                                      ),
                                      headingRowColor: MaterialStateProperty.all(
                                        const Color(0xFFF4F7FF),
                                      ),
                                      columns: const [
                                        DataColumn(
                                          label: SizedBox(
                                            width: 50,
                                            child: Center(
                                              child: smcText(
                                                textToDisplay: 'S.No',
                                                textSize: 12,
                                                textBoldness: 4,
                                                colorOfText: Color(0xFF5C6B8B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: 100,
                                            child: Padding(
                                              padding: EdgeInsets.only(left: 8),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: smcText(
                                                  textToDisplay: 'USN / ID',
                                                  textSize: 12,
                                                  textBoldness: 4,
                                                  colorOfText: Color(0xFF5C6B8B),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: 200,
                                            child: Center(
                                              child: smcText(
                                                textToDisplay: 'Name',
                                                textSize: 12,
                                                textBoldness: 4,
                                                colorOfText: Color(0xFF5C6B8B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: 180,
                                            child: Center(
                                              child: smcText(
                                                textToDisplay: 'Email',
                                                textSize: 12,
                                                textBoldness: 4,
                                                colorOfText: Color(0xFF5C6B8B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: 110,
                                            child: Center(
                                              child: smcText(
                                                textToDisplay: 'Mobile #',
                                                textSize: 12,
                                                textBoldness: 4,
                                                colorOfText: Color(0xFF5C6B8B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: 90,
                                            child: Center(
                                              child: smcText(
                                                textToDisplay: 'Batch',
                                                textSize: 12,
                                                textBoldness: 4,
                                                colorOfText: Color(0xFF5C6B8B),
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: SizedBox(
                                            width: 90,
                                            child: Center(
                                              child: smcText(
                                                textToDisplay: 'Gender',
                                                textSize: 12,
                                                textBoldness: 4,
                                                colorOfText: Color(0xFF5C6B8B),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: pageRows.asMap().entries.map((entry) {
                                        final int index = entry.key;
                                        final StudentModel s = entry.value;
                                        final int serialNo = startIndex + index + 1;
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Center(
                                                child: smcText(
                                                  textToDisplay: '$serialNo',
                                                  textSize: 12,
                                                  colorOfText: const Color(0xFF2E3954),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.only(left: 8),
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: smcText(
                                                    textToDisplay: s.studentId,
                                                    textSize: 12,
                                                    textBoldness: 4,
                                                    colorOfText: const Color(0xFF2E3954),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                child: Row(
                                                  children: [
                                                    _buildStudentAvatar(s),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: smcText(
                                                        textToDisplay: s.fullName,
                                                        textSize: 12,
                                                        colorOfText: const Color(0xFF2E3954),
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Center(
                                                child: smcText(
                                                  textToDisplay: s.email,
                                                  textSize: 12,
                                                  colorOfText: const Color(0xFF2E3954),
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Center(
                                                child: smcText(
                                                  textToDisplay: s.mobile,
                                                  textSize: 12,
                                                  colorOfText: const Color(0xFF2E3954),
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Center(
                                                child: smcText(
                                                  textToDisplay: s.batch.isEmpty ? '—' : s.batch,
                                                  textSize: 12,
                                                  colorOfText: const Color(0xFF2E3954),
                                                  maxLines: 1,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF4FF),
                                                    borderRadius: BorderRadius.circular(999),
                                                  ),
                                                  child: smcText(
                                                    textToDisplay: s.gender,
                                                    textSize: 11,
                                                    textBoldness: 3,
                                                    colorOfText: const Color(0xFF3558DA),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          height: 58,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: Color(0xFFE3EAF8))),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      smcText(
                                        textToDisplay: totalRows == 0
                                            ? 'Showing 0 entries'
                                            : 'Showing ${startIndex + 1} to $endIndex of $totalRows entries',
                                        textSize: 12,
                                        colorOfText: const Color(0xFF7D87A3),
                                      ),
                                      const SizedBox(width: 16),
                                      const smcText(
                                        textToDisplay: 'Rows per page:',
                                        textSize: 12,
                                        colorOfText: Color(0xFF7D87A3),
                                      ),
                                      const SizedBox(width: 8),
                                      DropdownButton<int>(
                                        value: _enrolledRowsPerPage,
                                        items: const [
                                          DropdownMenuItem(value: 10, child: Text('10')),
                                          DropdownMenuItem(value: 25, child: Text('25')),
                                          DropdownMenuItem(value: 50, child: Text('50')),
                                          DropdownMenuItem(value: 100, child: Text('100')),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _enrolledRowsPerPage = value;
                                              _enrolledCurrentPage = 1;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        onPressed: safePage > 1
                                            ? () => setState(() => _enrolledCurrentPage = 1)
                                            : null,
                                        icon: const Icon(Icons.first_page_rounded),
                                      ),
                                      IconButton(
                                        onPressed: safePage > 1
                                            ? () => setState(() => _enrolledCurrentPage = safePage - 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_left_rounded),
                                      ),
                                      Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEAF0FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: smcText(
                                          textToDisplay: '$safePage',
                                          textSize: 12,
                                          textBoldness: 4,
                                          colorOfText: ColorConst.primaryBlue,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: safePage < totalPages
                                            ? () => setState(() => _enrolledCurrentPage = safePage + 1)
                                            : null,
                                        icon: const Icon(Icons.chevron_right_rounded),
                                      ),
                                      IconButton(
                                        onPressed: safePage < totalPages
                                            ? () => setState(() => _enrolledCurrentPage = totalPages)
                                            : null,
                                        icon: const Icon(Icons.last_page_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEnrollStudentsOptions() async {
    final String? choice = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const smcText(
                  textToDisplay: 'Enroll Students',
                  textSize: 18,
                  textBoldness: 5,
                  colorOfText: ColorConst.textPrimary,
                ),
                const SizedBox(height: 8),
                const smcText(
                  textToDisplay: 'Choose how you want to add students to this course.',
                  textSize: 13,
                  colorOfText: ColorConst.textSecondary,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'search'),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Search & Enroll'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorConst.primaryBlue,
                    side: const BorderSide(color: ColorConst.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'excel'),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Import from Excel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ColorConst.primaryBlue,
                    side: const BorderSide(color: ColorConst.primaryBlue),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || choice == null) {
      return;
    }

    if (choice == 'search') {
      await _openSearchEnrollDialog();
    } else if (choice == 'excel') {
      await _importEnrollFromExcel();
    }
  }

  Future<void> _openSearchEnrollDialog() async {
    final List<StudentModel> available = _availableStudentsForEnrollment;
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All department students are already enrolled.')),
      );
      return;
    }

    final List<StudentModel>? selected = await showDialog<List<StudentModel>>(
      context: context,
      builder: (_) => CourseEnrollSearchDialog(
        students: available,
        studentAvatarBuilder: widget.studentAvatarBuilder,
      ),
    );

    if (selected == null || selected.isEmpty) {
      return;
    }

    await _enrollStudents(selected);
  }

  Future<void> _importEnrollFromExcel() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final Uint8List? bytes = result.files.single.bytes;

      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not read the selected Excel file.',
            ),
          ),
        );
        return;
      }

      final excel.Excel workbook =
      excel.Excel.decodeBytes(bytes);

      if (workbook.tables.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No sheets found in the Excel file.',
            ),
          ),
        );
        return;
      }

      final excel.Sheet sheet =
          workbook.tables.values.first;

      if (sheet.rows.length <= 1) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No student IDs found in the Excel file.',
            ),
          ),
        );
        return;
      }

      final Map<String, StudentModel> availableById = {
        for (final StudentModel student
        in _availableStudentsForEnrollment)
          student.studentId.trim().toUpperCase(): student,
      };

      final List<StudentModel> matched = [];

      final Set<String> seenIds = {};

      for (int i = 1; i < sheet.rows.length; i++) {
        final List<excel.Data?> row = sheet.rows[i];

        final String studentId =
            row[0]?.value?.toString().trim().toUpperCase() ?? '';

        if (studentId.isEmpty ||
            seenIds.contains(studentId)) {
          continue;
        }

        final StudentModel? student =
        availableById[studentId];

        if (student != null) {
          matched.add(student);
          seenIds.add(studentId);
        }
      }

      if (matched.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No matching unenrolled students found in the Excel file.',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;

      final bool? enrolled =
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CourseEnrollmentExcelReviewPage(
                course: _course,
                students: matched,
                studentAvatarBuilder:
                widget.studentAvatarBuilder,
              ),
        ),
      );

      if (enrolled == true) {
        final List<String> keys =
        matched.map(_studentKey).toList();

        final List<String> updatedIds = {
          ..._course.enrolledStudentIds,
          ...keys,
        }.toList();

        widget.onCourseUpdated?.call(
          _course.copyWith(
            enrolledStudentIds: updatedIds,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to import enrollments: $e',
          ),
        ),
      );
    }
  }

  Future<void> _enrollStudents(List<StudentModel> students) async {
    if (students.isEmpty) {
      return;
    }

    setState(() => _enrollingStudents = true);
    try {
      final List<String> keys =
          students.map(_studentKey).where((key) => key.isNotEmpty).toList();
      await _courseService.enrollStudents(_course.id, keys);

      final List<String> updatedIds = {
        ..._course.enrolledStudentIds,
        ...keys,
      }.toList();

      if (!mounted) return;
      setState(() => _enrollingStudents = false);
      widget.onCourseUpdated?.call(
        _course.copyWith(enrolledStudentIds: updatedIds),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${students.length} student${students.length == 1 ? '' : 's'} enrolled successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enrollingStudents = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to enroll students: $e')),
      );
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: smcText(
        textToDisplay: message,
        textSize: 14,
        colorOfText: ColorConst.textSecondary,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDetailsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool stretchContent = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: stretchContent ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _sectionHeader(title, icon),
          if (stretchContent)
            Expanded(
              child: children.length == 1
                  ? children.first
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: ColorConst.primaryBlue),
          const SizedBox(width: 6),
          Expanded(
            child: smcText(
              textToDisplay: title,
              textSize: 12,
              textBoldness: 4,
              colorOfText: ColorConst.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildDetailField(label, value),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        smcText(
          textToDisplay: label,
          textSize: 12,
          textBoldness: 4,
          colorOfText: ColorConst.textSecondary,
        ),
        const SizedBox(height: 4),
        smcText(
          textToDisplay: _displayText(value),
          textSize: 13,
          textBoldness: 3,
          colorOfText: ColorConst.textPrimary,
          maxLines: 8,
        ),
      ],
    );
  }

  String _displayText(String value) {
    return value.trim().isEmpty ? '—' : value.trim();
  }
}
