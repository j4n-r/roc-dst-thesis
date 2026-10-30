import Host

## A stand-in for basic-cli's Tcp: one-way messages between numbered nodes.
Net := [].{
	## Send `msg` to node `to`. Fire and forget: it may arrive late, or never.
	send! : U64, Str => {}
	send! = |to, msg| Host.send!(to, msg)

	## Wait up to `timeout_ms` for the next message.
	recv! : U64 => Try({ from : U64, msg : Str }, [Timeout])
	recv! = |timeout_ms| {
		r = Host.recv!(timeout_ms)
		if r.got Ok({ from: r.from, msg: r.msg }) else Err(Timeout)
	}
}
