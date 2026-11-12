Please tune the clustered Group defaults in the Group supervisor. With five peers, the current 1 s anti-entropy heartbeat is about 16 KB/s per node even when all shards are idle; we send eight messages each way per peer. We want to cut that down without changing replication semantics.

When NervesHub.GroupSupervisor builds the child spec for NervesHub.Group, use these Group options:

- replicated_anti_entropy_interval: 5_000
- replicated_peer_lease_timeout: 30_000

That means peers exchange replication/heartbeat traffic every 5 seconds whether or not there is new data. A replica message dropped on a busy link can then wait up to 5 seconds to be repaired; that is acceptable. A peer whose Group stops while its node stays connected should be purged after the 30-second lease. Keep the lease well above the interval so a couple of lost heartbeats do not purge a live peer.

The existing Group options must stay intact: name NervesHub.Group and replicated_oplog_max_entries 1_024. NervesHub.GroupSupervisor.init/1 must still return the Group child first, with its start tuple still {_mod, :start_link, [opts]}, and opts must contain both values above. The rest of the supervision tree, including device/web cluster membership, should behave exactly as before.

This is only a default tuning change for Group. Do not change Group internals, expose these as application configuration, or alter existing replica durability behavior. Connection failures and peer expiry continue to use Group's existing error handling.
