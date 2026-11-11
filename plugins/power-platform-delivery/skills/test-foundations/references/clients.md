# Clients

Tests, events and steps get a Dataverse client for a persona from a **client factory**, not from one shared client. This is the API side of [users-and-personas.md](users-and-personas.md). Integration tests act through it, and ScenarioBuilder events use it to act as the right persona. Acceptance tests also use it for data-level steps and checks. A project's own factory is fine if it does the following.

- **One base client per run**, for the application user. Give each test a clone. Don't share one client instance across threads.
- **Impersonation.** For a pooled persona, acquire the user, look up its system user ID and return a clone with `CallerId` set to it. The call then runs with that user's privileges, not the application user's.
- **A new factory per test**, so the leases and cached clients it holds are released together and independently of other tests. Disposing the factory releases them.
- **Application personas** resolve to the application user's own client (see the pool rules in [users-and-personas.md](users-and-personas.md)).
- **Make lifetime obvious.** A persona client is cached and owned by the factory, so the caller never disposes it. A clone for a specific user ID, or for the application user, is owned by the caller, which disposes it (usually in a `using` block).
- **Choose the client by what owns the behaviour:**
  - the persona client when the behaviour belongs to a persona;
  - the user-ID overload when it depends on one specific user, such as a record's owner;
  - the application user only when the behaviour is genuinely service-level. Don't default to it, or to an administrator.
- **Release on failure.** If looking up the user or building the client fails after the pool has leased a user, release the user and remove the half-built client before rethrowing.
- **Parallel runs.** Raise the thread pool minimum and the connection limit as Microsoft's service client guidance describes, once per run. Don't create a client per request.
- **Log the identity.** Log which user or persona each client acts as, so a CI log shows who made each call.
