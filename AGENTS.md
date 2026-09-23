# AGENTS.md — LenseScan

Rules for any agent (Antigravity, Claude, Gemini, or a local model) working on this
codebase: FastAPI + SQLAlchemy 2.0 + PostgreSQL backend, EasyOCR + rule-engine
compliance pipeline, ReportLab/python-docx report generation, Flutter mobile client.

These apply on top of whatever the harness's own defaults are. Where this file is
silent, use general good judgment. Where it speaks, it wins.

---

## 1. Truth & Verification

- **Verify before claiming.** Check the actual file/DB/response — never claim a
  route, screen, or test exists from memory or a prior summary. If a past report
  (yours or another agent's) says something is "done," re-check it before building
  on top of it.
- **Verify side effects.** After editing a router, a Flutter screen, a schema, or
  the rule engine, run the relevant check (pytest, `flutter analyze`, a real HTTP
  call) before reporting success — not just "the edit applied cleanly."
- **No fabrication.** Don't invent endpoint paths, rule citations (e.g. "Rule
  6(1)(e)"), file paths, or config values. If unsure which LMPC rule section
  applies, say so and ask, rather than guessing a plausible-sounding citation —
  this project's output includes statutory citations that go on real documents.
- **No silent failures.** Don't swallow OCR errors, DB exceptions, or failed auth
  checks. A silently-caught exception in the rule engine or export pipeline is
  worse than a visible crash — surface it.
- **Gap-round.** Before declaring a task complete, list what was *not* verified
  (e.g., "not tested against a real curved-bottle image," "role-gating added but
  no test written yet"). Don't let "implemented" imply "tested" unless it was.

## 2. This Project's Specific Risk Areas

- **Call-graph reachability for routers.** FastAPI routers must be registered in
  `main.py` to do anything. After adding a new router/endpoint, grep `main.py` to
  confirm `include_router(...)` is actually called. An endpoint with zero callers
  from `main.py` is not shipped, regardless of how complete the file looks.
- **RBAC checks are a named risk class here.** Any new endpoint touching
  inspections, exports, or analytics must state explicitly which roles
  (officer/supervisor/admin) can call it, and have a test asserting the 403/self-
  scoped case for a lower-privileged role — not just the happy path for an
  authorized one. This project has already had gaps here; treat every new
  data-exposing endpoint as guilty until a negative-case test proves otherwise.
- **Compliance engine correctness over convenience.** The rule engine
  (`rule_engine.py`) is the actual product. Never weaken a compliance check,
  loosen a threshold, or suppress a violation just to make a demo image pass. If
  a real product image produces an unexpected result, the fix is either the OCR
  preprocessing or a genuine rule-logic bug — not adjusting the test image's
  expected outcome to match what the code currently does.
- **Placement/geometry fallback stays fail-safe.** When placement-detection
  confidence is low, the engine must return a review state, never a hard
  violation. Any change to `calculate_geometry_confidence` or its threshold
  needs an explicit before/after justification, since this directly controls
  false-positive statutory notices.
- **Evidence integrity is untouchable.** SHA-256 hashing happens on raw image
  bytes before any preprocessing. Never reorder this, never hash a modified copy
  — this chain is what makes the evidence claim (Section 65B) true.

## 3. Testing & Quality Gates

- **Red-green for bug fixes.** Reproduce with a failing test first, then fix. A
  fix with no test is a claim, not a proof.
- **Test at seams.** Test through the actual FastAPI endpoints and Flutter public
  widgets/providers — not private helper functions that might change shape.
- **Immutable test invariant.** Never weaken an assertion, comment out a test, or
  change an expected value just to make a gate pass. If a test is wrong, say so
  explicitly and get confirmation before changing it — don't quietly "fix" it to
  match new behavior.
- **Run the real gates, don't guess.** Backend: `pytest backend/tests -v`.
  Flutter: `flutter analyze` (and `flutter test` where tests exist). Discover the
  exact commands from the project rather than assuming.
- **New logic needs new tests, not just old ones passing.** Fixing a broken
  fixture so old tests pass again is not the same as covering new logic
  (placement validation, analytics aggregation, new export formats). Both are
  required before something is "done."

## 4. Design & UI Work

- **Follow `DESIGN.md` and the Stitch `code.html` exports exactly** for colors,
  spacing, and type scale — don't eyeball the PNG screenshots when the HTML/CSS
  source is available; it's more precise.
- **Minimal-text discipline.** This app is deliberately light on on-screen copy
  (see design history: the first UI pass was reverted for being too
  text-heavy/"AI-generated" looking). Don't add instructional paragraphs,
  redundant subtitles, or explanatory footer text to a screen unless the design
  export explicitly shows it.
- **No silent truncation.** If text would overflow or ellipsis-clip (product
  names, filter tabs, officer names), that's a bug — shorten the actual displayed
  string sensibly, don't let the UI clip it mid-word.
- **Visual replacement ≠ logic replacement.** When restyling a screen to match a
  new design, preserve existing API calls, state management, and navigation
  logic unless explicitly asked to change behavior.

## 5. Process

- **Proportional effort.** A one-line fix doesn't need a design doc. A new
  compliance rule, a new export format, a schema change, or anything touching
  auth/RBAC does — state the plan and the blast radius (which files/endpoints/
  tests are affected) before making the change.
- **Ask when uncertain, with a recommendation.** If a design export is missing a
  screen, if a rule citation is ambiguous, or if two reasonable implementations
  exist, state the options and a recommendation, then wait — don't silently pick
  one and proceed. (This project has had this go well before — keep doing it.)
- **Commit gate.** Never `git commit`/`push` without being explicitly asked to.
- **Report format.** When closing out a task, report: what changed, exact
  file/endpoint references, the test/command run to verify it, and what was
  explicitly *not* verified. Skip the celebratory framing ("100% complete!") —
  state the facts and let the evidence speak.

## 6. Environment

- Backend: Python venv at `backend/.venv`, run via
  `.venv\Scripts\python.exe` (Windows/PowerShell).
- Frontend: Flutter, run/analyze from `lensescan/`.
- Don't invent file paths — confirm with `view`/`list` before referencing a path
  in a report.
