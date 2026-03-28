import 'dart:async';

import 'package:billeasy/modals/member.dart';
import 'package:billeasy/screens/member_detail_screen.dart';
import 'package:billeasy/screens/member_form_screen.dart';
import 'package:billeasy/services/membership_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:flutter/material.dart';

enum _MemberFilter { all, active, expiringSoon, expired, frozen }

class MembersScreen extends StatefulWidget {
  /// When [planId] is provided the screen shows only members of that plan
  /// and the title reflects [planName].
  const MembersScreen({super.key, this.planId, this.planName});

  final String? planId;
  final String? planName;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final MembershipService _membershipService = MembershipService();
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _searchDebounce;
  _MemberFilter _activeFilter = _MemberFilter.all;

  StreamSubscription<List<Member>>? _membersSub;
  List<Member> _allMembers = [];
  bool _isLoading = true;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _membersSub = _membershipService.watchMembers().listen(
      (members) {
        if (mounted) {
          setState(() {
            _allMembers = members;
            _isLoading = false;
            _loadError = null;
          });
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _loadError = error;
            _isLoading = false;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _membersSub?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Member> get _filteredMembers {
    final now = DateTime.now();
    List<Member> filtered;

    // If opened from a plan card, restrict to that plan's members only.
    final base = widget.planId != null
        ? _allMembers.where((m) => m.planId == widget.planId).toList()
        : _allMembers;

    switch (_activeFilter) {
      case _MemberFilter.all:
        filtered = base;
      case _MemberFilter.active:
        filtered = base
            .where((m) => m.status == MemberStatus.active && m.endDate.isAfter(now))
            .toList();
      case _MemberFilter.expiringSoon:
        filtered = base.where((m) {
          if (m.status != MemberStatus.active) return false;
          final daysLeft = m.endDate.difference(now).inDays;
          return daysLeft >= 0 && daysLeft <= 7;
        }).toList();
      case _MemberFilter.expired:
        filtered = base.where((m) => m.endDate.isBefore(now)).toList();
      case _MemberFilter.frozen:
        filtered = base
            .where((m) => m.status == MemberStatus.frozen)
            .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered
          .where((m) => m.name.toLowerCase().contains(query))
          .toList();
    }

    return filtered;
  }

  int _countForFilter(_MemberFilter filter) {
    final now = DateTime.now();
    final base = widget.planId != null
        ? _allMembers.where((m) => m.planId == widget.planId).toList()
        : _allMembers;
    switch (filter) {
      case _MemberFilter.all:
        return base.length;
      case _MemberFilter.active:
        return base
            .where((m) => m.status == MemberStatus.active && m.endDate.isAfter(now))
            .length;
      case _MemberFilter.expiringSoon:
        return base.where((m) {
          if (m.status != MemberStatus.active) return false;
          final daysLeft = m.endDate.difference(now).inDays;
          return daysLeft >= 0 && daysLeft <= 7;
        }).length;
      case _MemberFilter.expired:
        return base.where((m) => m.endDate.isBefore(now)).length;
      case _MemberFilter.frozen:
        return base
            .where((m) => m.status == MemberStatus.frozen)
            .length;
    }
  }

  void _toggleSearch() {
    setState(() {
      if (_isSearching) {
        _searchDebounce?.cancel();
        _searchController.clear();
        _searchQuery = '';
      }
      _isSearching = !_isSearching;
    });
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim();
      });
    });
  }

  Future<void> _openMemberForm() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const MemberFormScreen()),
    );
  }

  void _openMemberDetail(Member member) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => MemberDetailScreen(member: member)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final members = _filteredMembers;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: _isSearching
          ? AppBar(
              backgroundColor: kSurface,
              foregroundColor: kOnSurface,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              title: TextField(
                controller: _searchController,
                autofocus: true,
                cursorColor: kPrimary,
                style: const TextStyle(
                  color: kOnSurface,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: const TextStyle(color: kTextTertiary),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search, color: kTextTertiary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _handleSearchChanged('');
                          },
                          icon: const Icon(Icons.close_rounded, color: kOnSurfaceVariant),
                        )
                      : null,
                ),
                onChanged: _handleSearchChanged,
              ),
              actions: [
                IconButton(
                  onPressed: _toggleSearch,
                  icon: const Icon(Icons.close_rounded, color: kOnSurfaceVariant),
                  tooltip: 'Close search',
                ),
              ],
            )
          : kBuildGradientAppBar(
              titleText: widget.planName ?? 'Members',
              actions: [
                IconButton(
                  onPressed: _toggleSearch,
                  icon: const Icon(Icons.search, color: kOnSurfaceVariant),
                  tooltip: 'Search members',
                ),
              ],
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: kPrimary))
            : _loadError != null && _allMembers.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: kOverdue),
                          const SizedBox(height: 16),
                          const Text(
                            'Could not load members',
                            style: TextStyle(
                              color: kOnSurface,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check your connection and try again.',
                            style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: kPrimary),
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _loadError = null;
                              });
                              _membersSub?.cancel();
                              _membersSub = _membershipService.watchMembers().listen(
                                (members) {
                                  if (mounted) {
                                    setState(() {
                                      _allMembers = members;
                                      _isLoading = false;
                                      _loadError = null;
                                    });
                                  }
                                },
                                onError: (Object error) {
                                  if (mounted) {
                                    setState(() {
                                      _loadError = error;
                                      _isLoading = false;
                                    });
                                  }
                                },
                              );
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _allMembers.isEmpty
                    ? _buildEmptyState()
                    : Column(
                        children: [
                          _buildFilterChips(),
                          Expanded(
                            child: members.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.filter_list_off_rounded,
                                            size: 48,
                                            color: kTextTertiary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _searchQuery.isNotEmpty
                                                ? 'No members matching "$_searchQuery"'
                                                : 'No members in this category',
                                            style: const TextStyle(
                                              color: kOnSurface,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                    itemCount: members.length,
                                    itemBuilder: (context, index) {
                                      return _MemberCard(
                                        member: members[index],
                                        onTap: () => _openMemberDetail(members[index]),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
      ),
      floatingActionButton: Container(
        decoration: const BoxDecoration(
          gradient: kSignatureGradient,
          shape: BoxShape.circle,
          boxShadow: [kWhisperShadow],
        ),
        child: FloatingActionButton(
          heroTag: 'members-fab',
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          highlightElevation: 0,
          onPressed: _openMemberForm,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: kSurfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_outlined,
                size: 40,
                color: kPrimary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No members yet',
              style: TextStyle(
                color: kOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start managing your memberships by adding your first member.',
              style: TextStyle(
                color: kOnSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _openMemberForm,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add your first member'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: _MemberFilter.values.map((filter) {
          final isSelected = _activeFilter == filter;
          final count = _countForFilter(filter);
          final label = switch (filter) {
            _MemberFilter.all => 'All',
            _MemberFilter.active => 'Active',
            _MemberFilter.expiringSoon => 'Expiring Soon',
            _MemberFilter.expired => 'Expired',
            _MemberFilter.frozen => 'Frozen',
          };

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _activeFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected ? kSignatureGradient : null,
                  color: isSelected ? null : kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : kOnSurfaceVariant,
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : kSurfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isSelected ? Colors.white : kOnSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Member Card ────────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.onTap,
  });

  final Member member;
  final VoidCallback onTap;

  Color _statusColor(Member m) {
    if (m.status == MemberStatus.frozen) return const Color(0xFF3B82F6);
    if (m.endDate.isBefore(DateTime.now())) return kOverdue;
    final daysLeft = m.endDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 7) return kPending;
    return kPaid;
  }

  Color _statusBgColor(Member m) {
    if (m.status == MemberStatus.frozen) return const Color(0xFFDBEAFE);
    if (m.endDate.isBefore(DateTime.now())) return kOverdueBg;
    final daysLeft = m.endDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 7) return kPendingBg;
    return kPaidBg;
  }

  String _statusLabel(Member m) {
    if (m.status == MemberStatus.frozen) return 'Frozen';
    if (m.endDate.isBefore(DateTime.now())) return 'Expired';
    final daysLeft = m.endDate.difference(DateTime.now()).inDays;
    if (daysLeft <= 7) return 'Expiring Soon';
    return 'Active';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(member);
    final statusBg = _statusBgColor(member);
    final statusLabel = _statusLabel(member);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kSurfaceLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kWhisperShadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar with initials
                CircleAvatar(
                  radius: 22,
                  backgroundColor: kPrimaryContainer,
                  child: Text(
                    member.initials,
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name, plan, days left
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kOnSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (member.planName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          member.planName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: kOnSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        member.daysLeftLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
