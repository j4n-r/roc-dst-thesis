# Platform for the baton experiment. Unlike `messaging`, apps here are written in
# the ordinary effectful style, like a basic-cli program: `main!` runs a loop and
# blocks in `Net.recv!` or `Clock.sleep!`. The host decides what those calls do:
# the simulating host in src/ runs several app instances, one per node, and
# interleaves them deterministically from a seed.
platform ""
	requires {
		# Run node `id` (the U64) until it returns.
		main! : U64 => {}
	}
	exposes [Net, Clock, Stdout, Fiber]
	packages {}
	provides {
		"roc_main": main_for_host!,
		# Run a fiber the app passed to `Host.spawn!`.
		"roc_run_fiber": run_fiber_for_host!,
	}
	# Each effect the app can perform, implemented in Rust under this symbol name.
	hosted {
		"hosted_send": Host.send!,
		"hosted_recv": Host.recv!,
		"hosted_now_millis": Host.now_millis!,
		"hosted_sleep_millis": Host.sleep_millis!,
		"hosted_stdout_line": Host.stdout_line!,
		"hosted_spawn": Host.spawn!,
	}
	targets: {
		inputs_dir: "targets/",
		x64musl: { inputs: ["crt1.o", "libhost.a", "libunwind.a", app, "libc.a", "libzigc.a", "libcompiler_rt.a"] },
	}

import Host
import Net
import Clock
import Stdout
import Fiber

main_for_host! : U64 => {}
main_for_host! = |id| main!(id)

run_fiber_for_host! : Box(() => {}) => {}
run_fiber_for_host! = |task| {
	run! = Box.unbox(task)
	run!()
}
