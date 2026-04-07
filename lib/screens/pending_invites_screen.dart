import 'package:billeasy/modals/team_invite.dart';
import 'package:billeasy/screens/team_join_celebration_screen.dart';
import 'package:billeasy/services/profile_service.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/theme/app_colors.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:flutter/material.dart';

/// Shown after login when the user has pending team invites.
class PendingInvitesScreen extends StatefulWidget {
  const PendingInvitesScreen({super.key, this.onDone});

  /// Called when the user is done (accepted, declined, or skipped all invites).
  final VoidCallback? onDone;

  @override
  State<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends State<PendingInvitesScreen> {
  List<TeamInvite>? _invites;
  bool _loading = true;
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    try {
      final invites = await TeamService.instance.getPendingInvites();
      if (mounted) setState(() { _invites = invites; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _invites = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Invites'),
        actions: [
          TextButton(
            onPressed: widget.onDone,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invites == null || _invites!.isEmpty
              ? _buildEmpty()
              : _buildInviteList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mail_outline_rounded, size: 48, color: kTextTertiary),
          const SizedBox(height: 12),
          Text('No pending invites', style: TextStyle(color: kTextSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: widget.onDone,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _invites!.length,
      itemBuilder: (context, index) {
        final invite = _invites![index];
        final isProcessing = _processingId == invite.id;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kPrimary.withOpacity(0.12),
                      child: Icon(Icons.groups_rounded, color: kPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invite.teamBusinessName.isNotEmpty
                                ? invite.teamBusinessName
                                : 'A team',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          Text(
                            'Invited you as ${invite.role.displayName}',
                            style: TextStyle(color: kTextSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(invite.role.description, style: TextStyle(color: kTextSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isProcessing ? null : () => _decline(invite.id),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isProcessing ? null : () => _accept(invite.id),
                        child: isProcessing
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Accept'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _accept(String inviteId) async {
    // If the user has their own business data, warn them before joining
    final existingProfile = ProfileService.instance.cachedProfile;
    if (existingProfile != null && existingProfile.storeName.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Switch to team workspace?'),
          content: Text(
            'You currently have your own business "${existingProfile.storeName}". '
            'Joining this team will switch you to their workspace.\n\n'
            'Your own business data will be safely preserved and you can '
            'access it again by leaving the team.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Join Team'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    // Capture invite info before accepting (for celebration screen)
    final invite = _invites!.firstWhere((i) => i.id == inviteId);

    setState(() => _processingId = inviteId);
    try {
      await TeamService.instance.acceptInvite(inviteId);
      if (mounted) {
        // Show celebration, then proceed
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamJoinCelebrationScreen(
              memberName: invite.invitedName,
              roleName: invite.role.displayName,
              teamName: invite.teamBusinessName,
              onContinue: () => Navigator.pop(context),
            ),
          ),
        );
        if (mounted) widget.onDone?.call();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        String userMessage;
        if (msg.contains('already-exists') || msg.contains('already on a team')) {
          userMessage = 'You are already on a team. Leave your current team first from Settings → Team.';
        } else if (msg.contains('expired')) {
          userMessage = 'This invite has expired. Ask the owner to send a new one.';
        } else if (msg.contains('not-found')) {
          userMessage = 'This invite is no longer valid.';
        } else {
          userMessage = 'Failed to accept invite. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userMessage), duration: const Duration(seconds: 4)),
        );
        setState(() => _processingId = null);
      }
    }
  }

  Future<void> _decline(String inviteId) async {
    setState(() => _processingId = inviteId);
    try {
      await TeamService.instance.declineInvite(inviteId);
      _invites!.removeWhere((i) => i.id == inviteId);
      if (mounted) {
        setState(() => _processingId = null);
        if (_invites!.isEmpty) widget.onDone?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyError(e, fallback: 'Failed to process invite. Please try again.'))),
        );
        setState(() => _processingId = null);
      }
    }
  }
}
