# A token ring with timeouts, written like a normal blocking program.
#
# Node 0 starts a token; every node passes whatever it receives on to the next
# node. Messages can be delayed or dropped, so a node that hears nothing for
# 100ms starts a new token. Every node stops after one second.
#
# Nothing here knows about the simulator: the same code would run against a real
# network if the platform implemented Net, Clock and Stdout for real.
app [main!] { pf: platform "../platform/main.roc" }

import pf.Net
import pf.Clock
import pf.Stdout

cluster_size = 3
stop_at_ms = 1000
recv_timeout_ms = 100

main! = |id| {
	if id == 0 {
		Net.send!(next(id), "token from n0 at 0ms")
	} else {
		{}
	}
	run!(id, 0)
}

# Wait for a token and pass it on, until it's time to stop. `seen` counts the
# tokens this node has received.
run! = |id, seen| {
	now = Clock.now!()
	if now >= stop_at_ms {
		Stdout.line!("stopping after ${seen.to_str()} tokens")
	} else {
		match Net.recv!(recv_timeout_ms) {
			Ok({ from, msg }) => {
				Stdout.line!("got '${msg}' from n${from.to_str()}")
				Net.send!(next(id), msg)
				run!(id, seen + 1)
			}
			Err(Timeout) => {
				# Back off a little, longer for higher ids, so nodes don't all
				# start a token at the same moment.
				Clock.sleep!(id * 10)
				Net.send!(next(id), "token from n${id.to_str()} at ${Clock.now!().to_str()}ms")
				run!(id, seen)
			}
		}
	}
}

next = |id| (id + 1) % cluster_size
