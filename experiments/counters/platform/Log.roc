import Host

Log := [].{
	## Print a line through the host.
	line! : Str => {}
	line! = |message| Host.log!(message)
}
