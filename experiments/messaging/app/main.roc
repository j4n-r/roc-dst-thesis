# A token ring: node 0 sends a token to node 1, which passes it to node 2, then
# back to node 0, and so on for 9 hops. Small, but every hop is a real message
# that the host routes between independent node instances.
#
# The app never talks to the host directly: it only returns data.
app [Model, Msg, program] { pf: platform "../platform/main.roc" }

# One node's state: who it is, how big the cluster is, how many tokens it has seen.
Model : { id : U64, cluster_size : U64, seen : U64 }

# Messages nodes send each other. `Token(hop)` carries the hop count.
Msg : [Token(U64)]

program = { init, receive }

# Node 0 starts the ring by sending the first token; the others start idle.
init = |id, cluster_size| {
	model = { id, cluster_size, seen: 0 }
	outbox = if id == 0 [{ to: next_node(model), msg: Token(1) }] else []
	{ model, outbox, log: [] }
}

# Handle a token: count it, and pass it on to the next node until hop 9.
receive = |model, from, msg|
	match msg {
		Token(hop) => {
			# `{ ..model, seen: ... }` copies model with `seen` replaced.
			next = { ..model, seen: model.seen + 1 }
			outbox = if hop < 9 [{ to: next_node(next), msg: Token(hop + 1) }] else []
			log = ["node ${model.id.to_str()}: token hop ${hop.to_str()} from node ${from.to_str()} (seen ${next.seen.to_str()})"]
			{ model: next, outbox, log }
		}
	}

# The ring neighbour: 0 -> 1 -> 2 -> 0.
next_node = |model| (model.id + 1) % model.cluster_size
