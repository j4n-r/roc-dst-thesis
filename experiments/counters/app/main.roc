# The app: plain Roc code with no knowledge of the host. It only fills in what
# platform/main.roc `requires` and uses the modules the platform `exposes`.
#
# The header exposes `Model` and `program` (the two things the platform requires)
# and names the platform this app runs on, imported under the prefix `pf`.
app [Model, program] { pf: platform "../platform/main.roc" }

import pf.Log
import pf.Event

# One instance's state. The host runs several instances of this app side by
# side; each one gets its own Model value.
Model : { name : Str, count : U64 }

# The record the platform asks for: `{ init!, update! }` is shorthand for
# `{ init!: init!, update!: update! }`.
program = { init!, update! }

# Starting state. The host picks the name ("A", "B", "C").
init! : Str => Model
init! = |name| { name, count: 0 }

# Handle one event: compute the next state, report it through the platform's
# log effect, and return it. The host keeps the returned state for the next call.
update! : Model, Event => Model
update! = |model, event| {
	next = match event {
		# `{ ..model, count: ... }` copies model with `count` replaced.
		Increment => { ..model, count: model.count + 1 }
	}
	# Effect: ends up in the Rust function roc_log, which prints the line.
	Log.line!("${next.name}: ${next.count.to_str()}")
	next
}
