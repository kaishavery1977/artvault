import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Single Supabase entry — all DB/storage calls go through here.
/// Replaces 32× `Supabase.instance.client.from(...).select()` + `try-catch` repeats
/// with 1-liners: `SupabaseService.I.safeFetch('paintings', ownerUid)` etc.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService I = SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;
  bool get ready => SupabaseConfig.isConfigured;

  Future<List<Map<String, dynamic>>> safeFetch(String table, {String? ownerUid}) async {
    try {
      var q = _db.from(table).select();
      // Supabase PostgREST doesn't allow directly reassigning filtered query type, keep simple
      final data = ownerUid != null ? await _db.from(table).select().eq('ownerUid', ownerUid) : await q;
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> safeFetchOne(String table, String id, {String pk = 'id'}) async {
    try {
      final data = await _db.from(table).select().eq(pk, id).single();
      return Map<String, dynamic>.from(data as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> safeUpsert(String table, String id, Map<String, dynamic> data, {String pk = 'id'}) async {
    try {
      await _db.from(table).upsert({...data, pk: id});
    } catch (_) {}
  }

  Future<void> safeDelete(String table, String id, {String pk = 'id'}) async {
    try {
      await _db.from(table).delete().eq(pk, id);
    } catch (_) {}
  }

  Future<void> safeRpc(String fn, Map<String, dynamic> params) async {
    try {
      await _db.rpc(fn, params: params);
    } catch (_) {
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> watchTable(String table, {String pk = 'id'}) {
    if (!ready) return const Stream.empty();
    return _db.from(table).stream(primaryKey: [pk]).map((l) => l.cast<Map<String, dynamic>>());
  }
}
