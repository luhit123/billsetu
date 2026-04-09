import 'package:billeasy/modals/team_role.dart';
import 'package:billeasy/services/team_service.dart';
import 'package:billeasy/utils/error_helpers.dart';
import 'package:flutter/material.dart';

class TeamInviteScreen extends StatefulWidget {
  const TeamInviteScreen({super.key});

  @override
  State<TeamInviteScreen> createState() => _TeamInviteScreenState();
}

class _TeamInviteScreenState extends State<TeamInviteScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  TeamRole _selectedRole = TeamRole.sales;
  bool _isSending = false;

  bool get _canInviteCoOwner {
    final role = TeamService.instance.currentRole;
    return role == TeamRole.owner || role == TeamRole.coOwner;
  }

  List<TeamRole> get _availableRoles => TeamRole.values
      .where((role) => role != TeamRole.owner)
      .where((role) => _canInviteCoOwner || role != TeamRole.coOwner)
      .toList();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let the Scaffold handle keyboard insets natively — this ensures
      // the focused TextField scrolls into view on mobile web instead of
      // disappearing behind the soft keyboard.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Invite Member')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Member Name *',
                  hintText: 'e.g. Rahul Sharma',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+91 98765 43210',
                  prefixIcon: Icon(Icons.phone_rounded),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'member@example.com',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              Text('Role', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              RadioGroup<TeamRole>(
                groupValue: _selectedRole,
                onChanged: (v) => setState(() {
                  if (v != null) _selectedRole = v;
                }),
                child: Column(
                  children: _availableRoles.map(
                    (role) => RadioListTile<TeamRole>(
                      value: role,
                      title: Text(role.displayName),
                      subtitle: Text(
                        role.description,
                        style: const TextStyle(fontSize: 12),
                      ),
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ).toList(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ? null : _sendInvite,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Invite'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
  }

  Future<void> _sendInvite() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member name is required')));
      return;
    }

    if (phone.isEmpty && email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a phone number or email')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await TeamService.instance.inviteMember(
        name: name,
        phone: phone,
        email: email,
        role: _selectedRole,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invite sent!')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(userFriendlyError(e, fallback: 'Failed to send invite. Please try again.'))));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
