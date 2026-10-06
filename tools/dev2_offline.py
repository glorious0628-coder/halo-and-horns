"""Shared runner for the 게임성 개발 2 (server-only session) offline checks.

Each tools/test_<suite>.py of the server session describes its sources, the bindings it injects, its mutations and its
static checks; this module builds the harness (bindings as long-string locals + tools/fixtures/dev2_kit.luau + the
suite fixture), runs it with the installed official Luau CLI (build/luau_cli_0_741), runs every mutation on in-memory
copies of the sources (never src/) and writes one JSON report. No Studio, network, DataStore or Roblox API calls.
A report written with --no-mutations has status "passed-no-mutations" (never "passed") and mutationsSkipped = true at the
top level, like the main session's runners; it must not be committed (handoff rule).
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from typing import Callable

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "tools/fixtures/dev2_kit.luau"
SSS = ROOT / "src/ServerScriptService"
SHARED = ROOT / "src/ReplicatedStorage/Shared"


def literal(value: str) -> str:
    eq = "===="
    while "]" + eq + "]" in value:
        eq += "="
    return "[" + eq + "[" + value + "]" + eq + "]"


def between(text: str, start: str, end: str) -> str:
    first = text.find(start)
    last = text.find(end, first + len(start)) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r} / {end!r}; update the test extractor.")
    return text[first:last]


def function_block(text: str, start: str) -> str:
    """`start` up to and including the first top-level `end` line after it (a whole function)."""
    first = text.find(start)
    last = text.find("\nend\n", first) if first >= 0 else -1
    if first < 0 or last < 0:
        raise ValueError(f"Source boundary changed: {start!r}; update the test extractor.")
    return text[first:last + 5]


def strip_comments(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig").replace("\r\n", "\n")


class Suite:
    def __init__(self, *, mark: str, fixture: Path, out: Path, files: dict[str, Path],
                 bindings: Callable[[dict[str, str]], dict[str, str]],
                 mutations: list[tuple[str, str, str, str]],
                 static: Callable[[], tuple[int, list[str]]],
                 contract: str, limitations: str, world: Path | None = None):
        self.mark, self.fixture, self.out, self.files = mark, fixture, out, files
        self.world = world  # optional shared world file between the kit and the suite fixture
        self.bindings, self.mutations, self.static = bindings, mutations, static
        self.contract, self.limitations = contract, limitations

    def harness(self, sources: dict[str, str]) -> str:
        bound = self.bindings(sources)
        head = "\n".join(f"local {key} = {literal(value)}" for key, value in bound.items())
        world = (read(self.world) + "\n") if self.world else ""
        return (head + f"\nlocal SUITE_MARK = {literal(self.mark)}\n" + read(KIT) + "\n" + world + read(self.fixture))

    def run_one(self, binary: Path, text: str, directory: Path, name: str) -> dict:
        path = directory / name
        path.write_text(text, encoding="utf-8")
        proc = subprocess.run([str(binary), str(path)], cwd=ROOT, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=900)
        result = None
        for line in proc.stdout.splitlines():
            if line.startswith(self.mark + "_RESULT_JSON "):
                result = json.loads(line[len(self.mark + "_RESULT_JSON "):])
        return {"returncode": proc.returncode, "stdout": proc.stdout, "stderr": proc.stderr, "result": result}

    @staticmethod
    def failing(result: dict | None) -> set[str]:
        if not result:
            return set()
        return {f"{n['Group']} :: {n['Name']}" for n in result.get("Named", []) if n.get("Fail", 0) > 0}

    def main(self) -> int:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        parser = argparse.ArgumentParser()
        parser.add_argument("--luau", type=Path, default=ROOT / "build/luau_cli_0_741/luau.exe")
        parser.add_argument("--no-mutations", action="store_true")
        args = parser.parse_args()
        binary = args.luau.resolve()
        compiler = binary.with_name("luau-compile" + binary.suffix)
        if not binary.is_file() or not compiler.is_file():
            print("Installed Luau CLI missing; this test never downloads tools.", file=sys.stderr)
            return 1
        raw = {key: path.read_bytes() for key, path in self.files.items()}
        sources = {key: value.decode("utf-8-sig").replace("\r\n", "\n") for key, value in raw.items()}
        fixture_raw = self.fixture.read_bytes() + KIT.read_bytes() + (self.world.read_bytes() if self.world else b"")
        extra = [str(self.world)] if self.world else []
        compiled = subprocess.run([str(compiler), *(str(p) for p in self.files.values()), str(KIT), *extra, str(self.fixture)],
                                  cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True,
                                  encoding="utf-8", errors="replace", timeout=180)
        static_count, static_failures = self.static()
        mutations: list[dict] = []
        with tempfile.TemporaryDirectory(prefix=self.mark.lower() + "_") as tmp:
            tmpdir = Path(tmp)
            main_run = self.run_one(binary, self.harness(sources), tmpdir, "main.luau")
            result = main_run["result"]
            baseline = self.failing(result)
            if not args.no_mutations:
                jobs = []
                for name, key, old, new in self.mutations:
                    hits = sources[key].count(old)
                    rel = self.files[key].relative_to(ROOT).as_posix()
                    if hits != 1:
                        mutations.append({"mutation": name, "file": rel, "applied": False, "caught": False,
                                          "note": f"pattern matched {hits} times; update MUTATIONS"})
                        continue
                    mutated = dict(sources)
                    mutated[key] = sources[key].replace(old, new, 1)
                    try:
                        jobs.append((name, rel, self.harness(mutated)))
                    except ValueError as error:  # the mutation broke an extractor boundary: caught
                        mutations.append({"mutation": name, "file": rel, "applied": True, "caught": True,
                                          "crashed": True, "note": str(error), "newFailingChecks": [], "newFailingCount": 0})

                def work(index_job):
                    index, (name, rel, text) = index_job
                    out = self.run_one(binary, text, tmpdir, f"mutant_{index:02d}.luau")
                    new_fail = sorted(self.failing(out["result"]) - baseline)
                    crashed = out["result"] is None
                    return {"mutation": name, "file": rel, "applied": True, "caught": crashed or bool(new_fail),
                            "crashed": crashed, "newFailingChecks": new_fail[:6], "newFailingCount": len(new_fail)}

                with ThreadPoolExecutor(max_workers=6) as pool:
                    mutations.extend(pool.map(work, enumerate(jobs)))

        changed = [p.relative_to(ROOT).as_posix() for key, p in self.files.items() if p.read_bytes() != raw[key]]
        if self.fixture.read_bytes() + KIT.read_bytes() + (self.world.read_bytes() if self.world else b"") != fixture_raw:
            changed.append(self.fixture.relative_to(ROOT).as_posix())
        marker = re.search(self.mark + r"_OFFLINE_OK checks=(\d+) Studio/API calls=0", main_run["stdout"])
        named = result.get("Named", []) if result else []
        failing = [n for n in named if n.get("Fail", 0) > 0]
        caught = sum(1 for m in mutations if m.get("caught"))
        applied = sum(1 for m in mutations if m.get("applied"))
        ok = (compiled.returncode == 0 and main_run["returncode"] == 0 and marker is not None and not static_failures
              and not changed and all(m.get("applied") and m.get("caught") for m in mutations))
        report = {
            # review 2026-10-06: never plain "passed" without the mutation step (all runners)
            "status": ("passed-no-mutations" if args.no_mutations else "passed") if ok else "failed",
            "mutationsSkipped": bool(args.no_mutations),
            "checks": result.get("Checks", 0) if result else 0,
            "failedChecks": result.get("Failed", 0) if result else 0,
            "namedChecks": len(named),
            "namedChecksFailing": len(failing),
            "failing": [{"group": n["Group"], "check": n["Name"], "failures": n["Fail"], "passes": n["Pass"],
                         "firstFailure": n.get("FirstFailure")} for n in failing],
            "named": [{"group": n["Group"], "check": n["Name"], "pass": n["Pass"], "fail": n["Fail"]} for n in named],
            "findings": result.get("Findings", []) if result else [],
            "staticChecks": static_count,
            "staticFailures": static_failures,
            "mutations": {"total": len(self.mutations), "applied": applied, "caught": caught,
                          "skipped": bool(args.no_mutations), "results": mutations},
            "compileOk": compiled.returncode == 0,
            "compileErrors": compiled.stderr.strip(),
            "runtimeError": None if result else (main_run["stderr"].strip() or main_run["stdout"].strip())[-2000:],
            "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(raw[key]).hexdigest()
                             for key, p in self.files.items()},
            "fixtureSHA256": hashlib.sha256(fixture_raw).hexdigest(),
            "sourcesChangedDuringRun": changed,
            "studioCalls": 0, "apiCalls": 0,
            "contract": self.contract,
            "limitations": self.limitations,
        }
        self.out.parent.mkdir(parents=True, exist_ok=True)
        self.out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

        if compiled.returncode:
            print(compiled.stderr, end="")
        for line in main_run["stdout"].splitlines():
            if line.startswith("CHECK_FAIL") or line.startswith(self.mark + "_OFFLINE"):
                print(line)
        if not result:
            print(main_run["stderr"], end="")
            print(main_run["stdout"][-3000:], end="")
        for message in static_failures:
            print(f"STATIC_FAILURE {message}")
        print(f"STATIC checks={static_count} failed={len(static_failures)}")
        for m in mutations:
            print(f"MUTATION {'caught ' if m.get('caught') else 'MISSED'} {m['mutation']}"
                  + ("" if m.get("applied") else f" ({m.get('note')})"))
        if mutations:
            print(f"MUTATIONS caught={caught}/{applied} (of {len(self.mutations)})")
        if args.no_mutations:
            print("MUTATIONS SKIPPED (status passed-no-mutations: do not commit this report)")
        for f in report["findings"]:
            print(f"FINDING [{f.get('Group')}] {f.get('Text')}")
        print(f"Named checks: {len(named) - len(failing)} passed, {len(failing)} failing; "
              f"assertions {report['checks'] - report['failedChecks']}/{report['checks']}")
        print(f"Report: {self.out.relative_to(ROOT).as_posix()}")
        return 0 if ok else 1


def run(suite: Suite) -> None:
    try:
        raise SystemExit(suite.main())
    except (OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"{suite.mark} offline check failed: {error}", file=sys.stderr)
        raise SystemExit(1)
