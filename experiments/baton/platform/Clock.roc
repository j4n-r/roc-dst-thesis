import Host

Clock := [].{
	## Milliseconds since the node started.
	now! : () => U64
	now! = || Host.now_millis!()

	## Block for `ms` milliseconds.
	sleep! : U64 => {}
	sleep! = |ms| Host.sleep_millis!(ms)
}
