#!/usr/bin/env python3
"""Check an app authored against a trimmed platform unchanged against basic-cli."""

import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile


def run(*args):
    return subprocess.run(args, text=True, capture_output=True, check=True).stdout


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--basic-cli", type=Path, default=Path(__file__).resolve().parents[2] / "basic-cli")
parser.add_argument("--rev", default="cbd8b47")
parser.add_argument("--roc", default="roc")
parser.add_argument("--run-native", action="store_true", help="also build the upstream x64musl host and run the unchanged app")
args = parser.parse_args()
print(run(args.roc, "version").strip(), flush=True)
print("basic-cli:", run("git", "-C", str(args.basic_cli), "rev-parse", args.rev).strip(), flush=True)

with tempfile.TemporaryDirectory(prefix="roc-platform-compatibility-") as temp:
    root = Path(temp)
    archive = root / "platform.tar"
    with archive.open("wb") as output:
        command = ["git", "-C", str(args.basic_cli), "archive", args.rev]
        if not args.run_native:
            command.append("platform")
        subprocess.run(command, stdout=output, check=True)
    upstream = root / "upstream"
    upstream.mkdir()
    with tarfile.open(archive) as source:
        source.extractall(upstream, filter="data")
    original = upstream / "platform/main.roc"
    shutil.copytree(upstream / "platform", root / "trimmed/platform")
    identical = root / "identical/platform/main.roc"
    trimmed = root / "trimmed/platform/main.roc"

    # Remove one public operation, its hosted declaration and its native mapping.
    # Retained functions/signatures and all other files remain byte-identical.
    deletions = {
        "Stdout.roc": [
            "\twrite_bytes! : List(U8) => Try({}, [StdoutErr(IOErr)])\n",
            "\twrite_bytes! = |bytes| widen_stdout_err(Host.stdout_write_bytes!(bytes))\n",
        ],
        "Host.roc": ["\tstdout_write_bytes! : List(U8) => Try({}, [StdoutErr(IOErr)])\n"],
        "main.roc": ['\t\t"hosted_stdout_write_bytes": Host.stdout_write_bytes!,\n'],
    }
    for filename, lines in deletions.items():
        path = trimmed.parent / filename
        source = path.read_text()
        for line in lines:
            assert source.count(line) == 1, (filename, line)
            source = source.replace(line, "")
        path.write_text(source)
    shutil.copytree(trimmed.parent, identical.parent)

    package = root / "package"
    package.mkdir()
    (package / "main.roc").write_text('package [Greeting] { pf: platform "../trimmed/platform/main.roc" }\n')
    (package / "Greeting.roc").write_text('''import pf.Stdout
import pf.Duration

Greeting :: [].{
    hello! = || Stdout.line!("hello from a platform-dependent package")
    delay : Duration
    delay = Duration.millis(7)
}
''')
    app = root / "main.roc"
    app_source = '''app [main!] {
    pf: platform "./trimmed/platform/main.roc",
    greeting: "./package/main.roc",
}

import greeting.Greeting
import pf.Duration
import pf.Stdout

main! = |_args| {
    Greeting.hello!()?
    # A nominal platform type crosses the package/application boundary too.
    delay : Duration
    delay = Greeting.delay
    delay.sleep!()
    Stdout.line!("duration: ${delay.to_nanos().to_str()}ns")?
    Ok({})
}
'''
    app.write_text(app_source)
    # App-only switching is a control: the package still declares our platform.
    switched = root / "switched.roc"
    switched.write_text(app_source.replace("./trimmed/platform/main.roc", "./upstream/platform/main.roc"))
    switched_identical = root / "switched-identical.roc"
    switched_identical.write_text(app_source.replace("./trimmed/platform/main.roc", "./identical/platform/main.roc"))

    unsupported = root / "unsupported"
    shutil.copytree(package, unsupported)
    unsupported_module = unsupported / "Greeting.roc"
    unsupported_module.write_text((package / "Greeting.roc").read_text().replace(
        'Stdout.line!("hello from a platform-dependent package")', "Stdout.write_bytes!([65, 10])"
    ))
    unsupported_app = root / "unsupported.roc"
    unsupported_app.write_text(app_source.replace("./package/main.roc", "./unsupported/main.roc"))

    sources = [app, *package.glob("*.roc"), unsupported_app, *unsupported.glob("*.roc")]
    before = {path: hashlib.sha256(path.read_bytes()).digest() for path in sources}

    def check(label, path, replacement=None):
        command = [args.roc, "check", "--no-cache", "-j4", str(path)]
        if replacement:
            command += ["--replace-dep", str(trimmed), str(replacement)]
        result = subprocess.run(command, text=True, capture_output=True)
        print(f"\n--- {label}: exit {result.returncode} ---", flush=True)
        print(result.stdout + result.stderr, flush=True)
        return result

    results = {
        "trimmed": check("baseline: app and package declare our trimmed platform", app),
        "identical": check("replace our platform with byte-identical copy", app, identical),
        "app-only-identical": check("only app points at byte-identical copy", switched_identical),
        "app-only": check("only app points at upstream; package still declares ours", switched),
        "upstream": check("unchanged app/package: replace our platform with upstream", app, original),
        "unsupported-trimmed": check("excluded operation rejected by our platform", unsupported_app),
        "unsupported-upstream": check("excluded operation becomes available on upstream", unsupported_app, original),
    }
    if args.run_native:
        print("\nBuilding the pinned upstream basic-cli host...", flush=True)
        subprocess.run(["python3", "scripts/build.py", "--target", "x64musl"], cwd=upstream, check=True)
        expected = "hello from a platform-dependent package\nduration: 7000000ns\n"
        for backend in ("dev", "speed"):
            binary = root / f"app-{backend}"
            command = [args.roc, "build", "--no-cache", "-j4", f"--opt={backend}",
                       "--target=x64musl", f"--output={binary}", str(app),
                       "--replace-dep", str(trimmed), str(original)]
            subprocess.run(command, check=True)
            result = subprocess.run([str(binary)], text=True, capture_output=True, timeout=10)
            print(f"\n--- unchanged app on upstream host ({backend}): exit {result.returncode} ---", flush=True)
            print(result.stdout + result.stderr, flush=True)
            assert result.returncode == 0 and result.stdout == expected and result.stderr == "", backend
    assert before == {path: hashlib.sha256(path.read_bytes()).digest() for path in sources}
    print("App and package source hashes unchanged across checks.", flush=True)
    for name in ("upstream", "identical", "trimmed", "unsupported-upstream"):
        assert results[name].returncode == 0, name
    for name in ("app-only-identical", "app-only", "unsupported-trimmed"):
        assert results[name].returncode != 0, name
    for name in ("app-only-identical", "app-only"):
        assert "platform dependency mismatch" in results[name].stdout + results[name].stderr, name
    assert "write_bytes!" in results["unsupported-trimmed"].stdout + results["unsupported-trimmed"].stderr
    print("All compatibility expectations met.", flush=True)
