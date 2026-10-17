import 'package:flutter/material.dart';
import '../../../core/i18n/app_language.dart';
import '../../../core/widgets/app_card.dart';
import '../../auth/models/app_profile.dart';
import '../data/workflow_guides.dart';
import 'guide_viewer_screen.dart';

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key, required this.profile});
  final AppProfile profile;

  @override
  Widget build(BuildContext context) {
    final guides = guidesForRole(profile.role);
    return AnimatedBuilder(
      animation: AppLanguage.instance,
      builder: (context, _) {
        final somali = AppLanguage.instance.isSomali;
        return Scaffold(
          appBar: AppBar(title: Text(context.tr('Sida ay u shaqeyso', 'How it works'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                context.tr(
                  'Hage ku saabsan sida loo isticmaalo app-ka. Waa sharaxaad kaliya, wax iib ah ma bedelayso.',
                  'Short guides on how to use the app. They are explanations only and do not change any sale or stock.',
                ),
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              for (final guide in guides)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideViewerScreen(guide: guide, role: profile.role))),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          Icon(guide.icon, size: 32, color: Theme.of(context).colorScheme.secondary),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(guide.title.of(somali), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text(guide.summary.of(somali), style: const TextStyle(color: Colors.black54)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
