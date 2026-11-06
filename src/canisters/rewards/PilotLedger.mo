import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Trie "mo:base/Trie";

module {
  // Synthetic Creative TV orders only. All credits are nonredeemable test units.
  public type Status = { #paid; #partialRefund; #refunded; #cancelled };
  public type Event = {
    merchant : Text; currency : Text; eventId : Text; orderId : Text;
    revision : Nat64; shopper : Principal; status : Status; netCents : Nat64;
  };
  public type Outcome = { #applied; #duplicate; #stale };
  public type Entry = { event : Event; verifier : Principal; outcome : Outcome; delta : Int };
  type Order = { latest : Event; units : Nat };
  public type State = {
    events : Trie.Trie<Text, Entry>; orders : Trie.Trie<Text, Order>;
    balances : Trie.Trie<Principal, Nat>; total : Nat;
  };
  public let empty : State = { events = #empty; orders = #empty; balances = #empty; total = 0 };
  func key(value : Text) : Trie.Key<Text> { { key = value; hash = Text.hash(value) } };

  public func balance(state : State, shopper : Principal) : Nat {
    switch (Trie.get(state.balances, { key = shopper; hash = Principal.hash(shopper) }, Principal.equal)) {
      case null 0; case (?units) units
    }
  };
  public func entry(state : State, id : Text) : ?Entry {
    Trie.get(state.events, key(id), Text.equal)
  };
  func terminal(status : Status) : Bool { status == #cancelled or status == #refunded };

  public func record(state : State, event : Event, verifier : Principal) : {
    #ok : (State, Outcome); #err : Text
  } {
    if (event.merchant != "creative-tv-simulation" or event.currency != "USD") {
      return #err("Unsupported simulation merchant or currency")
    };
    if (event.eventId.size() == 0 or event.eventId.size() > 128 or event.orderId.size() == 0
        or event.orderId.size() > 128 or event.revision == 0 or Principal.isAnonymous(event.shopper)) {
      return #err("Invalid identifiers")
    };
    if (terminal(event.status) != (event.netCents == 0)) { return #err("Invalid net amount for status") };
    switch (entry(state, event.eventId)) {
      case (?prior) {
        if (prior.event != event) { return #err("Event ID conflict") };
        return #ok(state, #duplicate)
      };
      case null {}
    };

    var previousUnits = 0;
    var outcome : Outcome = #applied;
    switch (Trie.get(state.orders, key(event.orderId), Text.equal)) {
      case null {};
      case (?order) {
        let prior = order.latest;
        if (prior.shopper != event.shopper) { return #err("Order belongs to another shopper") };
        previousUnits := order.units;
        if (event.revision < prior.revision) { outcome := #stale }
        else if (event.revision == prior.revision) {
          if (event.status != prior.status or event.netCents != prior.netCents) { return #err("Revision conflict") };
          outcome := #duplicate
        } else if ((terminal(prior.status) and not terminal(event.status)) or event.netCents > prior.netCents
                   or (prior.status == #partialRefund and event.status == #paid)) {
          return #err("Invalid order transition")
        }
      }
    };

    var next = state;
    var delta : Int = 0;
    if (outcome == #applied) {
      let units = Nat.min(100, Nat64.toNat(event.netCents) / 100);
      let shopperUnits = Nat.sub(balance(state, event.shopper), previousUnits) + units;
      let total = Nat.sub(state.total, previousUnits) + units;
      if (shopperUnits > 500 or total > 1000) { return #err("Simulation budget exceeded") };
      delta := (units : Int) - previousUnits;
      let shopperKey = { key = event.shopper; hash = Principal.hash(event.shopper) };
      next := { state with total;
        balances = Trie.put(state.balances, shopperKey, Principal.equal, shopperUnits).0;
        orders = Trie.put(state.orders, key(event.orderId), Text.equal, { latest = event; units }).0
      }
    };
    let entries = Trie.put(next.events, key(event.eventId), Text.equal, { event; outcome; delta; verifier }).0;
    #ok({ next with events = entries }, outcome)
  }
}
