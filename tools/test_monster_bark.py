"""Monster bark bubble offline test (MonsterLabels; lines_pack 2, dev2 BarkService contract
docs/design/lines_pack_server_2026-10-07.md section 3): a new BarkAt on a monster model shows its Bark in a speech bubble
over the head for Config.Barks.Show s within Config.Barks.MaxDistance studs (the same line with a new BarkAt shows
again; an old bark of a monster streaming in, a far monster, Barks.Enabled = false or an empty line show nothing); the
BarkBubble art (9-slice, TextRect) or a white pill with a soft navy rim; a newer bark replaces the bubble (never two).
A23-74 (user 2026-10-07 "not cute"): 150-172 x 44 px for one line, wider with more letters (utf8), two lines at H2 up to
W2Max; the Head font (Fredoka One without UIKit); the family art (Config.Barks.BubbleFamily / BubbleArt) only once its
Id is uploaded, else BarkBubble; a jelly pop (UIScale Back + Size Elastic from the tail corner), a looping float, a
shrink + fade in the last B.Out s, every tween cancelled when the bubble is destroyed or replaced, none with reduced
motion. Runs the real MonsterLabels.luau + Config.luau in tools/fixtures/monster_bark_offline.luau.
Status "passed" only when the fixture passes AND every mutation was applied and caught.
Report: docs/art/verification_2026-10-07/offline_monster_bark_2026-10-07.json
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "src/ReplicatedStorage/Shared/Config.luau"
LABELS = ROOT / "src/StarterPlayer/StarterPlayerScripts/MonsterLabels.luau"
FIXTURE = ROOT / "tools/fixtures/monster_bark_offline.luau"
BINARY = ROOT / "build/luau_cli_0_741/luau.exe"
OUT = ROOT / "docs/art/verification_2026-10-07/offline_monster_bark_2026-10-07.json"

MUTATIONS = [
    ("every tick shows the bubble again", "\tif prev == at then return end\n", ""),
    ("old barks show when a monster streams in",
     "\tif prev == nil and workspace:GetServerTimeNow() - at > (tonumber(cfg.Show) or 3) then return end -- old news\n", ""),
    ("far monsters bark at me", "\tif me and (root.Position - me).Magnitude > (tonumber(cfg.MaxDistance) or 60) then return end\n", ""),
    ("the switch is ignored", 'if cfg.Enabled == false or type(at) ~= "number" then return end', 'if type(at) ~= "number" then return end'),
    ("the bubble never goes away",
     "\t\tif bubble.Parent then bubble:Destroy() end -- a newer bark already replaced (destroyed) it otherwise\n", ""),
    ("the tail floats in the middle", "bb.SizeOffset = Vector2.new(0.5, 0.5)", "bb.SizeOffset = Vector2.new(0, 0)"),
    ("no code fallback without the art", "\tif not art then\n\t\tart = Instance.new(\"Frame\")", "\tif false then\n\t\tart = Instance.new(\"Frame\")"),
    ("two bubbles stack on one monster", "\tif old then old:Destroy() end\n", ""),
    # A23-74 (user 2026-10-07): size, font, family art, motion
    ("letters counted as bytes", "local n = utf8.len(text) or #text", "local n = #text"),
    ("the old GothamBold font", "label.Font = Enum.Font.FredokaOne", "label.Font = Enum.Font.GothamBold"),
    ("the family art is never used", '{ B.ArtKey(kind), "BarkBubble" }', '{ "BarkBubble" }'),
    ("an un-uploaded family key is used", 'and def.Id ~= "" then return key end', "then return key end"),
    ("the fallback has square corners", "corner.CornerRadius = UDim.new(0.5, 0)", "corner.CornerRadius = UDim.new(0, 14)"),
    ("reduced motion still wobbles", "\tif reduced then\n", "\tif false then\n"),
    ("the bubble vanishes with no fade", "\tif fadeOut then task.delay(math.max(0, show - B.Out), fadeOut) end\n", ""),
    ("a replaced bubble still fades", "\t\tif not bb.Parent then return end -- a newer bark already replaced it\n", ""),
    ("the float loop never stops", "for _, tw in tweens do tw:Cancel() end", "local _ = tweens"),
]


def lua_str(s: str) -> str:
    level = 0
    while ("]" + "=" * level + "]") in s:
        level += 1
    return f"[{'=' * level}[{s}]{'=' * level}]"


def run(config: str, labels: str, name: str):
    path = ROOT / f"build/monster_bark_offline{name}.luau"
    path.write_text("local CONFIG_SOURCE = " + lua_str(config) + "\nlocal LABELS_SOURCE = " + lua_str(labels) + "\n"
                    + FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
    result = subprocess.run([str(BINARY), str(path)], cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
                            errors="replace", timeout=120)
    match = re.search(r"MONSTER_BARK_SUMMARY checks=(\d+) failed=(\d+)", result.stdout)
    ok = result.returncode == 0 and match is not None and match[2] == "0"
    fails = [ln for ln in (result.stdout + result.stderr).splitlines() if ln.startswith("CHECK_FAIL") or "error" in ln.lower()]
    return ok, (int(match[1]) if match else 0), fails, result


def main():
    config = CONFIG.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    labels = LABELS.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
    ok, checks, fails, result = run(config, labels, "")
    print(result.stdout, end="")
    print(result.stderr, end="")
    rows = []
    for name, old, new in MUTATIONS:
        applied = labels.count(old) == 1
        caught, why = False, []
        if applied:
            m_ok, _, why, _ = run(config, labels.replace(old, new), "_mut")
            caught = not m_ok
        rows.append({"mutation": name, "applied": applied, "caught": caught, "failures": why[:3]})
        print(f"mutation {'caught' if caught else ('NOT CAUGHT' if applied else 'NOT APPLIED')}: {name}")
    passed = ok and all(r["applied"] and r["caught"] for r in rows)
    report = {"status": "passed" if passed else "failed", "checks": checks, "failedChecks": fails,
              "mutations": {"total": len(rows), "applied": sum(r["applied"] for r in rows),
                            "caught": sum(r["caught"] for r in rows), "results": rows},
              "sourceSHA256": {p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in (CONFIG, LABELS)},
              "fixtureSHA256": hashlib.sha256(FIXTURE.read_bytes()).hexdigest(), "studioCalls": 0,
              "contract": __doc__.split("Status")[0].strip(),
              "limitations": "How the bubble looks over real monsters (size, overlap with the name tag, phones) is a Studio check."}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Status: {report['status']} (mutations {report['mutations']['caught']}/{report['mutations']['total']})")
    print(f"Report: {OUT.relative_to(ROOT).as_posix()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
