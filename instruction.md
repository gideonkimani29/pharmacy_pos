# Go Backend Integration Instructions

This repository now includes a Go REST API in `backend\`. The Flutter app still uses in-memory `Demo*Repository` classes; implementing Flutter's HTTP repositories and switching the composition root is a separate remaining integration step. API paths below describe the current service. SQLite schema is created idempotently at startup; back up the DB file before deployments and upgrades.

## 1. Agree on the API contract

Use JSON over HTTPS in production, with a versioned prefix such as `/api/v1`. Keep request/response field names stable and document each endpoint. All money values should be integer minor units (for example, `1250` means 12.50 in a two-decimal currency); do not use floating-point amounts.

| Flutter repository operation | Endpoint |
|---|---|
| Search products / find barcode | `GET /products?query=...` / `GET /products/barcode/{barcode}` |
| Submit sale | `POST /sales` |
| List checkout customers | `GET /customers` |
| Dashboard summary | `GET /dashboard/summary` |
| List/create/update/activate medicines | `GET, POST /medicines`; `PUT /medicines/{id}`; `PATCH /medicines/{id}/active` |
| List/adjust stock | `GET /stock/batches`; `POST /stock/adjustments` |
| List/create/update/activate customer accounts | `GET, POST /customer-accounts`; `PUT /customer-accounts/{id}`; `PATCH /customer-accounts/{id}/active` |
| Receive account payment | `POST /customer-account-payments` |
| List/create suppliers and purchases / record purchase | `GET, POST /suppliers`; `GET, POST /purchases` |
| Sales, profit, and losses reports | `GET /reports/sales`; `GET /reports/profit`; `GET /reports/losses` |
| Load/save pharmacy settings | `GET, PUT /settings` |
| List/create/update/activate users | `GET, POST /users`; `PUT /users/{id}`; `PATCH /users/{id}/active` |

Sales-return lookup and stock reversal are not implemented because the Flutter Returns tab does not yet have a domain repository. Role checks are enforced server-side: cashiers cannot read batch costs, purchase totals, profit/loss reports, or manage users/settings. Client-side role checks are not a security boundary.

## 2. Run the Go backend

Requires Go 1.27 or newer. From the repository root in PowerShell:

```powershell
Set-Location .\backend
$secretBytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($secretBytes)
$env:JWT_SECRET = [Convert]::ToBase64String($secretBytes)
$bootstrapBytes = New-Object byte[] 32
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bootstrapBytes)
$env:BOOTSTRAP_TOKEN = [Convert]::ToBase64String($bootstrapBytes)
$env:DATABASE_PATH = "..\data\pharmacy.db"
$env:CORS_ORIGINS = "http://localhost:5000,http://localhost:3000"
go run .\cmd\pharmacy-api
```

The service listens on `:8080` by default, creates the SQLite directory/database, applies schema setup at startup, and exposes `GET /health`. Keep `JWT_SECRET` stable across restarts and private; keep `BOOTSTRAP_TOKEN` private and remove it from the environment after creating the first admin. Use a secret manager for deployment. Both secrets must be at least 32 characters. The default database path is `backend\data\pharmacy.db`.

Create the first administrator once:

```powershell
Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8080/api/v1/auth/bootstrap `
  -Headers @{ "X-Bootstrap-Token" = $env:BOOTSTRAP_TOKEN } `
  -ContentType "application/json" `
  -Body '{"name":"Pharmacy Admin","email":"admin@example.com","phone":"","password":"replace-with-a-long-unique-password"}'
```

Bootstrap is disabled as soon as any user exists. Keep the returned access/refresh tokens private.

## 3. Authentication and errors

Authenticated request header:

```http
Authorization: Bearer <access-token>
Accept: application/json
Content-Type: application/json
```

Use `POST /api/v1/auth/login` with `{ "email": "...", "password": "..." }`. Access tokens expire after 15 minutes; refresh tokens expire after 30 days and rotate on `POST /api/v1/auth/refresh`. Send the returned refresh token to `POST /api/v1/auth/logout` to revoke it. Admin-created users receive a one-time `invitationToken` in the `POST /api/v1/users` response; after delivering it securely, the user calls `POST /api/v1/auth/accept-invitation` with `{ "token": "...", "password": "..." }`. This API returns the invitation token but does not send email.

Never embed a database credential or signing secret in the Flutter app.

Return non-2xx status codes for errors, with a consistent JSON shape, for example:

```json
{
  "error": {
    "code": "validation_error",
    "message": "The sale total has changed.",
    "details": {}
  }
}
```

The client should map connection/time-out failures to `NetworkFailure`, HTTP 401/403 to `UnauthorizedFailure`, validation/conflict responses to `ValidationFailure`, and malformed or unexpected responses to `UnexpectedFailure`.

## 4. Preserve POS transaction guarantees

- Require `Idempotency-Key` on `POST /sales` and `POST /purchases`. Store the key with the result and return the original result for a retry; reject reuse of the key with a different payload.
- Sale `payments[].amountMinor` is the tendered amount. The API deducts cash change from the stored cash payment totals so report payment totals reconcile to the net sale total.
- Submit `expectedTotalMinor` with sales and reject stale prices. The backend must compute the authoritative total and allocate stock by FEFO.
- In one database transaction, validate the sale, decrement batches, record the sale and payment lines, and update any customer balance.
- Treat stock quantities, active status, prescription requirements, discounts, and user permissions as server-authoritative.
- Make customer payment receipt and balance reduction atomic. Purchases and stock adjustments must also update stock consistently.
- Return stable IDs and ISO-8601 timestamps. Do not rely on display names as identifiers.

Example sale request shape:

```json
{
  "saleType": "cash",
  "customerId": null,
  "lines": [
    {
      "productId": "product-id",
      "quantity": 2,
      "unitPriceMinor": 1250
    }
  ],
  "payments": [
    {
      "method": "cash",
      "amountMinor": 2500
    }
  ],
  "prescriptionVerified": false,
  "discountMinor": 0,
  "expectedTotalMinor": 2500
}
```

The idempotency key belongs in the request header, not in place of server-side idempotency storage.

## 5. Configure and run the API

1. Start the Go service using the command above.
2. Verify its health endpoint (for example, `GET /health`) from the same machine/network as the Flutter client.
3. Configure CORS for the actual development origin when running Flutter Web. Do not use wildcard origins with credentials in production.
4. Use a reachable host address, not automatically `localhost`, when the client runs on another device or emulator.
5. Serve production traffic over HTTPS and restrict access to the API/database to the intended network.

Suggested development base URLs (replace the port/path with the Go service's actual values):

| Flutter target | Typical host address |
|---|---|
| Windows/macOS/Linux desktop on the API machine | `http://127.0.0.1:<port>/api/v1` |
| Flutter Web on the same machine | `http://127.0.0.1:<port>/api/v1` |
| Android emulator | `http://10.0.2.2:<port>/api/v1` |
| Physical device | `http://<development-machine-LAN-IP>:<port>/api/v1` |

Pass the chosen URL at build/run time rather than hard-coding it:

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

Use the corresponding target address above for emulator/device runs. Production builds should use the deployed HTTPS API URL.

## 6. Wire Flutter without changing the UI layer

The app already defines domain repository interfaces under each feature's `domain/repositories` directory. Add REST-backed implementations under the matching `data/repositories` directory, plus a shared HTTP client and request/response DTOs. Keep JSON parsing and HTTP concerns in the data layer; map responses into existing domain entities and map transport/API errors into the existing `Failure` types.

Replace the `Demo*Repository` registrations in `lib/app.dart` with the REST-backed implementations. Keep demo data only behind an explicit development configuration; do not silently fall back to demo values when the API is unavailable. Preserve existing client-side validation for fast feedback, but rely on the Go API to repeat all security and business-critical validation.

Before replacing all demos, verify one read path and one write path against the real Go service, including unauthorized, validation, timeout, malformed-response, and duplicate-idempotency cases. Then cover every repository and run:

```powershell
flutter analyze
flutter test
```

## 7. Remaining Flutter work and limitations

The backend contract is implemented but has not yet been connected to Flutter. Implement a shared configured HTTP client, secure token persistence, error mapping, data-transfer objects, and all repository adapters before replacing the `Demo*Repository` registrations. Confirm the deployment API URL and the intended token-storage strategy for each supported Flutter platform first. There is no returns workflow yet; suppliers can be added directly through the backend API although the Flutter app currently has no supplier-management screen.
