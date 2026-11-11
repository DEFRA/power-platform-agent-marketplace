# Test users and personas

Acceptance tests sign in to the app as a user, and integration tests call the API as one. Both run in parallel, so each test needs a **persona** (a named set of security configuration) and a **user** to apply it to, with no two concurrent tests ever sharing a user. This describes the pattern a project needs. It isn't shipped as code, and many projects already have their own implementation. If the project has one, follow it, check it covers the points below and report any gap. Don't replace it.

The code usually lives in the shared test-data project. How a test gets a client for a persona is in [clients.md](clients.md), and when the pool is built and released is in [run-lifecycle.md](run-lifecycle.md).

## Personas

A persona is a named actor, such as `Applicant` or `Inspector`, defined by:

| Setting | Meaning |
| --- | --- |
| Aliases | The names Gherkin uses ("an inspector"), so feature files never name a user or role. Not needed by tests that don't use Gherkin |
| Roles, business unit, teams, column security profiles | What a user must have to act as the persona |
| Static users (optional) | Users that permanently carry the persona |
| Application ID (optional) | For a persona that is a service identity (an application user) rather than a person |

- The persona list is an enum in the shared test-data project. The definitions live in non-secret configuration, such as `environment.json`, checked in.
- Roles and teams come from the solution. The persona names them, and never invents a role.
- A test runs as one user, so it asks for personas, never for roles. **Never assign roles or business units inside a step, a test or an event.** Change the persona's configuration instead.
- Credentials never go in that file or in the repository. See [configuration.md](configuration.md).

```json
{
  "personas": {
    "inspector": {
      "aliases": ["an inspector"],
      "businessUnit": "<business unit name>",
      "roles": ["<security role name>"],
      "teams": [],
      "columnSecurityProfiles": []
    },
    "serviceBus": { "appId": "<application (client) ID>", "roles": ["<security role name>"] }
  }
}
```

## Two kinds of user

- **Static users** are listed against a persona and are expected to have its configuration permanently. The pool never changes them. They suit personas that need setup the pool can't apply.
- **Dynamic (pooled) users** are every other credential. The pool borrows an unassigned user, applies the requested persona's configuration to it for as long as the test holds it, and strips what the last borrower left behind. They suit ephemeral environments, where nothing needs pre-configuring except that the users exist.

Leave a persona's static users empty unless it must always use pre-configured users, so any pooled user can serve it.

## The user pool

A pool that works for parallel tests does all of the following:

1. **One lease per user.** Each user has a gate (a `SemaphoreSlim(1, 1)`). A test holds a user from acquisition to release.
2. **Request a set of personas.** Match order: a static user whose personas are exactly the set, then (if extra personas are allowed) a static user whose personas include the set, then an unassigned user. Take an idle static user straight away. If all are busy, wait on the static candidates and the unassigned users together and take whichever is free first.
3. **Bound the wait.** Give up after a set time with an error naming the personas, never wait forever. Fail at once, with a clear message, if a persona has no configuration or if no user could ever serve the request.
4. **Strip, then apply, when a pooled user is acquired**, not on release (release is unreliable if a run is killed). Skip both only if the user's last verified state is exactly the requested personas. Track "verified" per user. If apply fails part-way, mark the user unverified and release it, so a later borrower reconfigures it rather than trusting unknown state.
5. **Release at the end of every test**, in a teardown step that can't fail the run, with a safety net that releases anything still held when the per-test client is disposed.
6. **Cache per test by persona set.** Key the cache on the sorted, distinct persona names (plus a flag for "exactly these"), so a test that asks twice for the same personas gets the same user.
7. **Allow "exactly these personas".** Some tests must prove a user has no other roles, so provide a variant that rejects supersets.
8. **Application personas stand apart.** A persona with an application ID resolves to that application user's own client. Don't mix it with pooled personas in one request, and don't mix two application IDs.
9. **Size the pool for the run.** Dynamic personas need at least as many users as parallel workers that use them at once. Each static user caps the parallelism of its persona at one.

## Verify static users up front

Before any test, query Dataverse to confirm each static user has the full configuration of its personas (enabled, business unit, roles, teams, column security profiles, plus any extension checks). Collect every discrepancy and fail the run once with the whole list, so a drifted environment shows up at the start instead of as confusing test failures. Log which users were checked.

## Persona extensions

Roles don't cover everything a persona needs (a licence, an access team, a profile record). Let a project add configuration through extensions with `ApplyAsync`, `RemoveAsync` and `VerifyAsync` for a set of personas. The pool runs them alongside its built-in steps, and `VerifyAsync` returns problems as strings, which are added to the up-front verification.

## Test users' settings

Date and number assertions need a consistent locale and time zone. Set them for every configured test user at the start of a run (see [run-lifecycle.md](run-lifecycle.md)).
