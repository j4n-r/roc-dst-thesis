## Internal hosted-effect boundary. Applications import Net, Clock and Stdout instead.
##
## Every function here is a yield point: in the simulator the calling node stops
## inside it until the scheduler decides to run that node again.
Host := [].{
	send! : U64, Str => {}
	recv! : U64 => { got : Bool, from : U64, msg : Str }
	now_millis! : () => U64
	sleep_millis! : U64 => {}
	stdout_line! : Str => {}
}
