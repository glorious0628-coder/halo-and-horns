"""
효과음 듣기판: build/sfx_game/cand.json + art/sfx/sources.json + Config.Audio 크기로 한 장짜리 HTML을 만든다.
고른 소리(art/sfx)와 다른 후보를 눌러서 들어 보고, 콤보 동전·말소리·자동 0.5배처럼 게임이 바꾸는 높이·크기도 들어 본다.
소리는 MP3(아이폰도 재생)로 바꿔 data URI로 넣는다(파일 하나, 바깥 요청 없음).
  py tools/sfx_board.py <out.html>
"""

import base64
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfx_game as sg  # noqa: E402

MP3 = os.path.join(sg.OUT, "mp3")

# name -> (Korean label, when it plays, group)
LABEL = {
    "SwingBlade": ("칼 휘두르기", "전사가 휘두를 때. 대장장이는 0.85배로 낮게, 맨손은 1.3배로 짧게", "전투"),
    "SwingMagic": ("마법 쏘기", "마법사가 쏠 때. 연금술사는 0.9배", "전투"),
    "SwingBow": ("활 쏘기", "궁수의 화살이 나가는 순간", "전투"),
    "SwingWhistle": ("펫 부르는 휘파람", "펫 조련사의 펫이 들이받을 때", "전투"),
    "HitThud": ("퍽", "고블린·플레이어·대왕을 맞힐 때. 내가 맞으면 0.8배로 낮게", "전투"),
    "HitSquish": ("말랑", "슬라임을 맞힐 때. 유령은 조금 높게", "전투"),
    "HitClack": ("딱", "해골을 맞힐 때", "전투"),
    "HitCrit": ("치명타", "치명타가 터질 때", "전투"),
    "KillPop": ("뽕", "몬스터를 잡았을 때", "보상"),
    "Coin": ("동전", "잡을 때마다. 연속으로 잡으면 한 음씩 올라가요(8번째에 한 옥타브)", "보상"),
    "LevelUp": ("레벨 업", "내 레벨이 오를 때", "보상"),
    "Reward": ("보상 받기", "퀘스트 보상, 희귀 드롭", "보상"),
    "WindowOpen": ("창 열기", "가방·지도·목록 창이 열릴 때", "화면"),
    "WindowClose": ("창 닫기", "창이 닫힐 때", "화면"),
    "No": ("안 돼요", "MP가 모자라거나 안 되는 행동을 눌렀을 때", "화면"),
    "AutoOn": ("자동 켜기", "자동 전투를 켤 때", "화면"),
    "AutoOff": ("자동 끄기", "자동 전투를 끌 때", "화면"),
    "Click": ("버튼 누름", "버튼을 누를 때", "화면"),
    "Purify": ("정화 찰랑", "착한 선택으로 빛 점수가 오를 때", "이야기와 이벤트"),
    "Devour": ("삼킴 뿌웅", "나쁜 선택으로 뿔 점수가 오를 때", "이야기와 이벤트"),
    "KingArrive": ("대왕 등장", "호박 대왕이 나타날 때. 유령 왕은 1.15배로 높게", "이야기와 이벤트"),
    "GooseHonk": ("거위 꽥", "황금 거위가 나타나거나 맞을 때", "이야기와 이벤트"),
    "TalkBlip": ("말소리 삑", "대화 글자가 한 글자씩 나올 때. 조각은 높고 빠르게, 뿔 안내자는 낮게", "이야기와 이벤트"),
}
GROUPS = ["전투", "보상", "화면", "이야기와 이벤트"]

# name_v -> short Korean note for the candidate button
NOTE = {
    "SwingBlade_a": "칼바람 + 쇠 울림", "SwingBlade_b": "바람만, 부드럽게", "SwingBlade_c": "두 번 휙휙",
    "SwingMagic_a": "올라가는 마법 + 반짝", "SwingMagic_b": "내려가는 찌릿 + 반짝", "SwingMagic_c": "짧고 밝게",
    "SwingBow_a": "활줄 퉁 + 화살 휙", "SwingBow_b": "높은 활줄", "SwingBow_c": "Kenney 퉁 + 휙",
    "SwingWhistle_a": "휘익 한 번", "SwingWhistle_b": "휘-휙 두 번",
    "HitThud_a": "주먹 + 나무 톡", "HitThud_b": "주먹 + 탁", "HitThud_c": "가벼운 톡 + 주먹",
    "HitSquish_a": "물컹한 덩어리", "HitSquish_b": "부드러운 쿵 + 물컹", "HitSquish_c": "낮은 뽀글 + 쿵",
    "HitClack_a": "마른 나무 딱", "HitClack_b": "나무 + 깡통 달그락", "HitClack_c": "가벼운 톡",
    "HitCrit_a": "센 주먹 + 톡 + 탁", "HitCrit_b": "센 주먹 + 깡통", "HitCrit_c": "센 주먹 + 쇠 울림",
    "KillPop_a": "올라가는 뽕", "KillPop_b": "Kenney 뽀록", "KillPop_c": "내려가는 퐁",
    "Coin_a": "맑은 종 한 번", "Coin_b": "동전 두 개", "Coin_c": "Kenney 유리 땡",
    "LevelUp_a": "도-미-솔-도 종 + 반짝", "LevelUp_b": "오락실 소리 + 반짝", "LevelUp_c": "Kenney 올라가는 띠링",
    "WindowOpen_a": "부드럽게 올라감", "WindowOpen_b": "밝게 올라감", "WindowOpen_c": "낮은 뽀옹",
    "WindowClose_a": "부드럽게 내려감", "WindowClose_b": "밝게 내려감", "WindowClose_c": "낮은 뽀옹 내려감",
    "No_a": "어-어 (두 음 내려감)", "No_b": "Kenney 두 음 삐빅", "No_c": "Kenney 짧은 지직",
    "AutoOn_a": "삑삑 올라감", "AutoOn_b": "Kenney 딸깍 올라감",
    "AutoOff_a": "삑삑 내려감", "AutoOff_b": "Kenney 딸깍 낮게",
    "Click_a": "Kenney 높은 톡", "Click_b": "Kenney 아주 짧은 딸깍", "Click_c": "Kenney 부드러운 퐁",
    "Reward_a": "Kenney 세 음 올라감", "Reward_b": "Kenney 밝은 띠링",
    "Purify_a": "반짝이는 종소리", "Purify_b": "부드러운 반짝", "Purify_c": "Kenney 유리 짤랑",
    "Devour_a": "후루룩 + 뿌웅 + 꿀꺽", "Devour_b": "와우 뿌우웅",
    "KingArrive_a": "깊은 종 + 쿵", "KingArrive_b": "둥… 둥! 나팔 + 종", "KingArrive_c": "깊은 종 두 개 + 쿵",
    "GooseHonk_a": "꽥 한 번", "GooseHonk_b": "꽥꽥",
    "TalkBlip_a": "부드러운 삑", "TalkBlip_b": "동그란 뿅", "TalkBlip_c": "Kenney 낮은 삑",
}


def config_audio():
    """Config.Audio Sounds volumes + Talk speeds + ComboSteps from the current Config.luau"""
    text = open(os.path.join(ROOT, "src", "ReplicatedStorage", "Shared", "Config.luau"), encoding="utf-8").read()
    block = text[text.index("Config.Audio = {"):]
    block = block[:block.index("\n}\n")]
    vol = {m.group(1): float(m.group(2)) for m in re.finditer(r"(\w+) = \{ Id = \"[^\"]*\", Volume = ([0-9.]+) \}", block)}
    talk = {m.group(1): float(m.group(2)) for m in re.finditer(r"(\w+) = ([0-9.]+)", block[block.index("Talk = {"):])}
    steps = [int(x) for x in re.search(r"ComboSteps = \{([^}]*)\}", block).group(1).split(",")]
    return vol, talk, steps


def mp3_b64(wav):
    os.makedirs(MP3, exist_ok=True)
    out = os.path.join(MP3, os.path.basename(wav)[:-4] + ".mp3")
    subprocess.run([sg.FFMPEG, "-v", "error", "-y", "-i", wav, "-codec:a", "libmp3lame", "-b:a", "112k", "-ac", "1", out],
                   check=True)
    with open(out, "rb") as f:
        return base64.b64encode(f.read()).decode("ascii")


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    out_html = sys.argv[1]
    with open(os.path.join(sg.OUT, "cand.json"), encoding="utf-8") as f:
        cand = json.load(f)
    with open(os.path.join(sg.FINAL_DIR, "sources.json"), encoding="utf-8") as f:
        picked = json.load(f)
    vol, talk, steps = config_audio()
    data = {}
    for name, (label, when, group) in LABEL.items():
        cs = []
        for c in cand.get(name, []):
            wav = os.path.join(ROOT, c["file"][:-4] + ".wav")
            cs.append({"v": c["v"], "note": NOTE.get(f"{name}_{c['v']}", c["note"]), "sec": c["sec"],
                       "kenney": any("Kenney" in s for s in c["sources"]), "b64": mp3_b64(wav)})
        data[name] = {"label": label, "when": when, "group": group, "pick": picked.get(name, {}).get("candidate"),
                      "vol": vol.get(name, 0.5), "cands": cs}
    payload = json.dumps({"sounds": data, "groups": GROUPS, "talk": talk, "steps": steps}, ensure_ascii=False)
    tpl = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "sfx_board_template.html"), encoding="utf-8").read()
    html = tpl.replace("/*__DATA__*/null", payload)
    with open(out_html, "w", encoding="utf-8", newline="\n") as f:
        f.write(html)
    print(out_html, round(len(html) / 1024), "KB")


if __name__ == "__main__":
    main()
