import 'package:flutter/material.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/errors.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationsRepository();
  late Future<List<Map<String, dynamic>>> _future;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _future = _repo.listNotifications());

  Future<void> _markAll() async {
    setState(() => _markingAll = true);
    try {
      await _repo.markAllAsRead();
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(friendlyError(e, fallback: 'Could not mark notifications as read.')),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _tapNotification(Map<String, dynamic> n) async {
    if (n['is_read'] == true) return;
    try {
      await _repo.markAsRead(n['id'] as String);
      _reload();
    } catch (_) {}
  }

  IconData _icon(String? type) {
    switch (type) {
      case 'approval':          return Icons.approval_outlined;
      case 'approval_decision': return Icons.check_circle_outline;
      case 'cash_closing':      return Icons.payments_outlined;
      default:                  return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String? type, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (type) {
      case 'approval':          return Colors.orange.shade700;
      case 'approval_decision': return Colors.green.shade700;
      case 'cash_closing':      return cs.primary;
      default:                  return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              final hasUnread = (snap.data ?? []).any((n) => n['is_read'] == false);
              if (!hasUnread) return const SizedBox.shrink();
              return _markingAll
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : TextButton(
                      onPressed: _markAll,
                      child: const Text('Mark all read'),
                    );
            },
          ),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    friendlyError(snapshot.error!, fallback: 'Could not load notifications.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                ]),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final items = snapshot.data!;
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.notifications_none, size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text(
                  'No notifications yet.',
                  style: TextStyle(color: Colors.black38),
                ),
              ]),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
              itemBuilder: (context, i) {
                final n = items[i];
                final isUnread = n['is_read'] == false;
                final type = n['type'] as String?;
                final dt = DateTime.tryParse(n['created_at'] as String? ?? '');

                return InkWell(
                  onTap: () => _tapNotification(n),
                  child: Container(
                    color: isUnread
                        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25)
                        : null,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _iconColor(type, context).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _icon(type),
                            size: 18,
                            color: _iconColor(type, context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(
                                    n['title'] as String? ?? '',
                                    style: TextStyle(
                                      fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (isUnread)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(left: 6, top: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ]),
                              const SizedBox(height: 2),
                              Text(
                                n['message'] as String? ?? '',
                                style: const TextStyle(fontSize: 13, color: Colors.black54),
                              ),
                              if (dt != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  formatDateTime(dt),
                                  style: const TextStyle(fontSize: 11, color: Colors.black38),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
