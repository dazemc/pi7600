import 'dart:convert';

import 'package:hashlib/hashlib.dart';
import 'package:serverpod/serverpod.dart';
import 'package:simcom_api_server/src/app_services.dart';
import 'package:simcom_api_server/src/auth/totp.dart';
import 'package:simcom_api_server/src/generated/audit_event.dart';
import 'package:simcom_api_server/src/generated/user.dart';
import 'package:simcom_api_server/src/web/docs/docs_page.dart';
import 'package:simcom_api_server/src/web/routes/api_routes.dart';
import 'package:simcom_api_server/src/web/routes/docs_routes.dart';
import 'package:test/test.dart';

import 'support/fake_api.dart';

void main() {
  late AppServices services;
  late FakeDatabase db;
  late FakeSession session;

  setUp(() {
    services = createTestServices();
    db = FakeDatabase();
    session = FakeSession(db);
  });

  User makeUser({
    int id = 1,
    String name = 'admin',
    String password = 'secret',
    bool isAdmin = true,
  }) {
    return User(
      id: id,
      userName: name,
      userPassword: bcrypt(utf8.encode(password), bcryptSalt(nb: 4)),
      isAdmin: isAdmin,
    );
  }

  String bearer(String token) => 'Bearer $token';

  String adminToken(User user) {
    return services.jwt.createToken(user.userName, version: user.tokenVersion);
  }

  Future<Result> call(Route route, Request request) {
    return Future.value(route.handleCall(session, request));
  }

  group('token routes', () {
    test('logs in, refreshes, and revokes tokens', () async {
      final admin = makeUser();
      db.users.add(admin);

      final login = await call(
        TokenRoute(services),
        buildRequest(
          Method.post,
          '/token',
          body: 'username=admin&password=secret',
        ),
      );
      final (loginStatus, loginBody) = await readJsonResponse(login);
      expect(loginStatus, 200);
      final access = loginBody!['access_token'] as String;
      final refresh = loginBody['refresh_token'] as String;

      final refreshed = await call(
        TokenRefreshRoute(services),
        buildRequest(
          Method.post,
          '/token/refresh',
          body: 'refresh_token=${Uri.encodeQueryComponent(refresh)}',
        ),
      );
      expect((await readJsonResponse(refreshed)).$1, 200);

      final logout = await call(
        LogoutRoute(services),
        buildRequest(
          Method.post,
          '/logout',
          headers: {'authorization': bearer(access)},
        ),
      );
      expect((await readJsonResponse(logout)).$1, 200);

      final afterLogout = await call(
        TotpStatusRoute(services),
        buildRequest(
          Method.get,
          '/totp',
          headers: {'authorization': bearer(access)},
        ),
      );
      expect((await readJsonResponse(afterLogout)).$1, 401);
    });

    test('rejects wrong credentials and missing fields', () async {
      db.users.add(makeUser());

      expect(
        (await readJsonResponse(
          await call(
            TokenRoute(services),
            buildRequest(
              Method.post,
              '/token',
              body: 'username=admin&password=wrong',
            ),
          ),
        )).$1,
        401,
      );

      expect(
        (await readJsonResponse(
          await call(
            TokenRoute(services),
            buildRequest(Method.post, '/token', body: 'username=admin'),
          ),
        )).$1,
        422,
      );
    });

    test('requires TOTP after enrollment', () async {
      final admin = makeUser();
      db.users.add(admin);
      final access = adminToken(admin);
      final auth = {'authorization': bearer(access)};

      final setup = await readJsonResponse(
        await call(
          TotpSetupRoute(services),
          buildRequest(
            Method.post,
            '/totp/setup',
            headers: auth,
            body: jsonEncode({'password': 'secret'}),
          ),
        ),
      );
      expect(setup.$1, 200);
      final secret = setup.$2!['secret'] as String;
      final recovery = setup.$2!['recovery_codes'][0] as String;

      final enabled = await readJsonResponse(
        await call(
          TotpEnableRoute(services),
          buildRequest(
            Method.post,
            '/totp/enable',
            headers: auth,
            body: jsonEncode({'code': totpCode(secret)}),
          ),
        ),
      );
      expect(enabled.$1, 200);

      expect(
        (await readJsonResponse(
          await call(
            TokenRoute(services),
            buildRequest(
              Method.post,
              '/token',
              body: 'username=admin&password=secret',
            ),
          ),
        )).$1,
        401,
      );

      expect(
        (await readJsonResponse(
          await call(
            TokenRoute(services),
            buildRequest(
              Method.post,
              '/token',
              body: 'username=admin&password=secret&otp=${totpCode(secret)}',
            ),
          ),
        )).$1,
        200,
      );

      expect(
        (await readJsonResponse(
          await call(
            TokenRoute(services),
            buildRequest(
              Method.post,
              '/token',
              body: 'username=admin&password=secret&otp=$recovery',
            ),
          ),
        )).$1,
        200,
      );

      expect(
        (await readJsonResponse(
          await call(
            TotpDisableRoute(services),
            buildRequest(
              Method.post,
              '/totp/disable',
              headers: auth,
              body: jsonEncode({
                'password': 'secret',
                'code': totpCode(secret),
              }),
            ),
          ),
        )).$1,
        200,
      );
    });
  });

  group('user and audit routes', () {
    test('lists and creates users with admin authorization', () async {
      final admin = makeUser();
      db.users.add(admin);
      final token = adminToken(admin);
      final auth = {'authorization': bearer(token)};

      final list = await readJsonResponse(
        await call(
          UsersRoute(services),
          buildRequest(Method.get, '/users', headers: auth),
        ),
      );
      expect(list.$1, 200);
      expect(list.$2, hasLength(1));

      db.userLookups.addAll([admin, null]);
      final created = await readJsonResponse(
        await call(
          UsersRoute(services),
          buildRequest(
            Method.post,
            '/users',
            headers: auth,
            body: jsonEncode({
              'username': 'managed',
              'password': 'long-enough',
              'is_admin': false,
            }),
          ),
        ),
      );
      expect(created.$1, 201);
      expect(created.$2!['username'], 'managed');
      expect(db.users, hasLength(2));

      db.userLookups.addAll([admin, db.users.last]);
      final duplicate = await readJsonResponse(
        await call(
          UsersRoute(services),
          buildRequest(
            Method.post,
            '/users',
            headers: auth,
            body: jsonEncode({
              'username': 'managed',
              'password': 'long-enough',
            }),
          ),
        ),
      );
      expect(duplicate.$1, 409);
    });

    test('rejects non-admin user management', () async {
      final managed = makeUser(id: 2, name: 'managed', isAdmin: false);
      db.users.addAll([makeUser(), managed]);
      db.userLookups.add(managed);
      final token = adminToken(managed);

      final result = await readJsonResponse(
        await call(
          UsersRoute(services),
          buildRequest(
            Method.get,
            '/users',
            headers: {'authorization': bearer(token)},
          ),
        ),
      );
      expect(result.$1, 403);
    });

    test('lists and cleans audit events', () async {
      final admin = makeUser();
      db.users.add(admin);
      db.auditEvents.add(
        AuditEvent(
          createdAt: DateTime.now().toUtc(),
          eventType: 'login',
          userName: 'admin',
          success: true,
        ),
      );
      final auth = {'authorization': bearer(adminToken(admin))};

      final list = await readJsonResponse(
        await call(
          AuditLogRoute(services),
          buildRequest(Method.get, '/audit?limit=5', headers: auth),
        ),
      );
      expect(list.$1, 200);
      expect(list.$2, hasLength(1));

      final cleanup = await readJsonResponse(
        await call(
          AuditCleanupRoute(services),
          buildRequest(Method.delete, '/audit/cleanup', headers: auth),
        ),
      );
      expect(cleanup.$1, 200);
      expect(cleanup.$2!['deleted'], 1);
    });
  });

  group('static and metrics routes', () {
    test('serves health and ETag-based docs assets', () async {
      final health = await readJsonResponse(
        await call(
          HealthRoute(),
          buildRequest(Method.get, '/healthz'),
        ),
      );
      expect(health.$1, 200);

      final cssRoute = DocsStyleRoute(true);
      final first = await call(
        cssRoute,
        buildRequest(Method.get, '/docs/style.css'),
      );
      final (firstStatus, firstBody) = await readResponse(first);
      expect(firstStatus, 200);
      expect(firstBody, isNotEmpty);

      final etag = '"${sha1.hex(utf8.encode(docsCss))}"';
      final second = await call(
        cssRoute,
        buildRequest(
          Method.get,
          '/docs/style.css',
          headers: {'if-none-match': etag},
        ),
      );
      expect((await readResponse(second)).$1, 304);
    });

    test('requires authentication for the modem report', () async {
      final getResult = await call(
        ModemInfoRoute(services),
        buildRequest(Method.get, '/modem'),
      );
      expect((await readJsonResponse(getResult)).$1, 401);

      final patchResult = await call(
        ModemInfoRoute(services),
        buildRequest(
          Method.patch,
          '/modem',
          body: jsonEncode({
            'settings': {'AT+CMGF': '1'},
          }),
        ),
      );
      expect((await readJsonResponse(patchResult)).$1, 401);
    });

    test('requires admin for modem settings', () async {
      final managed = makeUser(id: 2, name: 'managed', isAdmin: false);
      db.users.addAll([makeUser(), managed]);
      db.userLookups.add(managed);
      final token = services.jwt.createToken('managed');

      final result = await call(
        ModemInfoRoute(services),
        buildRequest(
          Method.patch,
          '/modem',
          headers: {'authorization': bearer(token)},
          body: jsonEncode({
            'settings': {'AT+CMGF': '1'},
          }),
        ),
      );
      expect((await readJsonResponse(result)).$1, 403);
    });

    test('renders request metrics counters', () async {
      final admin = makeUser();
      db.users.add(admin);
      services.requestMetrics.record('GET', '/healthz', 200, 1000);

      final result = await call(
        MetricsRoute(services),
        buildRequest(
          Method.get,
          '/metrics',
          headers: {'authorization': bearer(adminToken(admin))},
        ),
      );
      final (status, body) = await readResponse(result);
      expect(status, 200);
      expect(
        body,
        contains(
          'simcom_api_requests_total'
          '{method="GET",path="/healthz",status="200"} 1',
        ),
      );
    });
  });
}
