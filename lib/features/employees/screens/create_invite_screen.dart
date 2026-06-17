import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/i18n/app_language.dart';
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
    try { final code = await _repo.createInvite(_role); if (mounted) setState(() => _generatedCode = code); }
    catch (e) { if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(friendlyError(e, fallback: context.tr('Invite code lama samayn karin. Fadlan mar kale isku day.', 'Could not generate invite code. Please try again.'))), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5))); } }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _copyCode() async {
    if (_generatedCode == null) return;
    await Clipboard.setData(ClipboardData(text: _generatedCode!));
    if (mounted) { ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Invite code waa la koobiyeeyay.', 'Invite code copied to clipboard.')), behavior: SnackBarBehavior.floating)); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.tr('Samee Invite Code', 'Create Invite Code'))),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text(context.tr('Dooro doorka shaqaalaha cusub, kadib samee invite code. La wadaag code-ka shaqaalaha — wuxuu gelinayaa marka uu akoon samaynayo.', 'Select the role for the new employee, then generate an invite code. Share the code with the employee — they enter it when signing up.'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 24),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Doorka shaqaalaha cusub', 'Role for new employee'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _RoleOption(value: 'seller', groupValue: _role, label: context.tr('Iibiye', 'Seller'), description: context.tr('Wuxuu isticmaali karaa POS, arki karaa alaab/macaamiil, wuxuuna gudbin karaa xiritaanka lacagta.', 'Can use POS, view products and customers, submit cash closing.'), onChanged: (v) => setState(() => _role = v!)),
            const Divider(height: 1),
            _RoleOption(value: 'manager', groupValue: _role, label: context.tr('Maamule', 'Manager'), description: context.tr('Wuxuu leeyahay awoodaha iibiyeha iyo maamulka dheeraadka ah.', 'Same as seller, with additional management access.'), onChanged: (v) => setState(() => _role = v!)),
          ]))),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: _loading ? null : _generate, icon: _loading ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.key_outlined), label: Text(context.tr('Samee Invite Code', 'Generate Invite Code'))),
          if (_generatedCode != null) ...[
            const SizedBox(height: 28),
            Card(color: cs.primaryContainer, child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
              Text('${context.tr('Invite Code', 'Invite Code')} (${_role.toUpperCase()})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
              const SizedBox(height: 12),
              Text(_generatedCode!, style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8, color: cs.primary)),
              const SizedBox(height: 8),
              Text(context.tr('Wuxuu shaqaynayaa 7 maalmood · Hal mar ayaa la isticmaalaa', 'Valid for 7 days · Single use'), style: TextStyle(fontSize: 12, color: cs.primary.withValues(alpha: 0.7))),
              const SizedBox(height: 16),
              Row(children: [Expanded(child: OutlinedButton.icon(onPressed: _copyCode, icon: const Icon(Icons.copy), label: Text(context.tr('Koobi garee', 'Copy Code')))), const SizedBox(width: 12), Expanded(child: FilledButton.icon(onPressed: () => _shareCode(context), icon: const Icon(Icons.share_outlined), label: Text(context.tr('Wadaag', 'Share'))))]),
            ]))),
            const SizedBox(height: 16),
            Card(child: ListTile(leading: const Icon(Icons.info_outline, color: Colors.blue), title: Text(context.tr('Sida loo isticmaalo code-kan', 'How to use this code')), subtitle: Text(context.tr('U dir code-ka "$_generatedCode" shaqaalaha cusub. Wuxuu furayaa app-ka, taabanayaa "Ku biir dukaan adigoo isticmaalaya invite code", kadibna wuxuu samaynayaa akoon.', 'Send the code "$_generatedCode" to the new employee. They open the app, tap "Join a store with invite code", enter this code, and create their account.')))),
          ],
        ]),
      ),
    );
  }

  void _shareCode(BuildContext context) {
    if (_generatedCode == null) return;
    final text = AppLanguage.instance.isSomali ? 'Invite code-ka Dukaan Dhisme POS waa: $_generatedCode\nFur app-ka, taabo "Ku biir dukaan adigoo isticmaalaya invite code", kadib geli code-kan. Wuxuu shaqaynayaa 7 maalmood.' : 'Your Dukaan Dhisme POS invite code is: $_generatedCode\nOpen the app, tap "Join a store with invite code", and enter this code to create your account. Valid for 7 days.';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(context.tr('Fariinta invite-ka waa la koobiyeeyay — ku paste garee WhatsApp ama SMS.', 'Invite message copied — paste it in WhatsApp or SMS.')), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.value, required this.groupValue, required this.label, required this.description, required this.onChanged});
  final String value;
  final String groupValue;
  final String label;
  final String description;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => RadioListTile<String>(value: value, groupValue: groupValue, onChanged: onChanged, title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(description, style: const TextStyle(fontSize: 12)), contentPadding: EdgeInsets.zero);
}
