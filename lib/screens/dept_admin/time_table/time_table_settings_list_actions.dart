import 'package:flutter/material.dart';
import 'package:smartcampus/const/color_const.dart';

class TimeTableSettingsListActions extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TimeTableSettingsListActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onEdit,
          icon: const Icon(
            Icons.edit_outlined,
            size: 18,
            color: ColorConst.primaryBlue,
          ),
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(
            Icons.delete_outline,
            size: 18,
            color: Colors.red,
          ),
          tooltip: 'Delete',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
