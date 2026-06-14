import 'package:intl/intl.dart';

final _dateTime = DateFormat('yyyy-MM-dd HH:mm');
final _date = DateFormat('yyyy-MM-dd');
String formatDateTime(DateTime dt) => _dateTime.format(dt.toLocal());
String todayIsoDate() => _date.format(DateTime.now());
