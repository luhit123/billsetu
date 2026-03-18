import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/customer_group.dart';
import 'package:billeasy/services/customer_group_service.dart';
import 'package:flutter/material.dart';

class CustomerGroupSelection {
  const CustomerGroupSelection({
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;
}

Future<void> showCustomerGroupManagerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return const _CustomerGroupManagerSheet();
    },
  );
}

Future<CustomerGroupSelection?> showCustomerGroupPickerSheet(
  BuildContext context, {
  String initialGroupId = '',
}) {
  return showModalBottomSheet<CustomerGroupSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      return _CustomerGroupPickerSheet(initialGroupId: initialGroupId);
    },
  );
}

class _CustomerGroupManagerSheet extends StatelessWidget {
  const _CustomerGroupManagerSheet();

  @override
  Widget build(BuildContext context) {
    final groupService = CustomerGroupService();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StreamBuilder<List<CustomerGroup>>(
          stream: groupService.getGroupsStream(),
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <CustomerGroup>[];
            final s = AppStrings.of(context);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.groupsTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.groupsSubtitle,
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _openGroupDialog(context, groupService),
                      icon: const Icon(Icons.add),
                      label: Text(s.groupsAdd),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      s.groupsLoadError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (groups.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      s.groupsEmpty,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        height: 1.45,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.blueGrey.shade100),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE4F7F8),
                              foregroundColor: const Color(0xFF0F7D83),
                              child: Text(
                                group.name.trim().isEmpty
                                    ? '?'
                                    : group.name.trim()[0].toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            title: Text(
                              group.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              s.groupsRenameHint,
                              style: TextStyle(color: Colors.blueGrey.shade600),
                            ),
                            trailing: IconButton(
                              onPressed: () => _openGroupDialog(
                                context,
                                groupService,
                                group,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: s.groupsRenameTooltip,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openGroupDialog(
    BuildContext context,
    CustomerGroupService groupService, [
    CustomerGroup? initialGroup,
  ]) async {
    final controller = TextEditingController(text: initialGroup?.name ?? '');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final s = AppStrings.of(context);
            return AlertDialog(
              title: Text(initialGroup == null ? s.groupsAddTitle : s.groupsRenameTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: s.groupsNameLabel,
                  hintText: s.groupsNameHint,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: Text(s.groupsCancel),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = controller.text.trim();
                          if (name.isEmpty) {
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            await groupService.saveGroup(
                              CustomerGroup(
                                id: initialGroup?.id ?? '',
                                name: name,
                                createdAt: initialGroup?.createdAt,
                                updatedAt: initialGroup?.updatedAt,
                              ),
                            );

                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          } catch (error) {
                            if (!dialogContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(AppStrings.of(dialogContext).groupsFailedSave(error.toString())),
                              ),
                            );
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: Text(isSaving ? s.groupsSaving : s.groupsSave),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CustomerGroupPickerSheet extends StatelessWidget {
  const _CustomerGroupPickerSheet({required this.initialGroupId});

  final String initialGroupId;

  @override
  Widget build(BuildContext context) {
    final groupService = CustomerGroupService();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StreamBuilder<List<CustomerGroup>>(
          stream: groupService.getGroupsStream(),
          builder: (context, snapshot) {
            final groups = snapshot.data ?? const <CustomerGroup>[];
            final s = AppStrings.of(context);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.groupsPickerTitle,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.groupsPickerSubtitle,
                            style: TextStyle(
                              color: Colors.blueGrey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => showCustomerGroupManagerSheet(context),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: Text(s.groupsManage),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      s.groupsLoadError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else ...[
                  _GroupPickerTile(
                    icon: Icons.folder_off_outlined,
                    title: s.groupsUngrouped,
                    subtitle: s.groupsUngroupedSubtitle,
                    isSelected: initialGroupId.isEmpty,
                    onTap: () {
                      Navigator.of(context).pop(
                        const CustomerGroupSelection(
                          groupId: '',
                          groupName: '',
                        ),
                      );
                    },
                  ),
                  if (groups.isEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        s.groupsPickerEmpty,
                        style: TextStyle(
                          color: Colors.blueGrey.shade700,
                          height: 1.45,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: groups.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _GroupPickerTile(
                            icon: Icons.folder_open_rounded,
                            title: group.name,
                            subtitle: s.groupsMoveInto(group.name),
                            isSelected: initialGroupId == group.id,
                            onTap: () {
                              Navigator.of(context).pop(
                                CustomerGroupSelection(
                                  groupId: group.id,
                                  groupName: group.name,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroupPickerTile extends StatelessWidget {
  const _GroupPickerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEAF8FF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF123C85)
                  : Colors.blueGrey.shade100,
              width: isSelected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE4F7F8),
                foregroundColor: const Color(0xFF0F7D83),
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.blueGrey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: isSelected
                    ? const Color(0xFF123C85)
                    : Colors.blueGrey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
