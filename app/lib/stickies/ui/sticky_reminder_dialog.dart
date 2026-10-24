// © 2026 Tephra. All rights reserved.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../model/sticky_frontmatter.dart';
import '../model/sticky_meta.dart';

/// Shows a dialog to set, change, or remove a wall-clock reminder for a sticky note.
Future<Optional<LocalDateTime>?> showStickyReminderDialog(
  BuildContext context, {
  LocalDateTime? initialValue,
  DateTime? now,
}) {
  return showDialog<Optional<LocalDateTime>>(
    context: context,
    builder: (context) =>
        StickyReminderDialog(initialValue: initialValue, now: now),
  );
}

/// Dialog with quick reminder chips and Material date/time pickers.
class StickyReminderDialog extends StatelessWidget {
  const StickyReminderDialog({super.key, this.initialValue, this.now});

  final LocalDateTime? initialValue;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentNow = now ?? DateTime.now();

    return AlertDialog(
      title: Text(l10n.stickyReminderTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.timer_10, size: 18),
                  label: Text(l10n.stickyReminderIn10Minutes),
                  onPressed: () {
                    final target = currentNow.add(const Duration(minutes: 10));
                    Navigator.of(context).pop(
                      Optional.of(
                        LocalDateTime(
                          target.year,
                          target.month,
                          target.day,
                          target.hour,
                          target.minute,
                        ),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(l10n.stickyReminderIn1Hour),
                  onPressed: () {
                    final target = currentNow.add(const Duration(hours: 1));
                    Navigator.of(context).pop(
                      Optional.of(
                        LocalDateTime(
                          target.year,
                          target.month,
                          target.day,
                          target.hour,
                          target.minute,
                        ),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
                  label: Text(l10n.stickyReminderTomorrowMorning),
                  onPressed: () {
                    final tomorrow = currentNow.add(const Duration(days: 1));
                    Navigator.of(context).pop(
                      Optional.of(
                        LocalDateTime(
                          tomorrow.year,
                          tomorrow.month,
                          tomorrow.day,
                          9,
                          0,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_calendar),
              title: Text(
                initialValue != null
                    ? initialValue!.format().replaceFirst('T', ' ')
                    : l10n.stickyReminderTitle,
              ),
              subtitle: Text(l10n.propertyTypeDatetime),
              onTap: () async {
                final initialDate = initialValue != null
                    ? DateTime(
                        initialValue!.year,
                        initialValue!.month,
                        initialValue!.day,
                      )
                    : currentNow;

                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: initialDate,
                  firstDate: currentNow.subtract(const Duration(days: 365)),
                  lastDate: currentNow.add(const Duration(days: 3650)),
                );
                if (pickedDate == null || !context.mounted) return;

                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: initialValue != null
                      ? TimeOfDay(
                          hour: initialValue!.hour,
                          minute: initialValue!.minute,
                        )
                      : TimeOfDay(
                          hour: currentNow.hour,
                          minute: currentNow.minute,
                        ),
                );
                if (pickedTime == null || !context.mounted) return;

                Navigator.of(context).pop(
                  Optional.of(
                    LocalDateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    ),
                  ),
                );
              },
            ),
            if (initialValue != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: Text(
                  l10n.stickyReminderRemove,
                  style: const TextStyle(color: Colors.red),
                ),
                onPressed: () {
                  Navigator.of(context)
                      .pop(const Optional<LocalDateTime>.none());
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
