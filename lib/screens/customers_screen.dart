import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/customer_group.dart';
import 'package:billeasy/screens/customer_details_screen.dart';
import 'package:billeasy/screens/customer_form_screen.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/customer_group_service.dart';
import 'package:billeasy/widgets/customer_groups_sheet.dart';
import 'package:flutter/material.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({
    super.key,
    this.selectionMode = false,
    this.preselectedClientId,
  });

  final bool selectionMode;
  final String? preselectedClientId;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final ClientService _clientService = ClientService();
  final CustomerGroupService _groupService = CustomerGroupService();
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedGroupFilterId = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final title = widget.selectionMode ? s.customersSelectTitle : s.customersTitle;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                cursorColor: Colors.white,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: s.customersSearchHint,
                  hintStyle: TextStyle(color: Colors.white.withAlpha(170)),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim();
                  });
                },
              )
            : Text(title),
        actions: [
          IconButton(
            onPressed: _manageGroups,
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: s.customersManageGroupsTooltip,
          ),
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search),
            tooltip: _isSearching ? s.customersCloseSearch : s.customersSearchTooltip,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFEAF3FF), Color(0xFFF5FBFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: StreamBuilder<List<CustomerGroup>>(
            stream: _groupService.getGroupsStream(),
            builder: (context, groupSnapshot) {
              final groups = groupSnapshot.data ?? const <CustomerGroup>[];

              return StreamBuilder<List<Client>>(
                stream: _clientService.getClientsStream(
                  searchQuery: _searchQuery,
                  groupId: _selectedGroupFilterId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          s.customersLoadError,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final clients = snapshot.data ?? const <Client>[];

                  if (clients.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _CustomersIntroCard(
                          selectionMode: widget.selectionMode,
                        ),
                        if (groups.isNotEmpty ||
                            _selectedGroupFilterId.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _GroupFilterBar(
                            groups: groups,
                            selectedGroupFilterId: _selectedGroupFilterId,
                            onSelected: (value) {
                              setState(() {
                                _selectedGroupFilterId = value;
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        _EmptyCustomersState(
                          selectionMode: widget.selectionMode,
                          hasSearchQuery: _searchQuery.isNotEmpty,
                          searchQuery: _searchQuery,
                          hasGroupFilter: _selectedGroupFilterId.isNotEmpty,
                          onAddCustomer: _openCustomerForm,
                        ),
                      ],
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _CustomersIntroCard(selectionMode: widget.selectionMode),
                      const SizedBox(height: 16),
                      _GroupsToolbar(
                        groups: groups,
                        selectedGroupFilterId: _selectedGroupFilterId,
                        onSelected: (value) {
                          setState(() {
                            _selectedGroupFilterId = value;
                          });
                        },
                        onManageGroups: _manageGroups,
                      ),
                      if (groupSnapshot.hasError) ...[
                        const SizedBox(height: 10),
                        Text(
                          s.customersGroupsError,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ...clients.map((client) {
                        return _CustomerCard(
                          client: client,
                          isSelected: client.id == widget.preselectedClientId,
                          selectionMode: widget.selectionMode,
                          onTap: () => _handleClientTap(client),
                          onLongPress: widget.selectionMode
                              ? null
                              : () => _showCustomerActions(client),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: widget.selectionMode ? 'pick-customer-fab' : 'customers-fab',
        onPressed: _openCustomerForm,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(AppStrings.of(context).customersAddButton),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
      _isSearching = !_isSearching;
    });
  }

  Future<void> _manageGroups() async {
    await showCustomerGroupManagerSheet(context);

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _openCustomerForm() async {
    final savedClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
    );

    if (!mounted || savedClient == null) {
      return;
    }

    if (widget.selectionMode) {
      Navigator.of(context).pop(savedClient);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.of(context).customersReadyForBilling(savedClient.name))),
    );
  }

  Future<void> _handleClientTap(Client client) async {
    if (widget.selectionMode) {
      Navigator.of(context).pop(client);
      return;
    }

    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailsScreen(client: client)),
    );
  }

  Future<void> _showCustomerActions(Client client) async {
    final action = await showModalBottomSheet<_CustomerAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final s = AppStrings.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_open_rounded),
                  title: Text(
                    client.groupId.isEmpty ? s.customersMoveToGroup : s.customersChangeGroup,
                  ),
                  subtitle: Text(
                    client.groupName.trim().isEmpty
                        ? s.customersNoGroupSubtitle
                        : s.customersCurrentGroup(client.groupName.trim()),
                  ),
                  onTap: () =>
                      Navigator.of(context).pop(_CustomerAction.moveToGroup),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFB3261E),
                  ),
                  title: Text(
                    s.customersDeleteTitle,
                    style: const TextStyle(color: Color(0xFFB3261E)),
                  ),
                  subtitle: Text(s.customersDeleteSubtitle),
                  onTap: () =>
                      Navigator.of(context).pop(_CustomerAction.delete),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    if (action == _CustomerAction.moveToGroup) {
      await _moveCustomerToGroup(client);
      return;
    }

    await _confirmDeleteCustomer(client);
  }

  Future<void> _moveCustomerToGroup(Client client) async {
    final selection = await showCustomerGroupPickerSheet(
      context,
      initialGroupId: client.groupId,
    );

    if (!mounted || selection == null) {
      return;
    }

    if (selection.groupId == client.groupId &&
        selection.groupName == client.groupName) {
      return;
    }

    try {
      final updatedClient = await _clientService.updateClientGroup(
        client: client,
        groupId: selection.groupId,
        groupName: selection.groupName,
      );

      if (!mounted) {
        return;
      }

      final s = AppStrings.of(context);
      final message = updatedClient.groupName.trim().isEmpty
          ? s.customersNowUngrouped(updatedClient.name)
          : s.customersMovedToGroup(updatedClient.name, updatedClient.groupName);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).customersFailedUpdateGroup(error.toString()))),
      );
    }
  }

  Future<void> _confirmDeleteCustomer(Client client) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final s = AppStrings.of(dialogContext);
        return AlertDialog(
          title: Text(s.customersDeleteTitle),
          content: Text(s.customersDeleteConfirm(client.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.customersCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB3261E),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.customersDelete),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    try {
      await _clientService.deleteClient(client.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppStrings.of(context).customersDeletedCustomer(client.name))));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).customersFailedDelete(error.toString()))),
      );
    }
  }
}

enum _CustomerAction { moveToGroup, delete }

class _CustomersIntroCard extends StatelessWidget {
  const _CustomersIntroCard({required this.selectionMode});

  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF123C85), Color(0xFF0F7D83)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selectionMode
                ? s.customersSelectIntroTitle
                : s.customersIntroTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            selectionMode
                ? s.customersSelectIntroBody
                : s.customersIntroBody,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupsToolbar extends StatelessWidget {
  const _GroupsToolbar({
    required this.groups,
    required this.selectedGroupFilterId,
    required this.onSelected,
    required this.onManageGroups,
  });

  final List<CustomerGroup> groups;
  final String selectedGroupFilterId;
  final ValueChanged<String> onSelected;
  final VoidCallback onManageGroups;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDDE7F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.of(context).customersGroupsLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF123C85),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onManageGroups,
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(AppStrings.of(context).customersManage),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _GroupFilterBar(
            groups: groups,
            selectedGroupFilterId: selectedGroupFilterId,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _GroupFilterBar extends StatelessWidget {
  const _GroupFilterBar({
    required this.groups,
    required this.selectedGroupFilterId,
    required this.onSelected,
  });

  final List<CustomerGroup> groups;
  final String selectedGroupFilterId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text(AppStrings.of(context).customersAll),
          selected: selectedGroupFilterId.isEmpty,
          onSelected: (_) => onSelected(''),
          showCheckmark: false,
        ),
        if (groups.isNotEmpty)
          ChoiceChip(
            label: Text(AppStrings.of(context).customersUngrouped),
            selected: selectedGroupFilterId == '__ungrouped__',
            onSelected: (_) => onSelected('__ungrouped__'),
            showCheckmark: false,
          ),
        ...groups.map((group) {
          return ChoiceChip(
            label: Text(group.name),
            selected: selectedGroupFilterId == group.id,
            onSelected: (_) => onSelected(group.id),
            showCheckmark: false,
          );
        }),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.client,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    this.onLongPress,
  });

  final Client client;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final subtitle = client.subtitle;
    final groupName = client.groupName.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withAlpha(24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0F7D83)
                    : const Color(0xFFD7E2F3),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE4F7F8),
                  foregroundColor: const Color(0xFF0F7D83),
                  child: Text(
                    client.initials,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (groupName.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            groupName,
                            style: const TextStyle(
                              color: Color(0xFF123C85),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        client.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.blueGrey.shade700,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3FBF7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      AppStrings.of(context).customersSelected,
                      style: const TextStyle(
                        color: Color(0xFF0F7D83),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Icon(
                    selectionMode
                        ? Icons.check_circle_outline_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: Colors.blueGrey.shade400,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCustomersState extends StatelessWidget {
  const _EmptyCustomersState({
    required this.selectionMode,
    required this.hasSearchQuery,
    required this.searchQuery,
    required this.hasGroupFilter,
    required this.onAddCustomer,
  });

  final bool selectionMode;
  final bool hasSearchQuery;
  final String searchQuery;
  final bool hasGroupFilter;
  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final title = hasSearchQuery
        ? s.customersEmptySearchTitle(searchQuery)
        : hasGroupFilter
        ? s.customersEmptyGroupTitle
        : selectionMode
        ? s.customersEmptySelectTitle
        : s.customersEmptyTitle;
    final description = hasSearchQuery
        ? s.customersEmptySearchBody
        : hasGroupFilter
        ? s.customersEmptyGroupBody
        : selectionMode
        ? s.customersEmptySelectBody
        : s.customersEmptyBody;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF123C85), Color(0xFF0F7D83)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  size: 42,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF123C85),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.blueGrey.shade700,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAddCustomer,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(s.customersAddButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
