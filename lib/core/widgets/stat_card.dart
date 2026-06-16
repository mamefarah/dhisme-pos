import 'package:flutter/material.dart';
import 'app_card.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, this.icon, this.color, this.onTap});
  final String title;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon ?? Icons.analytics_outlined, color: color ?? Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.bodyMedium)),
          ]),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
