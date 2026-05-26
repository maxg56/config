# Plan — Issue #4: Inscription email/username avec mot de passe haché

## Context

Issue #4 asks to implement the user registration endpoint in `auth-service`. Most of the work is already done: the `RegisterHandler` accepts all required fields, hashes the password with bcrypt, validates inputs via Gin binding tags, and returns explicit errors for duplicate username/email.

**The only missing acceptance criterion:** email verification is not sent after registration. The `SendEmailVerificationHandler` already has all the logic, but `RegisterHandler` never calls it.

## What's Already Done

| Criterion | Status |
|---|---|
| Fields: email, username, first_name, last_name, password | ✅ `types/request_types.go:4-10` |
| bcrypt hashing | ✅ `services/user_creation.go:14` |
| Field validation (email format, min password length) | ✅ Gin binding tags in `types/request_types.go` |
| Explicit errors for duplicate email/username | ✅ `handlers/auth.go:88-109` |
| **Email verification sent after registration** | ❌ **MISSING** |

## Changes Required

### 1. Extract send-verification-code logic into a shared helper

**File:** `api/auth-service/src/handlers/email_verification.go`

Add a package-level helper (unexported) `sendVerificationCode(email string) error` that:
1. Generates a 6-digit code via `generateVerificationCode()`
2. Deletes any existing `EmailVerification` record for that email
3. Inserts a new `EmailVerification{Email, Code, ExpiresAt: now+15m}`
4. Calls `services.NewEmailService().SendVerificationEmail(email, code)` — non-fatal on failure (log and continue)

This avoids duplicating the logic that already exists in `SendEmailVerificationHandler`.

Refactor `SendEmailVerificationHandler` to call `sendVerificationCode(req.Email)` internally.

### 2. Trigger email verification in RegisterHandler

**File:** `api/auth-service/src/handlers/auth.go`

After the `services.CreateUser(req)` call succeeds, add:
```go
// fire-and-forget: non-fatal if email fails
if err := sendVerificationCode(user.Email); err != nil {
    fmt.Printf("Failed to send verification email to %s: %v\n", user.Email, err)
}
```

The registration response already returns `access_token`/`refresh_token`, so the user can start using the app immediately while verifying email in the background.

## Critical Files

- [api/auth-service/src/handlers/auth.go](api/auth-service/src/handlers/auth.go) — `RegisterHandler` (add verification call after user creation)
- [api/auth-service/src/handlers/email_verification.go](api/auth-service/src/handlers/email_verification.go) — extract `sendVerificationCode()` helper, refactor `SendEmailVerificationHandler` to use it

## Not in Scope

- Frontend registration form (separate issue)
- Additional password complexity rules (not in acceptance criteria)
- Username format validation (not in acceptance criteria)

## Verification

1. Start the stack: `make`
2. `POST /api/v1/auth/register` with `{username, email, password, first_name, last_name}`
   - Expect `201` with tokens
   - Without SMTP configured: expect verification code logged to container stdout
   - With SMTP configured: expect email in inbox
3. `POST /api/v1/auth/register` again with same email → expect `409 "Email déjà utilisé"`
4. `POST /api/v1/auth/register` again with same username → expect `409` with suggestions
5. Confirm user row in DB has `email_verified = false` until code is submitted
6. `POST /api/v1/auth/verify-email` with the code → expect `200` and `email_verified = true` in DB
