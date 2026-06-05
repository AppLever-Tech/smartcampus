import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';
import 'package:smartcampus/data/faculty_model.dart';
import 'package:smartcampus/widgets/smc_text.dart';

typedef FacultyAvatarBuilder = Widget Function(
    FacultyModel faculty, {
    double radius,
    });

class CourseAssignSearchDialog extends StatefulWidget {
  const CourseAssignSearchDialog({
    super.key,
    required this.faculties,
    this.facultyAvatarBuilder,
  });

  final List<FacultyModel> faculties;
  final FacultyAvatarBuilder? facultyAvatarBuilder;

  @override
  State<CourseAssignSearchDialog> createState() =>
      _CourseAssignSearchDialogState();
}

class _CourseAssignSearchDialogState
    extends State<CourseAssignSearchDialog> {
  final TextEditingController _searchController =
  TextEditingController();

  final Set<String> _selectedKeys = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _facultyKey(FacultyModel faculty) {
    return faculty.documentId?.isNotEmpty == true
        ? faculty.documentId!
        : faculty.facultyId;
  }

  Widget _buildAvatar(FacultyModel faculty) {
    if (widget.facultyAvatarBuilder != null) {
      return widget.facultyAvatarBuilder!(
        faculty,
        radius: 18,
      );
    }

    final String initial =
    faculty.fullName.trim().isEmpty
        ? '?'
        : faculty.fullName
        .trim()
        .substring(0, 1)
        .toUpperCase();

    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFEAF0FF),
      child: Text(
        initial,
        style: const TextStyle(
          color: ColorConst.primaryBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String searchTerm =
    _searchController.text.trim().toLowerCase();

    final List<FacultyModel> filtered =
    widget.faculties.where((faculty) {
      if (searchTerm.isEmpty) {
        return true;
      }

      return '${faculty.facultyId} '
          '${faculty.fullName} '
          '${faculty.email} '
          '${faculty.mobile}'
          .toLowerCase()
          .contains(searchTerm);
    }).toList()
      ..sort(
            (a, b) => a.fullName
            .toLowerCase()
            .compareTo(
          b.fullName.toLowerCase(),
        ),
      );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 900,
          maxHeight: 720,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                12,
                12,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: smcText(
                      textToDisplay:
                      'Search & Assign Faculty',
                      textSize: 18,
                      textBoldness: 5,
                      colorOfText:
                      ColorConst.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText:
                  'Search faculty...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                    borderSide:
                    const BorderSide(
                      color:
                      Color(0xFFE2E8F5),
                    ),
                  ),
                  enabledBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                    borderSide:
                    const BorderSide(
                      color:
                      Color(0xFFE2E8F5),
                    ),
                  ),
                  focusedBorder:
                  OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                    borderSide:
                    const BorderSide(
                      color:
                      ColorConst.primaryBlue,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: smcText(
                textToDisplay:
                '${_selectedKeys.length} selected · ${filtered.length} shown',
                textSize: 12,
                colorOfText:
                ColorConst.textSecondary,
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                child: smcText(
                  textToDisplay:
                  'No faculty available.',
                  textSize: 13,
                  colorOfText:
                  ColorConst
                      .textSecondary,
                ),
              )
                  : ListView.separated(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 12,
                ),
                itemCount:
                filtered.length,
                separatorBuilder:
                    (_, __) =>
                const Divider(
                  height: 1,
                ),
                itemBuilder:
                    (context, index) {
                  final FacultyModel
                  faculty =
                  filtered[index];

                  final String key =
                  _facultyKey(
                    faculty,
                  );

                  final bool
                  isSelected =
                  _selectedKeys
                      .contains(
                    key,
                  );

                  return CheckboxListTile(
                    value:
                    isSelected,
                    onChanged:
                        (checked) {
                      setState(
                            () {
                          if (checked ==
                              true) {
                            _selectedKeys
                                .add(
                              key,
                            );
                          } else {
                            _selectedKeys
                                .remove(
                              key,
                            );
                          }
                        },
                      );
                    },
                    controlAffinity:
                    ListTileControlAffinity
                        .leading,
                    title: Row(
                      children: [
                        _buildAvatar(
                          faculty,
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [
                              smcText(
                                textToDisplay:
                                faculty
                                    .fullName,
                                textSize:
                                13,
                                textBoldness:
                                4,
                                colorOfText:
                                ColorConst
                                    .textPrimary,
                                maxLines:
                                1,
                              ),

                              const SizedBox(
                                height:
                                2,
                              ),

                              smcText(
                                textToDisplay:
                                'Faculty ID: ${faculty.facultyId} • ${faculty.email}',
                                textSize:
                                12,
                                colorOfText:
                                ColorConst
                                    .textSecondary,
                                maxLines:
                                1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            Container(
              padding:
              const EdgeInsets.all(16),
              decoration:
              const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color:
                    Color(0xFFE3EAF8),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(
                          context,
                        ),
                    child:
                    const Text('Cancel'),
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(
                    onPressed:
                    _selectedKeys
                        .isEmpty
                        ? null
                        : () {
                      final List<
                          FacultyModel>
                      selected =
                      widget
                          .faculties
                          .where(
                            (
                            faculty,
                            ) =>
                            _selectedKeys.contains(
                              _facultyKey(
                                faculty,
                              ),
                            ),
                      )
                          .toList();

                      Navigator.pop(
                        context,
                        selected,
                      );
                    },
                    style:
                    ElevatedButton
                        .styleFrom(
                      backgroundColor:
                      ColorConst
                          .primaryBlue,
                      shape:
                      RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius
                            .circular(
                          10,
                        ),
                      ),
                    ),
                    child: smcText(
                      textToDisplay:
                      'Assign (${_selectedKeys.length})',
                      textSize: 14,
                      textBoldness: 4,
                      colorOfText:
                      Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}