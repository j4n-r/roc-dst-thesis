# Platform for the messaging experiment. Nodes are pure: the app's functions
# use `->` (not `=>`), so they cannot perform any effect. Everything a node wants
# to happen in the world (sending a message, logging) is returned as data, and
# the host decides what to do with it. That keeps the host in full control of
# the run, which is what deterministic simulation needs.
platform ""
	# What every app must define:
	# - `Model`: one node's state, shaped however the app likes.
	# - `Msg`: the app's message type. Nodes send each other Msg values; the host
	#   routes them without looking inside.
	# - `program`: a record with `init` and `receive`. Both return the same
	#   "step" record: the node's new state, messages to send, and log lines.
	requires {
		[Model : model, Msg : msg] for program : {
			# Start node `id` (first U64) in a cluster of `cluster_size` nodes (second U64).
			init : U64, U64 -> { model : Model, outbox : List({ to : U64, msg : Msg }), log : List(Str) },
			# Handle one message: current state, sender id, message.
			receive : Model, U64, Msg -> { model : Model, outbox : List({ to : U64, msg : Msg }), log : List(Str) },
		}
	}
	# No modules for apps to import: everything an app needs is in the required types.
	exposes []
	packages {}
	# Roc functions exported to the host as C symbols.
	provides {
		"roc_init_for_host": init_for_host,
		"roc_receive_for_host": receive_for_host,
	}
	# No effects at all: the host never gets called back except for memory and crashes.
	hosted {}
	# Linker inputs, looked up in targets/<target>/. `app` is the compiled Roc code,
	# libhost.a is the Rust host (./build.sh), the rest is musl's C runtime.
	targets: {
		inputs_dir: "targets/",
		x64musl: { inputs: ["crt1.o", "libhost.a", "libunwind.a", app, "libc.a", "libzigc.a", "libcompiler_rt.a"] },
	}

# Host-facing wrappers. `Model` and `Msg` differ per app, so the host can't know
# their size or layout. Boxing them puts each on the heap and gives the host one
# pointer to store (state) or route (message) without ever looking inside.

## Start one node; the host keeps the returned state box and sends the outbox.
init_for_host : U64, U64 -> { model : Box(Model), outbox : List({ to : U64, msg : Box(Msg) }), log : List(Str) }
init_for_host = |id, cluster_size| to_host((program.init)(id, cluster_size))

## Deliver one message from node `from` to the node whose state is `boxed_model`.
receive_for_host : Box(Model), U64, Box(Msg) -> { model : Box(Model), outbox : List({ to : U64, msg : Box(Msg) }), log : List(Str) }
receive_for_host = |boxed_model, from, boxed_msg| to_host((program.receive)(Box.unbox(boxed_model), from, Box.unbox(boxed_msg)))

# Convert the app's step record into the host-facing one by boxing the state
# and every outgoing message.
to_host : { model : Model, outbox : List({ to : U64, msg : Msg }), log : List(Str) } -> { model : Box(Model), outbox : List({ to : U64, msg : Box(Msg) }), log : List(Str) }
to_host = |step| {
	model: Box.box(step.model),
	outbox: step.outbox.map(|out| { to: out.to, msg: Box.box(out.msg) }),
	log: step.log,
}
