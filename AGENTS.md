# Style

1. Keep code/docs/output simple and concise.
2. Comment major methods and tricky code.
3. Put only trivial one-liners under `# one-liners`.
4. Prefer readers over ivars except for assignment or type hints.
5. Prefer `each`/ranges over `while`; counters are `idx`.
6. Treat String as immutable: use `StringIO buf`, arrays + `join`, substitution, or interpolation. Never add frozen-string comments.
7. Prefer truthy checks over `nil?` when `false` is not distinct.
8. Always nest module/class declarations; never declare them with constant paths such as `module RunKit::Options`.
9. Do not change `.rubocop.yml` without asking.
10. Keep PR/commit text succinct: one or two sentences tops. PR titles should be only a few words.

# Tests

1. Run `just test` after every change.
2. Mirror each source file with one `*_test.rb`; generally use one test method per public method.
3. Namespace tests to mirror production modules.
4. Use `new.tap { _1... }` to set up important objects.
5. Assert observable behavior or state, not incidental mutator return values.
6. Prefer table cases, shared helpers, and custom assertions.
7. Derive table messages from inputs; hand-name only opaque proc cases.
8. Inline one-use table literals directly into `each`; do not name them.
9. Give complicated classes a rich `test_basic` covering their main behavior end to end.
10. Prefer a few end-to-end behavior tests over exhaustive trivial method coverage.
11. Fixtures such as `test/smoke.rb` are exempt from test style conventions.
12. Use `just test-regen` only for intentional snapshot updates; review generated `*.expected` files.
13. Stdout/stderr are fine when relevant. Prefer `assert_equal`/`assert_raises`; never use `refute`.
14. Usually assert only the exception class; check messages only when wording is user-facing behavior.
