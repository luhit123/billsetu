import 'dart:async';

import 'package:billeasy/l10n/app_strings.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/widgets/empty_state_widget.dart';
import 'package:billeasy/widgets/error_retry_widget.dart';
import 'package:billeasy/modals/client.dart';
import 'package:billeasy/modals/customer_group.dart';
import 'package:billeasy/screens/customer_details_screen.dart';
import 'package:billeasy/screens/customer_form_screen.dart';
import 'package:billeasy/services/client_service.dart';
import 'package:billeasy/services/customer_group_service.dart';
import 'package:billeasy/widgets/customer_groups_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';


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
  static const int _pageSize = 20;

  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedGroupFilterId = '';
  Timer? _searchDebounce;
  List<Client> _clients = [];
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMoreClients = true;
  bool _isLoadingClients = true;
  bool _isLoadingMoreClients = false;
  Object? _clientsLoadError;
  int _loadGeneration = 0;

  // Groups subscription replacing StreamBuilder wrapper
  StreamSubscription<List<CustomerGroup>>? _groupsSub;
  List<CustomerGroup> _groups = const [];
  Object? _groupsLoadError;

  @override
  void initState() {
    super.initState();
    _groupsSub = _groupService.getGroupsStream().listen(
      (groups) {
        if (mounted) setState(() { _groups = groups; _groupsLoadError = null; });
      },
      onError: (Object error) {
        if (mounted) setState(() => _groupsLoadError = error);
      },
    );
    _loadClients(reset: true);
  }

  @override
  void dispose() {
    _groupsSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final title = widget.selectionMode ? s.customersSelectTitle : s.customersTitle;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: kOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                cursorColor: kPrimary,
                style: const TextStyle(
                  color: kOnSurface,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: s.customersSearchHint,
                  hintStyle: const TextStyle(color: kTextTertiary),
                  border: InputBorder.none,
                ),
                onChanged: _handleSearchChanged,
              )
            : Text(
                title,
                style: const TextStyle(
                  color: kOnSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
        actions: [
          IconButton(
            onPressed: _manageGroups,
            icon: const Icon(Icons.folder_open_rounded, color: kOnSurfaceVariant),
            tooltip: s.customersManageGroupsTooltip,
          ),
          IconButton(
            onPressed: _toggleSearch,
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search,
              color: kOnSurfaceVariant,
            ),
            tooltip: _isSearching ? s.customersCloseSearch : s.customersSearchTooltip,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingClients && _clients.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: kPrimary),
              )
            : RefreshIndicator(
                onRefresh: () => _loadClients(reset: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _CustomersIntroCard(selectionMode: widget.selectionMode),
                    if (_groups.isNotEmpty || _selectedGroupFilterId.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _GroupsToolbar(
                        groups: _groups,
                        selectedGroupFilterId: _selectedGroupFilterId,
                        onSelected: (value) {
                          setState(() {
                            _selectedGroupFilterId = value;
                          });
                          _loadClients(reset: true);
                        },
                        onManageGroups: _manageGroups,
                      ),
                    ],
                    if (_groupsLoadError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        s.customersGroupsError,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (_clientsLoadError != null && _clients.isEmpty) ...[
                      const SizedBox(height: 16),
                      ErrorRetryWidget(
                        message: 'Could not load customers.\nCheck your connection and try again.',
                        onRetry: () => _loadClients(reset: true),
                      ),
                    ] else if (_clients.isEmpty) ...[
                      const SizedBox(height: 16),
                      if (!_searchQuery.isNotEmpty && !_selectedGroupFilterId.isNotEmpty && !widget.selectionMode)
                        EmptyStateWidget(
                          icon: Icons.people_outline,
                          title: 'No customers yet',
                          subtitle: 'Add your first customer to get started',
                          actionLabel: 'Add Customer',
                          iconColor: kPrimary,
                          onAction: _openCustomerForm,
                        )
                      else
                        _EmptyCustomersState(
                          selectionMode: widget.selectionMode,
                          hasSearchQuery: _searchQuery.isNotEmpty,
                          searchQuery: _searchQuery,
                          hasGroupFilter: _selectedGroupFilterId.isNotEmpty,
                          onAddCustomer: _openCustomerForm,
                        ),
                    ] else ...[
                      const SizedBox(height: 16),
                      ..._clients.map((client) {
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
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _hasMoreClients && !_isLoadingMoreClients
                              ? () => _loadClients(reset: false)
                              : null,
                          child: _isLoadingMoreClients
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _hasMoreClients
                                      ? 'Load more customers'
                                      : 'No more customers',
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: widget.selectionMode ? 'pick-customer-fab' : 'customers-fab',
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        elevation: 2,
        onPressed: _openCustomerForm,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(AppStrings.of(context).customersAddButton),
      ),
    );
  }

  void _toggleSearch() {
    var shouldReload = false;
    setState(() {
      if (_isSearching) {
        _searchDebounce?.cancel();
        _searchController.clear();
        _searchQuery = '';
        shouldReload = true;
      }
      _isSearching = !_isSearching;
    });
    if (shouldReload) {
      _loadClients(reset: true);
    }
  }

  Future<void> _manageGroups() async {
    await showCustomerGroupManagerSheet(context);

    if (!mounted) {
      return;
    }

    setState(() {});
    await _loadClients(reset: true);
  }

  Future<void> _openCustomerForm() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text('Add Customer',
                style: TextStyle(color: kOnSurface, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _AddOptionTile(
              icon: Icons.contacts_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'From Contacts',
              subtitle: 'Import from your phone book',
              onTap: () {
                Navigator.pop(ctx, 'contacts');
              },
            ),
            const Divider(height: 1, color: kSurfaceContainerLow),
            _AddOptionTile(
              icon: Icons.edit_rounded,
              iconColor: kPrimary,
              title: 'Add Manually',
              subtitle: 'Enter customer details yourself',
              onTap: () {
                Navigator.pop(ctx, 'manual');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((result) async {
      if (!mounted || result == null) return;
      if (result == 'contacts') {
        await _importFromContacts();
      } else if (result == 'manual') {
        await _navigateToForm();
      }
    });
  }

  Future<void> _importFromContacts() async {
    // Open native contact picker (no permission needed — uses system UI)
    final contact = await FlutterContacts.openExternalPick();
    if (contact == null || !mounted) return;

    // Try to get full details (needs READ_CONTACTS permission)
    Contact? fullContact;
    if (await FlutterContacts.requestPermission()) {
      fullContact = await FlutterContacts.getContact(contact.id,
          withProperties: true, withAccounts: false, withPhoto: false);
    }

    if (!mounted) return;

    // Use full contact if available, otherwise fall back to picked contact
    final source = fullContact ?? contact;

    final phone = source.phones.isNotEmpty
        ? source.phones.first.number.replaceAll(RegExp(r'[\s\-()]'), '')
        : '';
    final email = source.emails.isNotEmpty
        ? source.emails.first.address
        : '';
    final address = source.addresses.isNotEmpty
        ? source.addresses.first.address
        : '';

    final prefilled = Client(
      id: '',
      name: source.displayName,
      phone: phone,
      email: email,
      address: address,
    );

    await _navigateToForm(initialClient: prefilled);
  }

  Future<void> _navigateToForm({Client? initialClient}) async {
    final savedClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(initialClient: initialClient),
      ),
    );

    if (!mounted || savedClient == null) return;

    if (widget.selectionMode) {
      Navigator.of(context).pop(savedClient);
      return;
    }

    await _loadClients(reset: true);
    if (!mounted) return;

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
    if (!mounted) {
      return;
    }
    await _loadClients(reset: true);
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _searchQuery = value.trim();
      });
      _loadClients(reset: true);
    });
  }

  Future<void> _loadClients({required bool reset}) async {
    if (_isLoadingMoreClients) {
      return;
    }

    if (!reset && !_hasMoreClients) {
      return;
    }

    final generation = reset ? ++_loadGeneration : _loadGeneration;

    if (reset) {
      setState(() {
        _isLoadingClients = true;
        _isLoadingMoreClients = false;
        _clientsLoadError = null;
        _hasMoreClients = true;
        _lastDocument = null;
      });
    } else {
      setState(() {
        _isLoadingMoreClients = true;
      });
    }

    try {
      final page = await _clientService.getClientsPage(
        searchQuery: _searchQuery,
        groupId: _selectedGroupFilterId,
        limit: _pageSize,
        startAfterDocument: reset ? null : _lastDocument,
      );

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _clients = reset ? page.items : [..._clients, ...page.items];
        _lastDocument = page.cursor;
        _hasMoreClients = page.hasMore;
        _clientsLoadError = null;
        _isLoadingClients = false;
        _isLoadingMoreClients = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _clientsLoadError = error;
        _isLoadingClients = false;
        _isLoadingMoreClients = false;
        if (reset) {
          _clients = [];
        }
      });
    }
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

      await _loadClients(reset: true);
      if (!mounted) {
        return;
      }

      final s = AppStrings.of(context);
      final message = updatedClient.groupName.trim().isEmpty
          ? s.customersNowUngrouped(updatedClient.name)
          : s.customersMovedToGroup(updatedClient.name, updatedClient.groupName);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

      await _loadClients(reset: true);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).customersDeletedCustomer(client.name))),
      );
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

// --- Intro card ---

class _CustomersIntroCard extends StatelessWidget {
  const _CustomersIntroCard({required this.selectionMode});

  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [kWhisperShadow],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: kPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectionMode
                      ? s.customersSelectIntroTitle
                      : s.customersIntroTitle,
                  style: const TextStyle(
                    color: kOnSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectionMode
                      ? s.customersSelectIntroBody
                      : s.customersIntroBody,
                  style: const TextStyle(
                    color: kOnSurfaceVariant,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Groups toolbar ---

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
    if (groups.isEmpty && selectedGroupFilterId.isEmpty) {
      return const SizedBox.shrink();
    }
    return _GroupFilterBar(
      groups: groups,
      selectedGroupFilterId: selectedGroupFilterId,
      onSelected: onSelected,
    );
  }
}

// --- Group filter bar ---

class _GroupFilterBar extends StatelessWidget {
  const _GroupFilterBar({
    required this.groups,
    required this.selectedGroupFilterId,
    required this.onSelected,
  });

  final List<CustomerGroup> groups;
  final String selectedGroupFilterId;
  final ValueChanged<String> onSelected;

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kPrimary : kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kOnSurfaceVariant,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            label: s.customersAll,
            selected: selectedGroupFilterId.isEmpty,
            onTap: () => onSelected(''),
          ),
          if (groups.isNotEmpty) ...[
            const SizedBox(width: 8),
            _chip(
              label: s.customersUngrouped,
              selected: selectedGroupFilterId == '__ungrouped__',
              onTap: () => onSelected('__ungrouped__'),
            ),
          ],
          ...groups.map((group) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _chip(
                label: group.name,
                selected: selectedGroupFilterId == group.id,
                onTap: () => onSelected(group.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// --- Customer card ---

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
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? kPrimaryContainer : kSurfaceLowest,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [kSubtleShadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: kSurfaceContainerLow,
                  child: Text(
                    client.initials,
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        client.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kOnSurface,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: kOnSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Group badge + trailing
                if (groupName.isNotEmpty && !isSelected)
                  Flexible(
                    flex: 0,
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      constraints: const BoxConstraints(maxWidth: 100),
                      decoration: BoxDecoration(
                        color: kPrimaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        groupName,
                        style: const TextStyle(
                          color: kPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: kPrimaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      AppStrings.of(context).customersSelected,
                      style: const TextStyle(
                        color: kPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Icon(
                    selectionMode
                        ? Icons.check_circle_outline_rounded
                        : Icons.chevron_right_rounded,
                    size: 20,
                    color: kOnSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Empty state ---

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
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: kSurfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  size: 36,
                  color: kPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: kOnSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: kOnSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
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

class _AddOptionTile extends StatelessWidget {
  const _AddOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(color: kOnSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(color: kOnSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: kTextTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
