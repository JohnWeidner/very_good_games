# Test Quality Review

**Branch**: `main` (leaderboard feature)
**Date**: 2026-04-06
**Reviewer**: Claude (automated)
**Stack**: Flutter, flutter_bloc, bloc_test, mocktail, very_good_analysis

---

## Coverage Summary

- **Test run**: Pass (46/46 tests green in `test/nostr/stats/`)
- **Coverage**: Not measured (no `--coverage` flag; see Recommendation 7)
- **Files with tests**: 5/5 (all implementation files have corresponding test files)
- **Missing test files**: None

| Implementation file | Test file | Status |
|---|---|---|
| `lib/nostr/stats/models/leaderboard.dart` | `test/nostr/stats/models/leaderboard_test.dart` | Present |
| `lib/nostr/stats/repository/community_stats_repository.dart` | `test/nostr/stats/repository/community_stats_repository_test.dart` | Present |
| `lib/nostr/stats/cubit/leaderboard_cubit.dart` | `test/nostr/stats/cubit/leaderboard_cubit_test.dart` | Present |
| `lib/nostr/stats/cubit/leaderboard_state.dart` | Tested inside `leaderboard_cubit_test.dart` | Covered |
| `lib/nostr/stats/view/leaderboard_section.dart` | `test/nostr/stats/view/leaderboard_section_test.dart` | Present |

---

## Data Model Test Quality

### `leaderboard_test.dart`: Issues found

**LeaderboardEntry group**: Good coverage of `displayName` truncation (long and short npub), `copyWith` (partial override and no-op), and Equatable equality/inequality. Well structured.

**Leaderboard group**: Covers `isEmpty` (both paths), equality, and `props`. However:

- **[Important] `containsUser` only tests the negative case.** There is no test where the hex pubkey actually matches an entry's npub. The positive path -- which exercises the `Nip19.encodePubKey` conversion -- is completely untested.

- **[Important] `findUserEntry` only tests the negative case.** Same gap: no test verifies that a matching hex pubkey returns the correct `LeaderboardEntry`.

- **[Suggestion] `displayName` boundary at exactly length 12.** The `_truncateNpub` implementation uses `npub.length < 12` as the threshold. There is a test for a short string (length 5) and a long string, but no test for the boundary value (length 11 vs 12) to confirm where truncation kicks in.

---

## Repository Test Quality

### `community_stats_repository_test.dart`: Issues found

**`fetchStats` group**: Excellent. Covers happy path, deduplication by pubkey, empty events, exceptions, malformed score labels, and caching with `verify(...).called(1)`.

**`fetchLeaderboard` group**: Good coverage of happy path (sorted DESC), null on empty events, null on exception, and null when all scores are invalid. However:

- **[Important] No test for deduplication by pubkey in `fetchLeaderboard`.** The `fetchStats` group tests deduplication, but `fetchLeaderboard` has its own independent deduplication loop. A bug could be introduced in the leaderboard-specific dedup code without any test catching it.

- **[Important] No test for tie-breaking by `createdAt` ASC.** The sort comparator has two branches -- score DESC and createdAt ASC for ties. Only score DESC is tested. Two entries with the same score but different `createdAt` values should be tested to verify the earlier submission ranks higher.

- **[Important] No test for the `limit` parameter.** `fetchLeaderboard` accepts `{int limit = 10}`. No test verifies that passing a custom limit (e.g., `limit: 2`) truncates the result, nor that the default of 10 works correctly with more than 10 entries.

- **[Suggestion] `makeEvent` helper is duplicated.** The same `makeEvent` factory exists in both the `fetchStats` and `fetchLeaderboard` groups. Extract it to a top-level helper within the test file.

---

## State Management Test Quality

### `leaderboard_cubit_test.dart`: Pass (minor suggestions)

- Uses `bloc_test` correctly throughout -- VGV convention.
- Uses `mocktail` for `CommunityStatsRepository` and `NostrIdentityRepository` -- VGV convention.
- Mocks are created in `setUp` -- VGV convention.
- Tests cover: initial state, no-identity path, loading->loaded, loading->unavailable (null return), exception handling, identity check exception bubbling, and multiple sequential calls.
- Test names are descriptive and read like specifications.

- **[Suggestion]** The "handles identity check exception gracefully" test name says "gracefully" but the test expects the exception to bubble up (`errors: () => [isA<Exception>()]`). The name is slightly misleading -- it is testing that exceptions propagate, which is intentional per the cubit comment "let exceptions bubble up as critical failures". Consider renaming to "propagates identity check exception as unhandled error".

### `LeaderboardState` (tested in cubit test file): Pass

- `copyWith` with overrides, `copyWith` preserving unchanged fields, Equatable equality, and `props` are all tested.

---

## UI Component Test Quality

### `leaderboard_section_test.dart`: Issues found

- Uses `BlocProvider.value` with mock cubit -- VGV convention.
- Uses `MaterialApp` wrapper -- correct for widget tests.
- Uses `setUp`/`tearDown` for mock lifecycle -- good practice.
- Covers all five visual states: identity prompt, loading, empty leaderboard, populated table, and unavailable.
- Tests `fetchLeaderboard` is called on initial build.

- **[Critical] User highlight test does not actually verify highlighting.** The test at line 138-176 is titled "highlights user entry when pubkey matches" but the only assertion is `expect(find.text('100'), findsOneWidget)`. This verifies the entry renders, not that it is highlighted. The test should find the `TableRow` `BoxDecoration` and assert `color == theme.colorScheme.primaryContainer`. As written, this test would pass even if highlighting were completely removed.

  Additionally, the test uses a fake npub (`npub1aaa...58 chars`) that is not a valid bech32 encoding. The `_isUserEntry` method calls `Helpers.decodeBech32` which throws on an invalid npub (the test output confirms: `WARNING: decodeBech32 error: Checksum verification failed`). This means the catch block returns `false`, so highlighting is never actually applied in this test. The test passes vacuously.

- **[Important] No test for `status=loaded` with `leaderboard=null` fallback.** The `BlocBuilder` has a default branch that renders `_UnavailableMessage`. When `status == LeaderboardStatus.loaded` but `leaderboard` is null (an edge case), the widget falls through to the default unavailable message. This path has no dedicated test.

- **[Suggestion]** The `buildTestWidget` helper calls `mockCubit.emitState(initialState)` which adds an event to the stream before the widget is built. This is unnecessary since `when(() => mockCubit.state).thenReturn(initialState)` is sufficient for `BlocBuilder` to use the initial state. The extra `emitState` call could mask issues where the cubit's `state` getter and stream disagree.

---

## Anti-Patterns Found

### 1. `leaderboard_section_test.dart:175` -- No meaningful assertion (highlight test)

- **Issue**: The test "highlights user entry when pubkey matches" only asserts `find.text('100')`, which verifies rendering but not highlighting. This is effectively a no-assertion test for its stated purpose.
- **Fix**: Use valid bech32-encoded npub values in test data. Find the `TableRow`'s `BoxDecoration` and assert `color` equals `Theme.of(context).colorScheme.primaryContainer`. Alternatively, use a `tester.widget<DecoratedBox>()` finder to inspect the decoration.

### 2. `leaderboard_section_test.dart:152-154` -- Invalid test data causes silent failure

- **Issue**: The npub string `npub1aaa...` is not a valid bech32-encoded public key. `Helpers.decodeBech32` throws, causing `_isUserEntry` to always return `false`. The test passes but tests nothing about highlighting.
- **Fix**: Generate a valid npub from a known 64-char hex pubkey using `Nip19.encodePubKey(hexKey)` in the test, then use that npub in the `LeaderboardEntry` and the corresponding hex as `userPubKeyHex`.

### 3. `leaderboard_test.dart:111-135` -- Missing positive path for user lookup methods

- **Issue**: `containsUser` and `findUserEntry` are only tested for the negative case. The happy path where a user IS found is never exercised.
- **Fix**: Create a `LeaderboardEntry` with an npub generated from a known hex pubkey via `Nip19.encodePubKey`, then call `containsUser`/`findUserEntry` with that hex key and assert the positive result.

---

## Pattern Compliance

| Pattern | Status | Notes |
|---|---|---|
| bloc_test for cubits | Pass | LeaderboardCubit uses blocTest correctly |
| mocktail for mocks | Pass | All mocks use mocktail |
| UI tests with MaterialApp wrapper | Pass | All widget tests wrap in MaterialApp |
| Seeded initial states | Pass | Cubit tests use setUp for non-initial state dependencies |
| setUp/tearDown | Pass | Shared setup in setUp, cubit mock close in tearDown |
| Group organization | Pass | All tests use group() for logical organization |
| MockCubit for UI tests | Pass | Uses custom mock with StreamController -- acceptable pattern |

---

## Recommendations

1. **[Critical] Fix the highlight test with valid bech32 npub data and real decoration assertions.** This is the highest priority -- the test currently provides false confidence that user highlighting works. Use `Nip19.encodePubKey` to create valid test npubs from known hex keys, and assert on the `BoxDecoration.color` of the highlighted `TableRow`.

2. **[Important] Add positive-path tests for `containsUser` and `findUserEntry`.** These methods involve `Nip19.encodePubKey` conversion and are only tested for the "not found" case. A regression in the encoding logic would go undetected.

3. **[Important] Add repository test for `fetchLeaderboard` deduplication.** Submit two events with the same pubkey but different timestamps/scores, and verify only the latest is kept.

4. **[Important] Add repository test for tie-breaking by `createdAt`.** Submit two events with equal scores but different `createdAt` values and verify the earlier submission ranks higher.

5. **[Important] Add repository test for the `limit` parameter.** Verify that `fetchLeaderboard(dTag, limit: 2)` returns only 2 entries when more are available, and that ranks are correctly assigned (1 and 2, not 1-N).

6. **[Suggestion] Rename the "handles identity check exception gracefully" cubit test** to clarify that the exception is intentionally propagated, not swallowed.

7. **[Suggestion] Run tests with `--coverage` and verify line coverage for the changed files** to confirm no dead code paths exist.

8. **[Suggestion] Extract the duplicated `makeEvent` helper** in the repository test to a single top-level function.

---

## Verdict

**Fix 1 critical and 5 important issues before merging.**

The test suite has good structural coverage -- every file has tests, VGV conventions (bloc_test, mocktail, proper grouping) are followed correctly, and the cubit tests are particularly well done. However, the user-highlight widget test provides false confidence due to invalid test data and a missing assertion, and several important behavioral paths in the model and repository layers are untested (positive-path user lookup, deduplication in leaderboard, tie-breaking, limit parameter). These gaps could allow regressions to ship undetected.
