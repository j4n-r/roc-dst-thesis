#!/usr/bin/env python3
"""Check a deletion-only basic-cli subset and link it to a fail-closed probe host."""

import argparse
import difflib
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
PUBLIC = "Duration Env IOErr Monotonic OsStr Random Sleep Stderr Stdout Tcp Utc".split()
PRIVATE = "Host Resource InternalDateTime InternalUtf16".split()
ENV = {"env_var!", "env_dict!", "env_platform!", "env_program_name!"}
HOSTED = ENV | {
    "random_seed_u32!", "random_seed_u64!", "sleep_nanos!", "monotonic_now!", "utc_now!",
    "stdout_line!", "stdout_write!", "stdout_write_bytes!",
    "stderr_line!", "stderr_write!", "stderr_write_bytes!",
    "tcp_listen!", "tcp_local_port!", "tcp_accept!", "tcp_listener_close!", "tcp_connect!",
    "tcp_read_up_to!", "tcp_read_exactly!", "tcp_read_until!", "tcp_read_line!", "tcp_write!",
}


def run(*command, cwd=None):
    print("+", " ".join(map(str, command)), flush=True)
    return subprocess.run(list(map(str, command)), cwd=cwd, text=True, capture_output=True)


def require(result):
    print(result.stdout + result.stderr, flush=True)
    result.check_returncode()
    return result.stdout


def delete_between(source, start, end):
    begin = source.index(start)
    finish = source.index(end, begin)
    return source[:begin] + source[finish:]


def trim(platform):
    for path in platform.glob("*.roc"):
        if path.stem not in PUBLIC + PRIVATE + ["main"]:
            path.unlink()

    path = platform / "main.roc"
    source = path.read_text()
    source = source[source.index('platform ""'):]
    exposed = re.search(r"exposes \[([^\]]+)\]", source).group(1).split(", ")
    for name in exposed:
        if name not in PUBLIC:
            source = source.replace(name + ", ", "", 1)
    source = delete_between(source, "\t\t# HTTP data types", "\t}\n\tprovides")
    source = "".join(line for line in source.splitlines(keepends=True)
                     if not (match := re.search(r'"hosted_[^"]+": Host\.([\w!]+)', line))
                     or match.group(1) in HOSTED)
    source = "".join(line for line in source.splitlines(keepends=True)
                     if not line.startswith("import ") or line.strip().split()[1] in PUBLIC + PRIVATE)
    source = source.replace("\t\t\tTty.disable_raw_mode!() ?? {}\n", "")
    source = source.replace("\t\t\t# Leave raw mode first, so the message is not printed without line breaks.\n", "")
    path.write_text(source)

    path = platform / "Host.roc"
    lines = path.read_text().splitlines(keepends=True)
    kept = []
    include_continuation = False
    for line in lines:
        match = re.match(r"\t([\w!]+) :", line)
        if match:
            include_continuation = match.group(1) in HOSTED | {"NativeOsStr"}
            if include_continuation:
                kept.append(line)
        elif include_continuation and (line.startswith("\t\t") or line == "\t}\n"):
            kept.append(line)
        else:
            include_continuation = False
            if line in ("import IOErr\n", "import Resource\n", "Host :: [].{\n", "}\n"):
                kept.append(line)
    path.write_text("".join(kept))

    path = platform / "Resource.roc"
    source = path.read_text()
    for name in ("Child", "FileReader", "FileWriter", "HttpResponse", "SqliteDb", "SqliteRows"):
        source = re.sub(rf"\t{name} : [^\n]+\n", "", source)
    path.write_text(source)

    path = platform / "Env.roc"
    source = path.read_text().replace("import Path\n", "")
    source = delete_between(source, "\t## Reads the [current working directory]", "\t## Gets the program name")
    source = delete_between(source, "\t## Atomically create a private directory", "\n}\n")
    path.write_text(source)


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--basic-cli", type=Path, default=ROOT / "basic-cli")
parser.add_argument("--roc-source", type=Path, default=ROOT / "project/roc")
parser.add_argument("--rev", default="cbd8b47c7ef180daa4f10138191ba7215a249e96")
parser.add_argument("--glue-rev", default="48d3369")
parser.add_argument("--roc", default="roc")
args = parser.parse_args()
require(run(args.roc, "version"))
require(run("rustc", "--version"))

with tempfile.TemporaryDirectory(prefix="roc-subset-link-") as temp:
    work = Path(temp)
    archive = work / "upstream.tar"
    with archive.open("wb") as output:
        subprocess.run(["git", "-C", str(args.basic_cli), "archive", args.rev, "platform"], stdout=output, check=True)
    upstream = work / "upstream"
    upstream.mkdir()
    with tarfile.open(archive) as source:
        source.extractall(upstream, filter="data")
    platform = work / "platform"
    shutil.copytree(upstream / "platform", platform)
    trim(platform)
    diff = []
    for original in sorted((upstream / "platform").glob("*.roc")):
        path = platform / original.name
        old = original.read_text()
        new = path.read_text() if path.exists() else ""
        # A deletion-only trim may shorten a one-line exposes list, but never
        # introduces characters, reorders retained text or changes signatures.
        remaining = iter(old)
        assert all(char in remaining for char in new), original.name
        diff.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                       fromfile=f"upstream/{original.name}", tofile=f"subset/{original.name}"))
    (work / "trim.patch").write_text("".join(diff))
    header = (platform / "main.roc").read_text()
    symbols = dict(re.findall(r'"(hosted_[^"]+)": Host\.([\w!]+)', header))
    assert set(symbols.values()) == HOSTED
    assert "http:" not in header
    print(f"Deletion-only trim: {len(PUBLIC)} public modules, {len(PRIVATE)} private modules, {len(symbols)} hosted functions", flush=True)
    print("Retained native symbols:\n" + "\n".join(sorted(symbols)), flush=True)

    for fixture in HERE.glob("*.roc"):
        shutil.copy2(fixture, work / fixture.name)
        require(run(args.roc, "check", "--no-cache", "-j4", work / fixture.name))

    # Check every excluded public module, plus filesystem operations nested in
    # an otherwise retained module. Missing API must be a checking error.
    upstream_header = (upstream / "platform/main.roc").read_text()
    exposed = re.search(r"exposes \[([^\]]+)\]", upstream_header).group(1).split(", ")
    exclusions = {name: f"import pf.{name}\n" for name in exposed if name not in PUBLIC}
    exclusions["Env.cwd!"] = "import pf.Env\n"
    for name, imports in exclusions.items():
        body = "_ = Env.cwd!()\n" if name == "Env.cwd!" else ""
        negative = work / "excluded.roc"
        negative.write_text('app [main!] { pf: platform "./platform/main.roc" }\n'
                            + imports + "main! = |_args| {\n" + body + "Ok({})\n}\n")
        result = run(args.roc, "check", "--no-cache", "-j4", negative)
        diagnostic = result.stdout + result.stderr
        assert result.returncode != 0 and name in diagnostic, diagnostic
        print(f"Excluded API rejected: {name}", flush=True)

    glue_spec = work / "RustGlue.roc"
    spec = subprocess.run(["git", "-C", str(args.roc_source), "show", f"{args.glue_rev}:src/glue/src/RustGlue.roc"],
                          text=True, capture_output=True, check=True).stdout
    glue_spec.write_text(spec)
    require(run(args.roc, "glue", "--no-cache", glue_spec, work, platform / "main.roc"))
    abi = (work / "roc_platform_abi.rs").read_text()
    declarations = re.findall(r"pub fn (hosted_\w+)\(([^;]*?)\)([^;]*);", abi)
    assert {name for name, _, _ in declarations} == set(symbols)
    stubs = []
    for name, params, result in declarations:
        stubs.append(f'#[no_mangle]\npub extern "C" fn {name}({params}){result} {{ tripwire("{name}") }}\n')
    (work / "stubs.rs").write_text("\n".join(stubs))
    shutil.copy2(HERE / "host.rs", work / "host.rs")
    host = platform / "targets/x64musl/libhost.a"
    require(run("rustc", "--edition=2021", "--crate-type=staticlib", "--target=x86_64-unknown-linux-musl",
                "-Cpanic=abort", "-Copt-level=2", work / "host.rs", "-o", host))
    result = run("nm", "--defined-only", "--extern-only", host)
    result.check_returncode()
    exported = result.stdout
    native = set(re.findall(r"\b(hosted_\w+)\s*$", exported, re.MULTILINE))
    assert native == set(symbols), native ^ set(symbols)
    for backend in ("dev", "speed"):
        for fixture in ("smoke", "effects"):
            binary = work / f"{fixture}-{backend}"
            require(run(args.roc, "build", "--no-cache", "-j4", f"--opt={backend}",
                        "--target=x64musl", f"--output={binary}", work / f"{fixture}.roc"))
            result = run(binary, "node-2", "a-long-argument-to-exercise-Roc-heap-allocation")
            print(result.stdout + result.stderr, flush=True)
            if fixture == "smoke":
                assert result.returncode == 0 and result.stdout == "" and result.stderr == ""
                assert run(binary).returncode == 23
            else:
                assert result.returncode == 86 and result.stderr == "LINK-ONLY HOST: hosted_env_platform\n"

    # A successful link is meaningful only if the workload really references
    # retained operations. Remove a late TCP operation and require a link error.
    missing = "hosted_tcp_read_until"
    (work / "stubs.rs").write_text("\n".join(stub for stub in stubs if f"fn {missing}(" not in stub))
    require(run("rustc", "--edition=2021", "--crate-type=staticlib", "--target=x86_64-unknown-linux-musl",
                "-Cpanic=abort", "-Copt-level=2", work / "host.rs", "-o", host))
    for backend in ("dev", "speed"):
        result = run(args.roc, "build", "--no-cache", "-j4", f"--opt={backend}",
                     "--target=x64musl", f"--output={work / 'must-not-link'}", work / "effects.roc")
        diagnostic = result.stdout + result.stderr
        assert result.returncode != 0 and missing in diagnostic, diagnostic
        print(f"Missing retained symbol rejected by linker ({backend}): {missing}", flush=True)
    print("Subset API checks, subset-only symbol audit, native links and fail-closed startup probes passed.", flush=True)
