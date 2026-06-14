import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/errors.dart';
import '../data/employee_repository.dart';

class CreateInviteScreen extends StatefulWidget {
  const CreateInviteScreen({super.key});

  @override
  State<CreateInviteScreen> createState() => _CreateInviteScreenState();
}

class _CreateInviteScreenState extends State<CreateInviteScreen> {
  final _repo = EmployeeRepository();
  String _role = 'seller';
  bool _loading = false;
  String? _generatedCode;

  Future<void> _generate() async {
    setState(() { _loading = true; _generatedCode = null; });
    try {
      final code = await _repo.createInvite(_role);
      if (mounted) setState(() => _generatedCode = code);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e,
                fallback: 'Could not generate invite code. Please try again.')),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copyCode() async {
    if (_generatedCode == null) return;
    await Clipboard.setData(ClipboardData(text: _generatedCode!));
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('Invite code copied to clipboard.'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Invite Code')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Select the role for the new employee, then generate an invite code. '
            'Share the code with the employee — they enter it when signing up.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),

          // Role selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Role for new employee',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _RoleOption(
                    value: 'seller',
                    groupValue: _role,
                    label: 'Seller',
                    description: 'Can use POS, view products and customers, submit cash closing.',
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                  const Divider(height: 1),
                  _RoleOption(
                    value: 'manager',
                    groupValue: _role,
                    label: 'Manager',
                    description: 'Same as seller, with additional management access in Phase 4.',
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.key_outlined),
            label: const Text('Generate Invite Code'),
          ),

          if (_generatedCode != null) ...[
            const SizedBox(height: 28),
            Card(
              color: cs.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Invite Code (${_role.toUpperCase()})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _generatedCode!,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Valid for 7 days · Single use',
                      style: TextStyle(fontSize: 12, color: cs.primary.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _copyCode,
                            icon: const Icon(Icons.copy),
                            label: const Text('Copy Code'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _shareCode(context),
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: const Text('How to use this code'),
                subtitle: Text(
                  'Send the code "$_generatedCode" to the new employee. '
                  'They open the app, tap "Join a store with invite code", '
                  'enter this code, and create their account.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _shareCode(BuildContext context) {
    if (_generatedCode == null) return;
    final text = 'Your Dhisme POS invite code is: $_generatedCode\n'
        'Open the app, tap "Join a store with invite code", and enter this code to create your account. '
        'Valid for 7 days.';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        content: Text('Invite message copied — paste it in WhatsApp or SMS.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.description,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final String label;
  final String description;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(description, style: const TextStyle(fontSize: 12)),
      contentPadding: EdgeInsets.zero,
    );
  }
}
