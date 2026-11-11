# The token ring from main.roc, plus a second fiber per node.
#
# The relay fiber is main.roc's loop: it blocks in `Net.recv!`, forwards tokens,
# and starts a new token after 100ms of silence. The heartbeat fiber sends a
# ping to the next node every 150ms. It keeps that schedule while the relay is
# blocked, which a single blocking loop can't do without folding the heartbeat
# into its recv timeout (as Raft timers have to on basic-cli today).
app [main!] { pf: platform "../platform/main.roc" }

import pf.Net
import pf.Clock
import pf.Stdout
import pf.Fiber

cluster_size = 3
stop_at_ms = 1000
recv_timeout_ms = 100
heartbeat_ms = 150

main! = |id| {
	Fiber.spawn!(|| heartbeat!(id, 1))
	if id == 0 {
		Net.send!(next(id), "token from n0 at 0ms")
	} else {
		{}
	}
	relay!(id, 0)
}

# Every `heartbeat_ms`, ping the next node, until it's time to stop.
heartbeat! : U64, U64 => {}
heartbeat! = |id, n| {
	Clock.sleep!(heartbeat_ms)
	if Clock.now!() >= stop_at_ms {
		Stdout.line!("heartbeat stopping after ${(n - 1).to_str()} pings")
	} else {
		Net.send!(next(id), "ping ${n.to_str()} from n${id.to_str()}")
		heartbeat!(id, n + 1)
	}
}

# Forward tokens, log pings, and start a token after a silence, until it's time
# to stop. `seen` counts the tokens this node has received.
relay! : U64, U64 => {}
relay! = |id, seen| {
	now = Clock.now!()
	if now >= stop_at_ms {
		Stdout.line!("relay stopping after ${seen.to_str()} tokens")
	} else {
		match Net.recv!(recv_timeout_ms) {
			Ok({ from, msg }) =>
				if Str.starts_with(msg, "ping") {
					Stdout.line!("got '${msg}'")
					relay!(id, seen)
				} else {
					Stdout.line!("got '${msg}' from n${from.to_str()}")
					Net.send!(next(id), msg)
					relay!(id, seen + 1)
				}
			Err(Timeout) => {
				Clock.sleep!(id * 10)
				Net.send!(next(id), "token from n${id.to_str()} at ${Clock.now!().to_str()}ms")
				relay!(id, seen)
			}
		}
	}
}

next = |id| (id + 1) % cluster_size
