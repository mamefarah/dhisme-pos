import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get sb => Supabase.instance.client;
String? get currentUserId => sb.auth.currentUser?.id;
