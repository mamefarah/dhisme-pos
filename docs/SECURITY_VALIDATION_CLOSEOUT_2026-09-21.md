# Dhisme POS — Security and Validation Close-out

**Date:** 21 Sep 2026  
**Repository:** `mamefarah/dhisme-pos`  
**Validated main commit:** `8e2f53191703085027e64f4cc2d08ac066c95afc`  
**Supabase project:** `dhisme-pos` (`uzhnzkgigmqzzgfyndlg`)

## Close-out status

The connected Supabase project was rechecked and reported `ACTIVE_HEALTHY`. Remote migration history includes migrations through **038**.

The current advisor state at close-out is:

- Security: **35 WARN** — authenticated `SECURITY DEFINER` functions. These are not auto-remediated because many are deliberate authenticated application RPC boundaries and require function-by-function review rather than blanket revocation.
- Security: **1 WARN** — leaked-password protection disabled. The organization is on the Supabase **Free** plan, where this control is unavailable. The operator accepted this as a controlled-pilot limitation and will revisit it after a plan upgrade.
- Performance: **64 INFO** — unused indexes. These remain informational and are not a basis for blind index deletion.

## Android/Supabase client-key incident response

A prior validation APK was found to contain a privileged Supabase `sb_secret_` credential. The following containment and prevention work was completed:

1. Exposed GitHub validation artifacts identified during the response were deleted.
2. CI was hardened so Android client builds fail before compilation if `SUPABASE_ANON_KEY` contains an `sb_secret_` value or a legacy JWT whose role is not exactly `anon`.
3. The same fail-fast protection is present in the production-release workflow.
4. Documentation was corrected to state that the client-key slot must contain a publishable key or legacy anon key only.
5. The hardening was merged in PR #44.

The Supabase connector can enumerate publishable keys but not privileged secret-key inventory/revocation state. Therefore server-side deletion of the previously exposed secret cannot be independently enumerated from this integration and must remain an operator-controlled credential-rotation step. The mobile build path itself is now independently guarded and verified.

## Final validation APK

Workflow **Build Dukaan Dhisme POS Validation APK #197, attempt 2** completed successfully on the validated main commit.

Verified workflow stages:

- privileged-key rejection guard — passed;
- Flutter setup and Android SDK setup — passed;
- package resolution — passed;
- generated splash/icon step — passed;
- Flutter analysis — passed;
- automated tests — passed;
- non-production validation APK build — passed;
- validation artifact upload — passed.

Artifact:

- name: `dukaan-dhisme-pos-validation-apk`;
- GitHub artifact archive digest: `sha256:7acf0fd30dee0566201ce61d83ae06794ad18624b926f48f78e8b5c7bda2bfcf`;
- APK SHA-256: `80071ace5eeb74bde61f22e7440f2bb024b269032ab7a7be4c18985f108be53d`;
- APK checksum matched the artifact's `SHA256SUMS`;
- `BUILD_CHANNEL.txt` identifies the build as **non-production validation / release mode / debug signing**;
- binary inspection found **no full `sb_secret_` credential**;
- the embedded Supabase client credential is the active publishable-key class.

The validation APK is suitable for controlled testing only; it is not a production-signed release.

## Manager test status

The permanent production account `Test Manager - Dhisme` was **not created**. This was explicitly deferred by operator decision after the candidate email addresses were found to belong to existing production users.

At close-out:

- matching `Test Manager - Dhisme` profile count: **0**;
- valid unused Dhisme manager invite count: **1**;
- no second production user was created merely to exercise invite replay;
- no fake production sales, purchases, payments, expenses, stock adjustments, cash closings, approvals, or other business transactions were created.

Backend role/RLS behavior and invite lifecycle remain covered by the existing automated verification. A real manager login/UI smoke test remains deferred until a dedicated unused email address is intentionally provisioned.

## Accepted limitations and remaining operational gates

The following items are not represented as completed:

- Supabase leaked-password protection on the current Free plan;
- dedicated production manager onboarding and real manager UI smoke test;
- full real-device pilot execution;
- first operator-run encrypted live-project backup and off-site custody confirmation;
- persistent crash/error monitoring and operational alerting;
- long-lived Android release keystore configuration and first properly signed APK/AAB;
- remaining Authentication email/redirect and server-side password-policy checks.

These are explicit operational or platform limitations, not hidden code-completion claims.

## Release interpretation

The current code/database/build baseline is appropriate for **controlled pilot validation**, subject to the remaining operational gates in `docs/RELEASE_CHECKLIST.md`.

This record does **not** authorize unrestricted production release, does not treat remaining Supabase advisor warnings as cleared, and does not convert deferred human/device testing into a claimed pass.
