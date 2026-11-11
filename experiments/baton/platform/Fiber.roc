import Host

## Concurrency inside one node, without async/await: each fiber is ordinary
## blocking code, and a fiber blocked in `Net.recv!` or `Clock.sleep!` lets the
## node's other fibers run. Fibers never run at the same time.
Fiber := [].{
	## Start `task!` as a new fiber on this node and return at once. The node
	## finishes when all its fibers have returned.
	spawn! : (() => {}) => {}
	spawn! = |task!| Host.spawn!(Box.box(task!))
}
