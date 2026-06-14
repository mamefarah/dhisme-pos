import 'package:intl/intl.dart';

final _money = NumberFormat.currency(symbol: 'ETB ', decimalDigits: 2);
String money(num value) => _money.format(value);
