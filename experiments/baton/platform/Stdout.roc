import Host

Stdout := [].{
	## Print a line.
	line! : Str => {}
	line! = |message| Host.stdout_line!(message)
}
