# Grill checklist

A prompt bank, not a questionnaire. Walk it between rounds to find the branch you have not visited; ask only what genuinely applies and what the research did not already answer. A domain that does not apply gets one line in the plan saying so — the point is that the skip was deliberate.

Ordered roughly by how expensive the mistake is to undo.

## 1. Scope and ownership

- What is explicitly **not** in this feature, and where does that boundary get enforced?
- Which parts are ours, which are the client's, CRM's, FE's, a third party's? Every cross-boundary item needs a named owner.
- What must ship together vs. what can be a fast-follow? Does anything half-shipped leave the user in a broken state?
- Is there an existing feature this duplicates or should extend instead?

## 2. Data model and contracts

- New tables/columns, or does existing structure carry it? What is nullable, and what does null *mean*?
- Which side owns each field — us, or the remote system? Who writes it, who only reads?
- Enum vs. lookup vs. free text. If the remote system sends codes, where do codes become display values, and who owns the mapping?
- Are codes global or per-entity? (The classic silent bug: one shared status map where the remote system reuses the same numeric code with different meanings per entity.)
- What does the API contract look like — request, response, error shape? Is it a discriminated union? Does FE already have an agreed shape?
- What happens to an unknown/unmapped value — skip and log, or fail? Which one keeps the screen alive?
- Pagination: cursor or offset? If merging several sources, can cursors even work?

## 3. Auth and authorization

- Which token/role may call this, and what is the *weakest* state a legitimate user can be in when they hit it (mid-onboarding, unverified email, impersonated)?
- Empty result vs. 401 vs. 403 for each of those states — which reads correctly to the user?
- Can one user reach another's resource by id? Where is that check, and is it on every route including the detail?
- Do admin/impersonation paths need a different rule, and do they bypass anything they should not?

## 4. Concurrency and idempotency

- Can two of these run at once for the same subject? What happens — last write wins, a duplicate row, a lost update?
- Optimistic concurrency (etag / `If-Match` / version column) or a lock? What does the client do on a conflict — retry, or surface a 409?
- If it is queued: what is the job id, and what dedupes — the queue, a claim row, a unique index? Does the guard survive a Redis flush?
- Is a retry safe end to end, or does it re-deliver a side effect (email, push, payment)? Which step must be last-awaited to narrow that window?
- Which races are you **accepting**? Name them, with the impact and the hook for closing them later.

## 5. Failure and retry semantics

- For each external call: what does a timeout mean, what does a 4xx mean, what does a 5xx mean?
- Retryable vs. terminal — and does a retryable failure deserve an alert, or is it noise?
- On final failure, fail **open** or **closed**? (Delivering on a channel the user switched off vs. not delivering at all — which is worse here?)
- Partial success: three of five sub-operations succeeded. Is the result committed, rolled back, or resumable?
- What does the user see while it is failing, and what does support see?

## 6. Caching and invalidation

- What is cached, keyed by what, for how long, and who busts it?
- Does the cache key fragment per filter/page combination, defeating the reuse it was added for?
- Is an **empty** result cached? (Often the exact population that hammers the source.)
- Which writes invalidate it — including the non-obvious ones (a cancel, a cascade, a remote webhook)?
- What is the worst staleness a user can observe, and is that acceptable, stated where support can find it?

## 7. Security and privacy

- What PII does this touch, and does any of it reach a log, a queue payload, an error report or a dashboard?
- Credentials and one-time tokens: are they in a request path that gets persisted or retried? (Anything enqueued lands in Redis, the queue UI and the error tracker.)
- Does this expose a third party's data to the user — a counterparty name, another investor, an internal note? Who signed off?
- Rate limiting and abuse: can this endpoint be used for enumeration, or as an unmetered send?
- Audit: is there a regulatory or support question ("was this person contacted, and when?") this must be able to answer later? What single line answers it?
- Secrets in config vs. settings vs. env — what needs changing without a deploy?

## 8. Integrations

- Exact remote entity/endpoint names, and which environment they were verified in.
- Who triggers what: does the remote system push events, do we poll, or both? Can both fire for the same change and double up?
- Is the remote payload guaranteed to carry what you need to identify the subject, or are you inferring it? (If inferring, dedupe and correlation are the first casualties.)
- Field names differ per environment / per solution version — is anything you rely on environment-specific metadata?
- What is the contract when the remote system is down for an hour?

## 9. Internationalisation and copy

- Which strings are BE-owned and which are FE-owned? A string is only BE's if BE renders it.
- Where do locales come from in an async context with no request?
- Dates, numbers, currency: formatted where, in whose timezone, and is the timezone ever named to the user?
- Length limits on any channel (push, SMS, a fixed-width UI)?
- Is the copy final, or a draft standing in for a client/Legal deliverable? That is an `## Open` item with an owner.

## 10. Observability

- What single log line proves this worked, and which one proves it did not?
- What must **never** appear in a log — address, body, token, amount?
- Which failures deserve an alert, and which would fan out to one alert per user during an outage?
- Is there a metric or query the team will actually run, or is this write-only logging?

## 11. Migration and backfill

- Existing rows/users: do they need backfilling, or does the code tolerate their absence?
- If tolerating: is a missing row distinguishable from a deliberate opt-out? (These usually must not be treated the same.)
- Is the change backwards compatible with clients already in the wild, and for how long must it stay so?
- Is there a reversible path if this ships wrong — a flag, a config switch, or only a revert?

## 12. Testing and verification

- What can be tested automatically, and where do the mocks sit? A mock at the wrong boundary hides exactly the layer the feature lives in.
- Which behaviours can only be checked against real remote data, and against which environment?
- What is deliberately untested, and why — that belongs in `## Verification`, stated, not omitted.
- Is there a test that would have caught the most likely regression here?

## 13. Rollout

- Smallest slice that is independently shippable and verifiable.
- Dependency order — what must land before what, and what is waiting on someone else.
- Is anything gated behind a client deliverable, a CRM deployment, or a Legal sign-off?
- What does "done" mean for this feature, in one sentence — and for each Rollout item, what check proves it (its `Done when`)?
