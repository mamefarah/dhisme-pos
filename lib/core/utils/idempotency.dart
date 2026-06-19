import 'package:uuid/uuid.dart';

const _uuid = Uuid();

String newOperationKey(String operation) => '$operation-${_uuid.v4()}';
