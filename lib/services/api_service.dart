import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

/// Data layer for Shomman. Keeps the interface the screens use
/// (Api.get / post / put / patch) but stores everything in Cloud Firestore,
/// so no separate server or MySQL is needed.
class Api {
  static final _db = FirebaseFirestore.instance;

  static const _categories = ['food', 'financial', 'medical', 'abandonment', 'abuse', 'loneliness', 'other'];
  static const _statuses = ['submitted', 'under_review', 'verified', 'in_progress', 'visit_scheduled', 'resolved', 'rejected'];
  static const _activeStatuses = ['submitted', 'under_review', 'verified', 'in_progress', 'visit_scheduled'];
  static const _risks = ['unassigned', 'low', 'medium', 'high', 'critical'];
  static const _riskOrder = ['critical', 'high', 'medium', 'low', 'unassigned'];
  static const _selfRoles = ['elder', 'family', 'neighbor', 'social_worker', 'volunteer'];
  static const _allRoles = ['elder', 'family', 'neighbor', 'social_worker', 'volunteer', 'officer', 'admin'];

  static String? _cachedUid;
  static Map<String, dynamic>? _cachedMe;
  static bool _syncing = false;
  static int _seq = 0;

  /// New numeric, time-ordered id. The complaint form uses it to name the evidence folder
  /// before the complaint itself exists.
  static int newId() => _newId();

  // ------------------------------------------------------------------ router
  static Future<dynamic> get(String path) => _route('GET', path, null);
  static Future<dynamic> post(String path, Map<String, dynamic> body) => _route('POST', path, body);
  static Future<dynamic> put(String path, Map<String, dynamic> body) => _route('PUT', path, body);
  static Future<dynamic> patch(String path, Map<String, dynamic> body) => _route('PATCH', path, body);

  static Future<dynamic> _route(String method, String path, Map<String, dynamic>? body) async {
    final uri = Uri.parse(path);
    final s = uri.pathSegments;
    final b = body ?? <String, dynamic>{};
    final ids = s.where((x) => int.tryParse(x) != null).map(int.parse).toList();
    final key = '$method ${s.map((x) => int.tryParse(x) != null ? ':id' : x).join('/')}';
    try {
      switch (key) {
        case 'GET auth/me':
          return await _me(refresh: true);
        case 'POST auth/register':
          return await _register(b);
        case 'PUT auth/fcm-token':
          return await _saveFcm('${b['token']}');
        case 'GET elders':
          return await _elders();
        case 'POST elders':
          return await _createElder(b);
        case 'PUT elders/:id':
          return await _updateElder(ids[0], b);
        case 'POST complaints':
          return await _createComplaint(b);
        case 'GET complaints/mine':
          return await _myComplaints();
        case 'GET complaints/:id':
          return await _complaint(ids[0]);
        case 'POST sos':
          return await _createSos(b);
        case 'POST wellbeing':
          return await _saveWellbeing(b);
        case 'POST notifications/sync':
          return await _syncNotifications();
        case 'GET notifications':
          return await _notifications();
        case 'PATCH notifications/read-all':
          return await _markAllRead();
        case 'PATCH notifications/:id/read':
          return await _markRead(ids[0]);
        case 'GET admin/complaints':
          return await _adminComplaints(uri.queryParameters['status']);
        case 'GET admin/complaints/:id':
          await _staff();
          return await _complaint(ids[0]);
        case 'PATCH admin/complaints/:id/verify':
          return await _staffUpdate(ids[0],
              status: b['verified'] == false ? 'rejected' : 'verified', note: _nn(b['note']));
        case 'PATCH admin/complaints/:id/risk':
          final risk = '${b['risk_level']}';
          if (!_risks.contains(risk)) throw ApiException(400, 'Invalid risk level');
          return await _staffUpdate(ids[0], risk: risk, note: 'Risk level set to $risk');
        case 'PATCH admin/complaints/:id/status':
          final st = '${b['status']}';
          if (!_statuses.contains(st)) throw ApiException(400, 'Invalid status');
          return await _staffUpdate(ids[0], status: st, note: _nn(b['note']));
        case 'POST admin/complaints/:id/visits':
          return await _scheduleVisit(ids[0], b);
        case 'GET admin/sos':
          return await _adminSos();
        case 'PATCH admin/sos/:id':
          return await _setSos(ids[0], '${b['status']}');
        case 'GET admin/analytics':
          return await _analytics();
        case 'GET admin/report':
          return await _report(int.tryParse(uri.queryParameters['days'] ?? '') ?? 0);
        case 'GET admin/users':
          return await _adminUsers();
        case 'PATCH admin/users':
          return await _updateUser(b);
      }
      throw ApiException(404, 'Unknown request: $key');
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw ApiException(403, 'Permission denied. Check the Firestore rules and your account role.');
      }
      throw ApiException(500, e.message ?? e.code);
    }
  }

  // ----------------------------------------------------------------- helpers
  static User get _user {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw ApiException(401, 'Please log in again');
    return u;
  }

  static String get _uid => _user.uid;

  static dynamic _norm(dynamic v) {
    if (v is Timestamp) return v.toDate().toUtc().toIso8601String();
    if (v is Map) return v.map((k, x) => MapEntry(k.toString(), _norm(x)));
    if (v is List) return v.map(_norm).toList();
    return v;
  }

  static Map<String, dynamic> _doc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = Map<String, dynamic>.from(_norm(d.data() ?? <String, dynamic>{}) as Map);
    m['id'] = int.tryParse(d.id) ?? d.id;
    return m;
  }

  static String? _nn(dynamic v) {
    final t = (v ?? '').toString().trim();
    return t.isEmpty ? null : t;
  }

  // Numeric, time-ordered id (fits safely in a JS number on web too)
  static int _newId() {
    _seq = (_seq + 1) % 1000;
    return DateTime.now().millisecondsSinceEpoch * 1000 + _seq;
  }

  static String _nowIso() => DateTime.now().toUtc().toIso8601String();
  static int _idDesc(Map a, Map b) => (b['id'] as num).compareTo(a['id'] as num);

  static String _label(String s) {
    final t = s.replaceAll('_', ' ');
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }

  static String _curMonth() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, dynamic>> _me({bool refresh = false}) async {
    final uid = _uid;
    if (!refresh && _cachedUid == uid && _cachedMe != null) return _cachedMe!;
    final d = await _db.collection('users').doc(uid).get();
    if (!d.exists) throw ApiException(404, 'Profile not found');
    final me = _doc(d);
    if (me['status'] == 'disabled') {
      throw ApiException(403, 'Your account has been disabled. Please contact the administrator.');
    }
    _cachedUid = uid;
    _cachedMe = me;
    return me;
  }

  static Future<Map<String, dynamic>> _staff() async {
    final me = await _me();
    if (me['role'] != 'officer' && me['role'] != 'admin') throw ApiException(403, 'Officers only');
    return me;
  }

  static Future<Map<String, dynamic>> _admin() async {
    final me = await _me();
    if (me['role'] != 'admin') throw ApiException(403, 'Administrators only');
    return me;
  }

  // An elder profile the current user created (or their own profile)
  static Future<Map<String, dynamic>?> _myElder(dynamic id) async {
    if (id == null) return null;
    final d = await _db.collection('elders').doc('$id').get();
    if (!d.exists || d.data()?['created_by'] != _uid) return null;
    return _doc(d);
  }

  // ------------------------------------------------------------ auth / profile
  static Future<Map<String, dynamic>> _register(Map<String, dynamic> b) async {
    final u = _user;
    final name = (b['name'] ?? '').toString().trim();
    if (name.isEmpty) throw ApiException(400, 'Name is required');
    final role = b['role'];
    if (!_selfRoles.contains(role)) throw ApiException(400, 'Invalid role');

    final existing = await _db.collection('users').doc(u.uid).get();
    if (existing.exists) return _me(refresh: true);

    final phone = _nn(b['phone']);
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(u.uid), {
      'name': name,
      'email': u.email,
      'phone': phone,
      'role': role,
      'status': 'active',
      'created_at': FieldValue.serverTimestamp(),
    });
    // An elderly person gets their own elder profile automatically
    if (role == 'elder') {
      batch.set(_db.collection('elders').doc('${_newId()}'), {
        'created_by': u.uid,
        'user_id': u.uid,
        'name': name,
        'phone': phone,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    return _me(refresh: true);
  }

  static Future<Map<String, dynamic>> _saveFcm(String token) async {
    if (token.isEmpty || token == 'null') throw ApiException(400, 'token required');
    await _db.collection('users').doc(_uid).update({'fcm_token': token});
    return {'ok': true};
  }

  // ------------------------------------------------------------------- elders
  static Map<String, dynamic> _elderFields(Map<String, dynamic> b) {
    final age = int.tryParse('${b['age'] ?? ''}');
    final gender = _nn(b['gender']);
    return {
      'name': (b['name'] ?? '').toString().trim(),
      'age': (age != null && age > 0 && age < 130) ? age : null,
      'gender': ['male', 'female', 'other'].contains(gender) ? gender : null,
      'address': _nn(b['address']),
      'district': _nn(b['district']),
      'phone': _nn(b['phone']),
      'emergency_contact': _nn(b['emergency_contact']),
      'health_notes': _nn(b['health_notes']),
    };
  }

  static Future<List<Map<String, dynamic>>> _elders() async {
    await _me();
    final q = await _db.collection('elders').where('created_by', isEqualTo: _uid).get();
    final list = q.docs.map(_doc).toList();
    list.sort(_idDesc);
    return list;
  }

  static Future<Map<String, dynamic>> _createElder(Map<String, dynamic> b) async {
    final f = _elderFields(b);
    if ((f['name'] as String).isEmpty) throw ApiException(400, 'Name is required');
    final id = _newId();
    await _db.collection('elders').doc('$id').set({
      ...f,
      'created_by': _uid,
      'created_at': FieldValue.serverTimestamp(),
    });
    return {...f, 'id': id};
  }

  static Future<Map<String, dynamic>> _updateElder(int id, Map<String, dynamic> b) async {
    final f = _elderFields(b);
    if ((f['name'] as String).isEmpty) throw ApiException(400, 'Name is required');
    await _db.collection('elders').doc('$id').update(f);
    return {'ok': true};
  }

  // --------------------------------------------------------------- complaints
  static Future<Map<String, dynamic>> _createComplaint(Map<String, dynamic> b) async {
    final category = '${b['category']}';
    final description = (b['description'] ?? '').toString().trim();
    if (!_categories.contains(category) || description.length < 10) {
      throw ApiException(400, 'A valid category and a description (min 10 characters) are required');
    }
    final elder = await _myElder(b['elder_id']);
    if (elder == null) throw ApiException(403, 'You cannot report for this elder profile');

    final me = await _me();
    final anon = b['is_anonymous'] == true;
    // The app picks the id first so evidence files can be stored under evidence/<id>/
    final id = int.tryParse('${b['id']}') ?? _newId();

    final evidence = <Map<String, dynamic>>[];
    for (final x in ((b['evidence'] as List?) ?? const [])) {
      if (x is! Map || !['photo', 'audio'].contains(x['type']) || evidence.length >= 10) continue;
      final path = x['path'];
      if (path is String && path.startsWith('evidence/$id/')) {
        evidence.add({'type': x['type'], 'path': path});
      }
    }

    final batch = _db.batch();
    batch.set(_db.collection('complaints').doc('$id'), {
      'elder_id': elder['id'],
      'elder_name': elder['name'],
      'elder_age': elder['age'],
      'elder_gender': elder['gender'],
      'elder_address': elder['address'],
      'elder_district': elder['district'],
      'elder_phone': elder['phone'],
      'elder_emergency_contact': elder['emergency_contact'],
      'elder_health_notes': elder['health_notes'],
      'category': category,
      'description': description,
      'is_anonymous': anon,
      // Reporter identity is stored ONLY when the complaint is not anonymous
      if (!anon) ...{
        'reporter_name': me['name'],
        'reporter_phone': me['phone'],
        'reporter_role': me['role'],
      },
      'status': 'submitted',
      'risk_level': 'unassigned',
      'evidence': evidence,
      'updates': [
        {'status': 'submitted', 'note': 'Complaint submitted', 'officer_name': null, 'created_at': _nowIso()},
      ],
      'visits': [],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    // Private pointer: lets the reporter track the case (and get notifications) even when anonymous
    batch.set(_db.collection('users').doc(_uid).collection('my_complaints').doc('$id'), {
      'complaint_id': id,
      'seen_count': 1,
      'created_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return {'id': id};
  }

  static Map<String, dynamic> _summary(Map<String, dynamic> c) => {
    for (final k in [
      'id', 'category', 'status', 'risk_level', 'is_anonymous',
      'created_at', 'updated_at', 'elder_name', 'elder_district',
    ])
      k: c[k],
  };

  static Future<List<Map<String, dynamic>>> _myComplaints() async {
    await _me();
    final ptr = await _db.collection('users').doc(_uid).collection('my_complaints').get();
    final docs = await Future.wait(ptr.docs.map((p) => _db.collection('complaints').doc(p.id).get()));
    final list = docs.where((d) => d.exists).map((d) => _summary(_doc(d))).toList();
    list.sort(_idDesc);
    return list;
  }

  static Future<Map<String, dynamic>> _complaint(int id) async {
    final d = await _db.collection('complaints').doc('$id').get();
    if (!d.exists) throw ApiException(404, 'Complaint not found');
    return _doc(d);
  }

  // ---------------------------------------------------------- notifications
  // Notifications are generated on the reporter's own device from the case timeline,
  // so officers never need to know who an anonymous reporter is.
  static Future<int> _unreadCount() async {
    final q = await _db.collection('notifications').where('user_id', isEqualTo: _uid).get();
    return q.docs.where((d) => d.data()['is_read'] != true).length;
  }

  static Future<Map<String, dynamic>> _syncNotifications() async {
    await _me();
    if (_syncing) return {'unread': await _unreadCount()};
    _syncing = true;
    try {
      final ptrs = await _db.collection('users').doc(_uid).collection('my_complaints').get();
      final docs = await Future.wait(ptrs.docs.map((p) => _db.collection('complaints').doc(p.id).get()));
      final batch = _db.batch();
      var writes = 0;
      for (var i = 0; i < ptrs.docs.length; i++) {
        final p = ptrs.docs[i];
        final c = docs[i];
        if (!c.exists) continue;
        final updates = (c.data()?['updates'] as List?) ?? const [];
        final seen = (p.data()['seen_count'] as num?)?.toInt() ?? 1;
        if (updates.length <= seen) continue;
        for (var k = seen; k < updates.length; k++) {
          final u = Map<String, dynamic>.from(updates[k] as Map);
          if (u['status'] == 'risk_updated') continue; // internal note
          final status = _label('${u['status']}');
          batch.set(_db.collection('notifications').doc('${_newId()}'), {
            'user_id': _uid,
            'title': 'Complaint #${c.id}: $status',
            'body': _nn(u['note']) ?? 'Your complaint is now ${status.toLowerCase()}.',
            'complaint_id': int.tryParse(c.id),
            'is_read': false,
            'created_at': FieldValue.serverTimestamp(),
          });
          writes++;
        }
        batch.update(p.reference, {'seen_count': updates.length});
        writes++;
      }
      if (writes > 0) await batch.commit();
    } finally {
      _syncing = false;
    }
    return {'unread': await _unreadCount()};
  }

  static Future<List<Map<String, dynamic>>> _notifications() async {
    await _me();
    final q = await _db.collection('notifications').where('user_id', isEqualTo: _uid).get();
    final list = q.docs.map(_doc).toList();
    list.sort(_idDesc);
    return list;
  }

  static Future<Map<String, dynamic>> _markRead(int id) async {
    await _db.collection('notifications').doc('$id').update({'is_read': true});
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> _markAllRead() async {
    final q = await _db.collection('notifications').where('user_id', isEqualTo: _uid).get();
    final batch = _db.batch();
    var n = 0;
    for (final d in q.docs) {
      if (d.data()['is_read'] != true) {
        batch.update(d.reference, {'is_read': true});
        n++;
      }
    }
    if (n > 0) await batch.commit();
    return {'ok': true};
  }

  // ------------------------------------------------------- officer actions
  static Future<List<Map<String, dynamic>>> _adminComplaints(String? status) async {
    await _staff();
    final snap = await _db.collection('complaints').limit(300).get();
    var list = snap.docs.map(_doc).toList();
    if (status != null && _statuses.contains(status)) {
      list = list.where((c) => c['status'] == status).toList();
    }
    int rank(Map c) => _riskOrder.indexOf('${c['risk_level']}');
    list.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : _idDesc(a, b);
    });
    return list.map(_summary).toList();
  }

  static Future<Map<String, dynamic>> _staffUpdate(
      int id, {
        String? status,
        String? risk,
        String? note,
        Map<String, dynamic>? visit,
      }) async {
    final me = await _staff();
    final entry = {
      'status': status ?? 'risk_updated',
      'note': note,
      'officer_name': me['name'],
      'created_at': _nowIso(),
    };
    final data = <String, dynamic>{
      'updated_at': FieldValue.serverTimestamp(),
      'updates': FieldValue.arrayUnion([entry]),
    };
    if (status != null) {
      data['status'] = status;
      if (status == 'resolved') data['resolved_at'] = FieldValue.serverTimestamp();
    }
    if (risk != null) data['risk_level'] = risk;
    if (visit != null) data['visits'] = FieldValue.arrayUnion([visit]);
    await _db.collection('complaints').doc('$id').update(data);
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> _scheduleVisit(int id, Map<String, dynamic> b) async {
    final when = DateTime.tryParse('${b['scheduled_at']}');
    if (when == null) throw ApiException(400, 'Valid scheduled_at is required');
    final me = await _staff();
    final local = when.toLocal().toString().substring(0, 16);
    return _staffUpdate(
      id,
      status: 'visit_scheduled',
      note: 'Welfare visit scheduled for $local',
      visit: {
        'scheduled_at': when.toUtc().toIso8601String(),
        'notes': _nn(b['notes']),
        'completed': false,
        'officer_name': me['name'],
      },
    );
  }

  // --------------------------------------------------------------------- SOS
  static Future<Map<String, dynamic>> _createSos(Map<String, dynamic> b) async {
    final me = await _me();
    Map<String, dynamic>? elder;
    if (b['elder_id'] != null) {
      elder = await _myElder(b['elder_id']);
      if (elder == null) throw ApiException(403, 'Not allowed');
    } else if (me['role'] == 'elder') {
      // An elder user's SOS is linked to their own profile automatically
      final q = await _db.collection('elders').where('created_by', isEqualTo: _uid).limit(1).get();
      if (q.docs.isNotEmpty) elder = _doc(q.docs.first);
    }
    final msg = _nn(b['message']);
    final id = _newId();
    await _db.collection('sos_requests').doc('$id').set({
      'user_uid': _uid,
      'user_name': me['name'],
      'user_phone': me['phone'],
      'elder_id': elder?['id'],
      'elder_name': elder?['name'],
      'elder_address': elder?['address'],
      'elder_district': elder?['district'],
      'message': msg == null ? null : (msg.length > 500 ? msg.substring(0, 500) : msg),
      'status': 'open',
      'created_at': FieldValue.serverTimestamp(),
    });
    return {'id': id};
  }

  static Future<List<Map<String, dynamic>>> _adminSos() async {
    await _staff();
    final snap = await _db.collection('sos_requests').limit(300).get();
    final list = snap.docs.map(_doc).toList();
    const order = ['open', 'acknowledged', 'closed'];
    list.sort((a, b) {
      final r = order.indexOf('${a['status']}').compareTo(order.indexOf('${b['status']}'));
      return r != 0 ? r : _idDesc(a, b);
    });
    return list;
  }

  static Future<Map<String, dynamic>> _setSos(int id, String status) async {
    await _staff();
    if (!['acknowledged', 'closed'].contains(status)) throw ApiException(400, 'Invalid status');
    await _db.collection('sos_requests').doc('$id').update({'status': status});
    return {'ok': true};
  }

  // ------------------------------------------------------ monthly wellbeing
  static Future<Map<String, dynamic>> _saveWellbeing(Map<String, dynamic> b) async {
    final month = '${b['month']}';
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(month)) throw ApiException(400, 'Month (YYYY-MM) is required');
    final elder = await _myElder(b['elder_id']);
    if (elder == null) throw ApiException(403, 'Not allowed');

    final meals = b['meals_regular'] == true;
    final medicine = b['has_medicine'] == true;
    final safe = b['feels_safe'] == true;
    final lonely = b['feels_lonely'] == true;
    final visits = max(0, int.tryParse('${b['family_visits']}') ?? 0);
    // Flag for follow-up when two or more warning signs appear (or they do not feel safe)
    final warnings = (meals ? 0 : 1) + (medicine ? 0 : 1) + (safe ? 0 : 1) + (lonely ? 1 : 0) + (visits == 0 ? 1 : 0);
    final flagged = warnings >= 2 || !safe;

    await _db.collection('wellbeing_checks').doc('${elder['id']}_${month}_$_uid').set({
      'elder_id': elder['id'],
      'elder_name': elder['name'],
      'submitted_by': _uid,
      'month': month,
      'meals_regular': meals,
      'has_medicine': medicine,
      'feels_safe': safe,
      'feels_lonely': lonely,
      'family_visits': visits,
      'notes': _nn(b['notes']),
      'flagged': flagged,
      'created_at': FieldValue.serverTimestamp(),
    });
    return {'ok': true, 'flagged': flagged};
  }

  // ---------------------------------------------------------------- analytics
  static Future<Map<String, dynamic>> _analytics() async {
    await _staff();
    final cs = (await _db.collection('complaints').get()).docs.map(_doc).toList();

    List<Map<String, dynamic>> group(String key, {String fallback = 'unknown', int? top}) {
      final counts = <String, int>{};
      for (final c in cs) {
        final v = (c[key] ?? fallback).toString();
        counts[v] = (counts[v] ?? 0) + 1;
      }
      final rows = counts.entries
          .map<Map<String, dynamic>>((e) => {'label': e.key, 'count': e.value})
          .toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      return top == null ? rows : rows.take(top).toList();
    }

    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final d = DateTime(now.year, now.month - 5 + i, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });
    final monthly = months
        .map<Map<String, dynamic>>((m) => {
      'label': m,
      'count': cs.where((c) => '${c['created_at']}'.startsWith(m)).length,
    })
        .toList();

    final days = <double>[];
    for (final c in cs) {
      if (c['status'] != 'resolved') continue;
      final a = DateTime.tryParse('${c['created_at']}');
      final r = DateTime.tryParse('${c['resolved_at']}');
      if (a != null && r != null) days.add(r.difference(a).inHours / 24);
    }
    final avg = days.isEmpty
        ? null
        : double.parse((days.reduce((x, y) => x + y) / days.length).toStringAsFixed(1));

    final openSos = (await _db.collection('sos_requests').where('status', isEqualTo: 'open').get()).docs.length;
    final wb = await _db.collection('wellbeing_checks').where('month', isEqualTo: _curMonth()).get();
    final flagged = wb.docs.where((d) => d.data()['flagged'] == true).length;

    return {
      'total': cs.length,
      'resolved': cs.where((c) => c['status'] == 'resolved').length,
      'active': cs.where((c) => _activeStatuses.contains(c['status'])).length,
      'avg_resolution_days': avg,
      'open_sos': openSos,
      'flagged_wellbeing_this_month': flagged,
      'by_status': group('status'),
      'by_risk': group('risk_level'),
      'by_category': group('category'),
      'by_district': group('elder_district', fallback: 'Unknown', top: 10),
      'monthly': monthly,
    };
  }

  // ------------------------------------------------------------------ reports
  // Rows for the exportable report. Reporter identity and descriptions are left out on purpose.
  static Future<Map<String, dynamic>> _report(int days) async {
    await _staff();
    final snap = await _db.collection('complaints').limit(2000).get();
    var list = snap.docs.map(_doc).toList();
    if (days > 0) {
      final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
      list = list.where((c) {
        final d = DateTime.tryParse('${c['created_at']}');
        return d != null && d.isAfter(cutoff);
      }).toList();
    }
    list.sort(_idDesc);
    final rows = list
        .map((c) => {
      for (final k in [
        'id', 'created_at', 'resolved_at', 'elder_name', 'elder_district',
        'category', 'status', 'risk_level', 'is_anonymous',
      ])
        k: c[k],
    })
        .toList();
    return {'generated_at': _nowIso(), 'days': days, 'rows': rows};
  }

  // ---------------------------------------------------------- user management
  static Future<List<Map<String, dynamic>>> _adminUsers() async {
    await _admin();
    final snap = await _db.collection('users').limit(500).get();
    final list = snap.docs.map(_doc).toList();
    list.sort((a, b) => '${b['created_at']}'.compareTo('${a['created_at']}'));
    return list
        .map((u) => {
      for (final k in ['id', 'name', 'email', 'phone', 'role', 'status', 'created_at']) k: u[k],
    })
        .toList();
  }

  static Future<Map<String, dynamic>> _updateUser(Map<String, dynamic> b) async {
    await _admin();
    final uid = '${b['uid']}';
    if (uid == _uid) throw ApiException(400, 'You cannot change your own role or status');
    final data = <String, dynamic>{};
    if (b['role'] != null) {
      if (!_allRoles.contains(b['role'])) throw ApiException(400, 'Invalid role');
      data['role'] = b['role'];
    }
    if (b['status'] != null) {
      if (!['active', 'disabled'].contains(b['status'])) throw ApiException(400, 'Invalid status');
      data['status'] = b['status'];
    }
    if (data.isEmpty) throw ApiException(400, 'Nothing to update');
    await _db.collection('users').doc(uid).update(data);
    return {'ok': true};
  }
}
