/// Timers for one-off or periodic tasks. Applicable as part of the default mechanism.
/// If `moc` is invoked with `-no-timer`, the importing will fail. Furthermore, if passed `--trap-on-call-error`, a congested canister send queue may prevent timer expirations to execute at runtime. It may also deactivate the global timer.
///
/// ```motoko name=import
/// import Timer "mo:core/Timer";
/// ```
///
/// The resolution of the timers is similar to the block rate,
/// so durations should be chosen well above that. For frequent
/// canister wake-ups, consider using the [heartbeat](https://internetcomputer.org/docs/current/motoko/main/writing-motoko/heartbeats) mechanism; however, when possible, canisters should prefer timers.
///
/// The functionality described below is enabled only when the actor does not override it by declaring an explicit `system func timer`.
///
/// Timers are _not_ persisted across upgrades. One possible strategy
/// to re-establish timers after an upgrade is to use stable variables
/// in the `post_upgrade` hook and distill necessary timer information
/// from there.
///
/// Using timers for security (e.g., access control) is strongly discouraged.
/// Make sure to inform yourself about state-of-the-art dapp security.
/// If you must use timers for security controls, be sure
/// to consider reentrancy issues as well as the vanishing of timers on upgrades
/// and reinstalls.
///
/// For further usage information for timers on the IC, please consult
/// [the documentation](https://internetcomputer.org/docs/current/developer-docs/backend/periodic-tasks#timers-library-limitations).
import { setTimer = setTimerNano; cancelTimer = cancel } = "mo:⛔";
import Nat64 = "Nat64";
import Time "Time";

module {

  public type TimerId = Nat;

  /// Installs a one-off timer that upon expiration after given duration `d`
  /// executes the future `job()`.
  ///
  /// ```motoko include=import no-repl
  /// import Int "mo:core/Int";
  ///
  /// func runIn30Minutes() : async () {
  ///   // ...
  /// };
  /// let timerId = Timer.setTimer<system>(#minutes 30, runIn30Minutes);
  /// ```
  public func setTimer<system>(duration : Time.Duration, job : () -> async ()) : TimerId {
    setTimerNano<system>(Nat64.fromNat(Time.toNanoseconds duration), false, job)
  };

  /// Installs a recurring timer that upon expiration after given duration `d`
  /// executes the future `job()` and reinserts itself for another expiration.
  ///
  /// Note: A duration of 0 will only expire once.
  ///
  /// ```motoko include=import no-repl
  /// func runEvery30Minutes() : async () {
  ///   // ...
  /// };
  /// let timerId = Timer.recurringTimer<system>(#minutes 30, runEvery30Minutes);
  /// ```
  public func recurringTimer<system>(duration : Time.Duration, job : () -> async ()) : TimerId {
    setTimerNano<system>(Nat64.fromNat(Time.toNanoseconds duration), true, job)
  };

  /// Cancels a still active timer with `(id : TimerId)`. For expired timers
  /// and not recognised `id`s nothing happens.
  ///
  /// ```motoko include=import no-repl
  /// var counter = 0;
  /// var timerId : ?Timer.TimerId = null;
  /// func runFiveTimes() : async () {
  ///   counter += 1;
  ///   if (counter == 5) {
  ///     switch (timerId) {
  ///       case (?id) { Timer.cancelTimer(id) };
  ///       case null { assert false /* timer already cancelled */ };
  ///     };
  ///   }
  /// };
  /// timerId := ?Timer.recurringTimer<system>(#minutes 30, runFiveTimes);
  /// ```
  public let cancelTimer : TimerId -> () = cancel;

}
