#if canImport(EventKit)
  import XCTest

  @testable import event

  /// Pure-logic tests for `PermissionService` that do not touch EventKit.
  /// The prompt/timeout machinery itself cannot be exercised without mocking
  /// `EKEventStore`, which EventKit does not allow.
  final class PermissionServiceTests: XCTestCase {

    // MARK: - timeoutMilliseconds

    func testTimeoutDefaultsTo15SecondsWithoutEnvVar() {
      // Given no EVENT_PERMISSION_TIMEOUT_MS in the environment,
      // when resolving the prompt timeout, then it is 15 s.
      XCTAssertEqual(
        PermissionService.timeoutMilliseconds(environment: [:]), 15_000)
    }

    func testTimeoutHonorsEventPermissionTimeoutMs() {
      // Given EVENT_PERMISSION_TIMEOUT_MS set to 3000 (below the MCP
      // server's 20 s kill timeout), when resolving the prompt timeout,
      // then it is 3 s.
      XCTAssertEqual(
        PermissionService.timeoutMilliseconds(environment: ["EVENT_PERMISSION_TIMEOUT_MS": "3000"]),
        3_000)
    }

    func testTimeoutTrimsWhitespaceAroundEnvValue() {
      XCTAssertEqual(
        PermissionService.timeoutMilliseconds(environment: [
          "EVENT_PERMISSION_TIMEOUT_MS": "  7500  "
        ]),
        7_500)
    }

    func testTimeoutFallsBackToDefaultForInvalidEnvValue() {
      // Given a non-numeric or zero value, when resolving the prompt
      // timeout, then the 15 s default is used rather than hanging or
      // disabling the bound.
      for raw in ["abc", "0", "-5", ""] {
        XCTAssertEqual(
          PermissionService.timeoutMilliseconds(
            environment: ["EVENT_PERMISSION_TIMEOUT_MS": raw]),
          15_000,
          "expected default for raw value \(raw)")
      }
    }

    func testTimeoutCapsAbsurdEnvValueToOneHour() {
      // Given an env value larger than Int64.max (which would overflow the
      // Task.sleep(for:) conversion and trap), when resolving the prompt
      // timeout, then it is clamped to 1 h instead.
      XCTAssertEqual(
        PermissionService.timeoutMilliseconds(
          environment: ["EVENT_PERMISSION_TIMEOUT_MS": "18446744073709551615"]),
        3_600_000)
    }

    // MARK: - ResumeGate

    func testResumeGateClaimsExactlyOnce() {
      // Given a fresh gate, when claiming it repeatedly, then only the
      // first claim wins — a double resume of the checked continuation
      // would crash the process.
      let gate = ResumeGate()
      XCTAssertTrue(gate.claim())
      XCTAssertFalse(gate.claim())
      XCTAssertFalse(gate.claim())
    }

    func testResumeGateHasSingleWinnerUnderConcurrency() async {
      // Given many racing claimers (the TCC completion handler and the
      // timeout task), when they all claim the same gate, then exactly one
      // wins.
      let gate = ResumeGate()
      let results = await withTaskGroup(
        of: Bool.self, returning: [Bool].self
      ) { group in
        for _ in 0..<64 {
          group.addTask { gate.claim() }
        }
        var claims: [Bool] = []
        for await claim in group {
          claims.append(claim)
        }
        return claims
      }
      XCTAssertEqual(results.filter { $0 }.count, 1)
    }
  }
#endif
