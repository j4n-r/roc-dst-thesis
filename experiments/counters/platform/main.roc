# The platform is the layer between the Rust host and a Roc app. It decides
# what an app must provide, which modules apps can import, which functions the
# host can call, and which effects the host implements.
platform ""
	# What every app on this platform must define. The app exposes a type named
	# `Model` (its state; each app picks its own shape, `model` is the type
	# variable standing for it) and a record `program` with these two functions.
	# `=>` marks an effectful function: it may call effects like `Log.line!`.
	requires {
		[Model : model] for program : {
			# Build the starting state of one instance. The Str is the instance name.
			init! : Str => Model,
			# Take the current state and one event, return the next state.
			update! : Model, Event => Model,
		}
	}
	# Modules an app can import, as `import pf.Log` and `import pf.Event`.
	# Host stays internal: apps go through Log instead of calling the host directly.
	exposes [Log, Event]
	# Other Roc packages this platform depends on: none.
	packages {}
	# Roc functions exported to the host as C symbols. The string is the symbol
	# name the Rust host declares and calls (see roc_platform_abi.rs).
	provides {
		"roc_init_for_host": init_for_host!,
		"roc_update_for_host": update_for_host!,
	}
	# Functions declared in Roc but implemented in Rust. When Roc calls
	# `Host.log!`, it jumps to the Rust function exported as `roc_log`.
	hosted {
		"roc_log": Host.log!,
	}
	# What the linker combines into the final executable, per target, looked up in
	# targets/<target>/. `app` is the compiled Roc code; libhost.a is our Rust host
	# (built by ./build.sh); the rest is musl's C runtime and support libraries.
	targets: {
		inputs_dir: "targets/",
		x64musl: { inputs: ["crt1.o", "libhost.a", "libunwind.a", app, "libc.a", "libzigc.a", "libcompiler_rt.a"] },
	}

import Log
import Event
import Host

# The two functions below are the host-facing wrappers. They adapt the app's
# `program` to types the host can handle over the C ABI.
#
# `Model` differs per app, so the host can't know its size or layout. Wrapping it
# in `Box` puts it on the heap and hands the host a single pointer: the host just
# stores that pointer per instance and passes it back later, never looking inside.

## Create one instance. The host keeps the returned box and passes it back to update.
init_for_host! : Str => Box(Model)
init_for_host! = |name| Box.box((program.init!)(name))

## Glue can't represent a single-tag union, so the host sends events as a U8 code.
update_for_host! : Box(Model), U8 => Box(Model)
update_for_host! = |boxed_model, code| {
	# Translate the host's numeric code into the Event the app understands.
	# Codes must match the constants in src/lib.rs.
	event = match code {
		0 => Increment
		# `crash` stops the program; the host's roc_crashed prints the message.
		_ => crash "unknown event code ${code.to_str()}"
	}
	# Unwrap the state, run the app's update!, and box the new state for the host.
	Box.box((program.update!)(Box.unbox(boxed_model), event))
}
