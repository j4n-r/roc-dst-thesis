app [main!] { pf: platform "./platform/main.roc" }

import pf.OsStr

main! = |args| {
	if args.len() != 2 {
		return Err(Exit(23))
	}
	if args.get(0)? != OsStr.utf8("node-2") {
		crash "wrong first argument"
	}
	if args.get(1)? != OsStr.utf8("a-long-argument-to-exercise-Roc-heap-allocation") {
		crash "wrong second argument"
	}
	Ok({})
}
