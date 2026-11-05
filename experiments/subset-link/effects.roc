app [main!] { pf: platform "./platform/main.roc" }

import pf.Duration
import pf.Env
import pf.Monotonic
import pf.Random
import pf.Sleep
import pf.Stderr
import pf.Stdout
import pf.Tcp
import pf.Utc

main! = |_args| {
	_ = Env.platform!()
	_ = Env.dict!()
	_ = Env.var!("DST_NODE")?
	_ = Env.program_name!()?
	_ = Random.seed_u32!()?
	_ = Random.seed_u64!()?
	Sleep.millis!(1)
	_ = Monotonic.now!()
	_ = Utc.now!()
	Stdout.line!("line")?
	Stdout.write!("text")?
	Stdout.write_bytes!([65, 10])?
	Stderr.line!("line")?
	Stderr.write!("text")?
	Stderr.write_bytes!([66, 10])?
	listener = Tcp.listen!("127.0.0.1", 0, Duration.millis(10))?
	_ = listener.local_port!()?
	_ = listener.accept!({ accept_timeout: After(Duration.millis(1)), io_timeout: Duration.millis(10) })?
	conn = Tcp.connect!("127.0.0.1", 8001, { connect_timeout: Duration.millis(10), io_timeout: Duration.millis(10) })?
	_ = conn.read_up_to!(3)?
	_ = conn.read_exactly!(2)?
	_ = conn.read_until!(10)?
	_ = conn.read_line!()?
	conn.write_bytes!([67, 10])?
	listener.close!()?
	Ok({})
}
