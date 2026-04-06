## VGV Code Review -- Leaderboard Feature

### Summary

The leaderboard feature is well-structured and follows VGV conventions closely: proper layer separation (models / repository / cubit / view), Equatable models, `part of` state files, barrel exports, and comprehensive test coverage with `bloc_test` and `mocktail`. The code is clean and readable. There are a few issues that should be addressed before merge -- a bare `catch` that will fail the linter, an unhandled exception path in the cubit that can crash the app, a `copyWith` that cannot clear a nullable field (violating the project's documented convention), and duplicated relay query logic in the repository. Test coverage is solid overall but has gaps around positive-path tests for user lookup methods and the user-highlighting widget test asserts nothing meaningful. Overall assessment: **needs work** -- the three critical issues should be addressed before merging.

### Critical -- Must Fix Before Merge

- **lib/nostr/stats/view/leaderboard_section.dart:200** -- Bare `catch (e)` instead of `on Exception catch`
  - Why: `very_good_analysis` enforces `avoid_catches_without_on_clauses`. A bare `catch` catches `Error` types (assertion errors, stack overflows) which should propagate, not be silently swallowed. This will fail the linter.
  - Fix: Change `} catch (e) {` to `} on Exception catch (_) {` (the exception variable is unused anyway).

- **lib/nostr/stats/cubit/leaderboard_cubit.dart:32** -- Identity check exception is unhandled, will crash the app
  - Why: The comment says "let exceptions bubble up as critical failures," but unhandled exceptions in a Cubit method invoked from `addPostFrameCallback` surface as uncaught async errors, potentially crashing the app. The cubit test at line 148 confirms this -- the exception propagates unhandled. The existing `CommunityStatsCubit` does not have this pattern; it wraps all async work. An exception from `SharedPreferences` or `FlutterSecureStorage` is a plausible runtime failure, not a "critical" failure worth crashing over.
  - Fix: Wrap the `hasIdentity` call in the same try/catch block as the fetch, or emit an error/unavailable state on failure. At minimum, catch `Exception` and emit `unavailable` so the UI degrades gracefully instead of crashing:
    ```dart
    Future<void> fetchLeaderboard(String dTag) async {
      try {
        final hasIdentity = await _identityRepository.hasIdentity();
        if (!hasIdentity) {
          emit(state.copyWith(hasIdentity: false));
          return;
        }
        emit(const LeaderboardState(status: LeaderboardStatus.loading));
        final leaderboard = await _statsRepository.fetchLeaderboard(dTag);
        // ... rest of logic
      } on Exception {
        emit(const LeaderboardState(status: LeaderboardStatus.unavailable));
      }
    }
    ```

- **lib/nostr/stats/cubit/leaderboard_state.dart:41-50** -- `copyWith` cannot set `leaderboard` back to `null`
  - Why: Because `leaderboard` is nullable and `copyWith` uses `??`, once a leaderboard is loaded, calling `copyWith(status: LeaderboardStatus.loading)` preserves the stale leaderboard object. The cubit works around this by constructing new `LeaderboardState(...)` instances directly (lines 43, 47, 53, 57), which is inconsistent with how `CommunityStatsCubit` uses `state.copyWith(...)`. More importantly, if future code calls `copyWith` expecting to reset to null, it silently keeps stale data. The project's CLAUDE.md explicitly documents the convention: "use `Type? Function()?` wrapper for nullable fields that need explicit null-setting."
  - Fix:
    ```dart
    LeaderboardState copyWith({
      LeaderboardStatus? status,
      Leaderboard? Function()? leaderboard,
      bool? hasIdentity,
    }) {
      return LeaderboardState(
        status: status ?? this.status,
        leaderboard: leaderboard != null ? leaderboard() : this.leaderboard,
        hasIdentity: hasIdentity ?? this.hasIdentity,
      );
    }
    ```
    Then update the cubit to use `state.copyWith(...)` consistently instead of constructing new instances. This aligns with the project's established pattern.

### Important -- Should Fix

- **lib/nostr/stats/repository/community_stats_repository.dart:79-136** -- Duplicated relay query and deduplication logic between `fetchStats` and `fetchLeaderboard`
  - Why: Both methods query kind 30042 events with the same filter, deduplicate by pubkey keeping latest `createdAt`, and extract scores via `_extractScore`. The query + dedup + score extraction logic is repeated almost verbatim (~30 lines). A bug fix in one method could easily be missed in the other. For example, if the deduplication strategy changes or a new NIP-32 label format is added, both methods must be updated in lockstep.
  - Fix: Extract a private method like `Future<Map<String, Nip01Event>?> _fetchDedupedEvents(String dTag)` that handles the query, timeout, and deduplication. Both `fetchStats` and `fetchLeaderboard` call it and then do their own aggregation.

- **lib/nostr/stats/stats.dart** -- Missing `view/view.dart` export from barrel file
  - Why: The barrel file exports cubit, models, and repository, but does not export `view/view.dart`. Currently nothing imports `LeaderboardSection` via the barrel, which means consumers must use a direct file import. VGV convention is that barrel files export the public API for a directory. The existing `CommunityStatsSection` view (if one exists) should also be exported from this barrel or from a view barrel.
  - Fix: Add `export 'view/view.dart';` to `lib/nostr/stats/stats.dart`.

- **lib/nostr/stats/view/leaderboard_section.dart:32-38** -- Side effect (data fetch) triggered inside `BlocBuilder.builder`
  - Why: Triggering `fetchLeaderboard` from inside `BlocBuilder.builder` using `addPostFrameCallback` is fragile. It runs on every rebuild where `status == initial`, and relies on `context.mounted` to guard against stale context. This mixes presentation concerns with data fetching. The builder should be pure -- it should only render state, not trigger state changes.
  - Fix: Move the `fetchLeaderboard` call to the point where the cubit is created. If the cubit is provided via `BlocProvider(create: ...)`, the create callback can trigger the fetch. Alternatively, convert to a `StatefulWidget` and call `fetchLeaderboard` in `initState`. This keeps the builder pure and ensures the fetch happens exactly once.

- **lib/nostr/stats/repository/community_stats_repository.dart:79-136** -- `fetchLeaderboard` does not use the cache
  - Why: `fetchStats` caches results in `_cache`, but `fetchLeaderboard` always hits the relay. If both are called for the same `dTag`, the same relay query runs twice. Repeated calls to `fetchLeaderboard` (e.g., on widget rebuild or cubit re-creation) also re-fetch every time.
  - Fix: Either share a common event cache between both methods, or add a separate `_leaderboardCache` for `fetchLeaderboard`. At minimum, document why caching is intentionally omitted for leaderboard if freshness is required.

- **test/nostr/stats/models/leaderboard_test.dart** -- Missing positive-path tests for `containsUser` and `findUserEntry`
  - Why: Both methods are only tested with a non-matching pubkey (negative case). There is no test verifying that `containsUser` returns `true` or that `findUserEntry` returns the correct entry when the user IS in the leaderboard. These are the primary use cases for the methods. Testing only the "not found" path gives false confidence.
  - Fix: Add tests using `Nip19.encodePubKey(hexKey)` to construct an npub that matches an entry, then verify `containsUser` returns `true` and `findUserEntry` returns the expected `LeaderboardEntry`.

- **test/nostr/stats/view/leaderboard_section_test.dart:140-176** -- User highlight test does not actually verify highlighting
  - Why: The test comment says "Verify the highlighted row has the primaryContainer color" but then only checks `expect(find.text('100'), findsOneWidget)`. It does not assert that any `BoxDecoration` has the `primaryContainer` color. The test passes regardless of whether highlighting works -- it is testing that the entry renders, not that it is highlighted.
  - Fix: Find the `TableRow` with the user's entry and verify its `BoxDecoration.color` matches `Theme.of(context).colorScheme.primaryContainer`. For example:
    ```dart
    final table = tester.widget<Table>(find.byType(Table));
    final userRow = table.children[1]; // First data row
    final decoration = userRow.decoration as BoxDecoration?;
    expect(decoration?.color, isNotNull);
    ```

### Suggestions -- Nice to Have

- **lib/nostr/stats/models/leaderboard.dart:69-83** -- `containsUser` and `findUserEntry` both encode hex to npub on every call
  - Suggestion: These two methods both call `Nip19.encodePubKey(userPubKeyHex)` which involves bech32 encoding. If called in sequence (check then get entry), the encoding runs twice. Consider having `containsUser` delegate to `findUserEntry != null`, or combining into a single method.

- **lib/nostr/stats/view/leaderboard_section.dart:192-204** -- `_isUserEntry` decodes bech32 on every row during every rebuild
  - Suggestion: The method calls `Helpers.decodeBech32(entry.npub)` for every table row. For a 10-entry leaderboard this is minor, but it would be cleaner to encode `userPubKeyHex` to npub once in the `build` method and compare strings directly, avoiding repeated bech32 decoding and the need for a try/catch.

- **test/nostr/stats/repository/community_stats_repository_test.dart:24-39 and 214-229** -- `makeEvent` helper is duplicated between the two test groups
  - Suggestion: Extract `makeEvent` to a shared helper at the top of the file with a `dTag` parameter. Both groups define nearly identical helpers with only the default `dTag` value differing.

- **test/nostr/stats/view/leaderboard_section_test.dart** -- Missing test for identity setup button tap behavior
  - Suggestion: The test verifies the button renders but does not tap it to verify `IdentitySetupLauncher.launch` is called. A test that taps the "Set Up Identity" button and verifies the navigation/launcher behavior would increase confidence in the integration.

- **lib/nostr/stats/repository/community_stats_repository.dart:119-124** -- Sort comparator is correct but could benefit from a comment about tie-breaking rationale
  - Suggestion: The sort uses `createdAt ASC` for tie-breaking (earlier submission wins). This is a reasonable and fair policy, but it is a product decision embedded in code. A brief comment like `// Ties broken by earliest submission (rewards speed)` makes the intent explicit.

### Simplicity Assessment

- Lines that could be removed: ~25 (by extracting shared relay query logic in the repository)
- Unnecessary abstractions: None -- the layer separation (model / repository / cubit / view) is appropriate for this feature's complexity
- YAGNI violations: None identified -- `copyWith`, `containsUser`, and `findUserEntry` all have clear immediate use cases in the view layer
- Complexity verdict: Minor tweaks needed -- the duplicated relay logic in the repository is the main simplification opportunity

### Testing Assessment

- New code with tests: Partial -- all new files have corresponding test files, but positive-path tests for `containsUser`/`findUserEntry` are missing, and the highlight widget test asserts nothing meaningful
- Test quality: Meaningful -- tests cover success, failure, edge cases (malformed scores, dedup, caching verification), and state transitions including sequential fetches and exception propagation
- State management test coverage: Complete -- all cubit states and transitions tested including identity-absent, success, null-result, exception, and sequential-fetch paths
- UI component test coverage: Partial -- all visual states tested (identity prompt, loading, empty, loaded, unavailable), but user highlight assertion is a no-op and identity setup button tap is not tested
