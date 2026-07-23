import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/student_model.dart';
import 'package:smartcampus/models/meeting_model.dart';
import 'package:smartcampus/services/meeting_firestore_service.dart';
import 'package:smartcampus/widgets/smc_text.dart';

class ProctorMeetingsTab extends StatefulWidget {
  final List<StudentModel> assignedStudents;
  final bool showScheduleButton;
  
  const ProctorMeetingsTab({
    super.key,
    required this.assignedStudents,
    this.showScheduleButton = true,
  });

  @override
  State<ProctorMeetingsTab> createState() => _ProctorMeetingsTabState();
}

class _ProctorMeetingsTabState extends State<ProctorMeetingsTab> {
  final MeetingFirestoreService _meetingService = MeetingFirestoreService();

  String _formatDisplayDate(String isoDate) {
    if (isoDate.isEmpty) return '';
    try {
      final d = DateTime.parse(isoDate);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (e) {
      return isoDate;
    }
  }

  InputDecoration _dialogFieldDecor(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: ColorConst.primaryBlue)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.assignedStudents.isEmpty) {
      return const Center(
        child: smcText(textToDisplay: 'No students assigned yet.', textSize: 14, colorOfText: ColorConst.textSecondary),
      );
    }
    
    final studentUuids = widget.assignedStudents.map((s) => s.resolvedUuid).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE4EBFB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF0FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.event_outlined, color: ColorConst.primaryBlue),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const smcText(
                          textToDisplay: 'Proctoring Meetings',
                          textSize: 16,
                          textBoldness: 5,
                          colorOfText: Color(0xFF1F2F52),
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        const smcText(
                          textToDisplay: 'Manage meetings with your assigned students.',
                          textSize: 12,
                          colorOfText: Color(0xFF7D87A3),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ],
                ),
                if (widget.showScheduleButton)
                  ElevatedButton.icon(
                    onPressed: () => _openMeetingDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                    label: const smcText(
                      textToDisplay: 'Schedule Meeting',
                      textSize: 13,
                      textBoldness: 4,
                      colorOfText: Colors.white,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorConst.primaryBlue,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<MeetingModel>>(
                stream: _meetingService.getMeetingsForStudents(studentUuids),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final rawMeetings = snapshot.data ?? [];
                  
                  final Map<String, MeetingModel> grouped = {};
                  for (var m in rawMeetings) {
                    final key = '${m.date}_${m.time}_${m.purpose}';
                    if (!grouped.containsKey(key)) {
                      grouped[key] = m;
                    }
                  }
                  
                  final meetings = grouped.values.toList();

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE3EAF8)),
                    ),
                    child: meetings.isEmpty
                        ? const Center(
                            child: smcText(
                              textToDisplay: 'No meetings scheduled yet.',
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
                                            border: TableBorder.all(color: const Color(0xFFE3EAF8), width: 1),
                                            headingRowColor: MaterialStateProperty.all(const Color(0xFFF4F7FF)),
                                            columns: const [
                                              DataColumn(label: SizedBox(width: 50, child: Center(child: smcText(textToDisplay: 'S.No', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                              DataColumn(label: SizedBox(width: 100, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'Date', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                                              DataColumn(label: SizedBox(width: 80, child: Center(child: smcText(textToDisplay: 'Time', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                              DataColumn(label: SizedBox(width: 140, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'Type', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                                              DataColumn(label: SizedBox(width: 250, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'Purpose', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                                              DataColumn(label: SizedBox(width: 120, child: Center(child: smcText(textToDisplay: 'Status', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                              DataColumn(label: SizedBox(width: 250, child: Padding(padding: EdgeInsets.only(left: 8), child: Align(alignment: Alignment.centerLeft, child: smcText(textToDisplay: 'Meeting Minutes', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B)))))),
                                              DataColumn(label: SizedBox(width: 120, child: Center(child: smcText(textToDisplay: 'Actions', textSize: 12, textBoldness: 4, colorOfText: Color(0xFF5C6B8B))))),
                                            ],
                                            rows: meetings.asMap().entries.map((entry) {
                                              final int index = entry.key;
                                              final MeetingModel m = entry.value;
                                              final int serialNo = index + 1;
                                              return DataRow(
                                                onSelectChanged: (_) => _openMeetingDialog(meeting: m, allMeetings: rawMeetings),
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
                                                          textToDisplay: _formatDisplayDate(m.date),
                                                          textSize: 12,
                                                          textBoldness: 4,
                                                          colorOfText: const Color(0xFF2E3954),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: smcText(
                                                        textToDisplay: m.time,
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
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: m.type == 'Academic Review' ? const Color(0xFFEFF4FF) : const Color(0xFFF5F3FF),
                                                            borderRadius: BorderRadius.circular(999),
                                                          ),
                                                          child: smcText(
                                                            textToDisplay: m.type,
                                                            textSize: 11,
                                                            textBoldness: 4,
                                                            colorOfText: m.type == 'Academic Review' ? ColorConst.primaryBlue : const Color(0xFF7E22CE),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                      child: Align(
                                                        alignment: Alignment.centerLeft,
                                                        child: smcText(
                                                          textToDisplay: m.purpose,
                                                          textSize: 12,
                                                          colorOfText: const Color(0xFF2E3954),
                                                          maxLines: 2,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: m.status == 'Scheduled' ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9),
                                                          borderRadius: BorderRadius.circular(999),
                                                        ),
                                                        child: smcText(
                                                          textToDisplay: m.status,
                                                          textSize: 11,
                                                          textBoldness: 4,
                                                          colorOfText: m.status == 'Scheduled' ? const Color(0xFFF57C00) : const Color(0xFF2E7D32),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                                      child: TextFormField(
                                                        initialValue: m.minutes,
                                                        decoration: const InputDecoration(
                                                          border: InputBorder.none,
                                                          hintText: 'Type points discussed...',
                                                          isDense: true,
                                                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF2E3954),
                                                        ),
                                                        maxLines: 3,
                                                        minLines: 1,
                                                        onChanged: (value) async {
                                                          final key = '${m.date}_${m.time}_${m.purpose}';
                                                          final toEdit = rawMeetings.where((rm) => '${rm.date}_${rm.time}_${rm.purpose}' == key).toList();
                                                          for (var rm in toEdit) {
                                                            final updatedMeeting = MeetingModel(
                                                              id: rm.id,
                                                              uuid: rm.uuid,
                                                              date: rm.date,
                                                              time: rm.time,
                                                              purpose: rm.purpose,
                                                              minutes: value,
                                                              type: rm.type,
                                                              status: rm.status,
                                                              createdOn: rm.createdOn,
                                                            );
                                                            await _meetingService.updateMeeting(rm.id!, updatedMeeting);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  DataCell(
                                                    Center(
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.edit_outlined, size: 18, color: ColorConst.primaryBlue),
                                                            onPressed: () => _openMeetingDialog(meeting: m, allMeetings: rawMeetings),
                                                            tooltip: 'Edit',
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                                            onPressed: () => _deleteMeeting(m, rawMeetings),
                                                            tooltip: 'Delete',
                                                          ),
                                                        ],
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
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMeetingDialog({MeetingModel? meeting, List<MeetingModel>? allMeetings}) async {
    final bool isEdit = meeting != null;
    final formKey = GlobalKey<FormState>();
    final dateCtrl = TextEditingController(text: meeting?.date ?? '');
    final timeCtrl = TextEditingController(text: meeting?.time ?? '');
    final purposeCtrl = TextEditingController(text: meeting?.purpose ?? '');
    String selectedUuid = meeting?.uuid ?? '__ALL__';
    String selectedType = meeting?.type ?? 'Academic Review';
    String selectedStatus = meeting?.status ?? 'Scheduled';
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          smcText(
                            textToDisplay: '${isEdit ? 'Edit' : 'Schedule'} Meeting',
                            textSize: 18,
                            textBoldness: 5,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedType,
                              decoration: _dialogFieldDecor('Meeting Type *'),
                              items: const [
                                DropdownMenuItem(value: 'Academic Review', child: Text('Academic Review', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: 'Parent Meeting', child: Text('Parent Meeting', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: 'Disciplinary', child: Text('Disciplinary', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: 'Other', child: Text('Other', style: TextStyle(fontSize: 14))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedType = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedStatus,
                              decoration: _dialogFieldDecor('Status *'),
                              items: const [
                                DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 14))),
                                DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled', style: TextStyle(fontSize: 14))),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedStatus = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: dateCtrl,
                              readOnly: true,
                              decoration: _dialogFieldDecor('Date *').copyWith(
                                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 16),
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setModalState(() => dateCtrl.text = picked.toIso8601String().split('T')[0]);
                                }
                              },
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: timeCtrl,
                              decoration: _dialogFieldDecor('Time *', hint: 'e.g., 10:30 AM'),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: purposeCtrl,
                        maxLines: 2,
                        decoration: _dialogFieldDecor('Purpose *'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: saving ? null : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModalState(() => saving = true);
                            try {
                                if (isEdit) {
                                  final key = '${meeting!.date}_${meeting.time}_${meeting.purpose}';
                                  final toEdit = (allMeetings ?? []).where((m) => '${m.date}_${m.time}_${m.purpose}' == key).toList();
                                  if (toEdit.isEmpty) toEdit.add(meeting);
                                  for (var m in toEdit) {
                                    final updated = MeetingModel(
                                      id: m.id,
                                      uuid: m.uuid,
                                      date: dateCtrl.text,
                                      time: timeCtrl.text,
                                      purpose: purposeCtrl.text,
                                      minutes: meeting.minutes ?? '',
                                      type: selectedType,
                                      status: selectedStatus,
                                      createdOn: m.createdOn ?? DateTime.now(),
                                    );
                                    await _meetingService.updateMeeting(m.id!, updated);
                                  }
                                } else {
                                final uuidsToSave = selectedUuid == '__ALL__'
                                    ? widget.assignedStudents.map((s) => s.resolvedUuid).toList()
                                    : [selectedUuid];

                                for (var uuid in uuidsToSave) {
                                  final m = MeetingModel(
                                    uuid: uuid,
                                    date: dateCtrl.text,
                                    time: timeCtrl.text,
                                    purpose: purposeCtrl.text,
                                    minutes: '',
                                    type: selectedType,
                                    status: selectedStatus,
                                    createdOn: DateTime.now(),
                                  );
                                  await _meetingService.addMeeting(m);
                                }
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setModalState(() => saving = false);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorConst.primaryBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: saving
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : smcText(textToDisplay: isEdit ? 'Save Changes' : 'Schedule', textSize: 14, colorOfText: Colors.white, textBoldness: 5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _deleteMeeting(MeetingModel meeting, List<MeetingModel> allMeetings) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Meeting'),
        content: const Text('Are you sure you want to delete this meeting?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final key = '${meeting.date}_${meeting.time}_${meeting.purpose}';
      final toDelete = allMeetings.where((m) => '${m.date}_${m.time}_${m.purpose}' == key).toList();
      if (toDelete.isEmpty) toDelete.add(meeting);
      for (var m in toDelete) {
        await _meetingService.deleteMeeting(m.id!);
      }
    }
  }
}
