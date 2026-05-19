#!/bin/bash
# ─────────────────────────────────────────────────────────────
# 🚀 JLPT N1 學習教材 自動部署腳本
# 用法：在 Terminal 執行  bash deploy.sh
# ─────────────────────────────────────────────────────────────

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

echo "📚 正在更新 lessons.json..."

# ── 掃描所有 N1_*.html，重新產生 lessons.json ─────────────────
python3 - <<'PYEOF'
import os, json, re
from pathlib import Path

folder = Path(os.getcwd())
files  = sorted(folder.glob("N1_*.html"), reverse=True)

# 舊教材沒有 W#D# 命名，這裡手動標註課本對應
LEGACY_WD = {
    "N1_2026-04-08_性格語彙＋こそ文法.html":         "W1D1",
    "N1_2026-05-06_気持ち語彙＋ものとして文法.html": "W1D2",
}

def guess_tags(title):
    tags = []
    if any(w in title for w in ["語彙","単語","言葉","語"]): tags.append("語彙")
    if any(w in title for w in ["文法","Grammar","こそ","〜","ば","たら","のに","こと","もの","から","まで"]):
        tags.append("文法")
    if not tags: tags = ["語彙", "文法"]
    return tags

lessons = []
for f in files:
    # 支援兩種命名格式：
    #   1. N1_YYYY-MM-DD_title.html         (舊版)
    #   2. N1_YYYY-MM-DD_W#D#_title.html    (新版，含週/日索引)
    m = re.match(r"N1_(\d{4}-\d{2}-\d{2})_(?:(W\d+D\d+)_)?(.*?)\.html$", f.name)
    if not m: continue
    date     = m.group(1)
    week_day = m.group(2) or LEGACY_WD.get(f.name)  # 新版有檔名標記 / 舊版查 LEGACY_WD
    raw_title= m.group(3)
    title    = raw_title.replace("_", " ").replace("＋", " ＋ ")

    # 拆出 week / day 數字
    week = day = None
    if week_day:
        wd = re.match(r"W(\d+)D(\d+)", week_day)
        if wd:
            week = int(wd.group(1))
            day  = int(wd.group(2))

    # 從檔案內 <div class="meta"> 抽 subtitle
    try:
        content = f.read_text(encoding="utf-8")
        meta = re.search(r'<div class="meta">[^<]*[|｜]([^<]+)</div>', content)
        subtitle = meta.group(1).strip() if meta else ""
    except:
        subtitle = ""

    entry = {
        "date":     date,
        "title":    title,
        "subtitle": subtitle,
        "file":     f.name,
        "tags":     guess_tags(title),
    }
    if week_day:
        entry["weekDay"] = week_day      # e.g. "W1D3"
        entry["week"]    = week
        entry["day"]     = day
    lessons.append(entry)

with open("lessons.json", "w", encoding="utf-8") as out:
    json.dump(lessons, out, ensure_ascii=False, indent=2)

print(f"  ✅ 找到 {len(lessons)} 份教材")
for L in lessons:
    tag = f"[{L.get('weekDay','--')}]"
    print(f"     {L['date']} {tag} {L['title']}")
PYEOF

# ── Git 推送 ───────────────────────────────────────────────────
echo ""
echo "🔧 正在提交並推送到 GitHub..."

git add .

# 只有在有變更時才 commit
if git diff --cached --quiet; then
  echo "  ℹ️  沒有新的變更，不需要推送"
else
  TODAY=$(date "+%Y-%m-%d")
  git commit -m "📚 ${TODAY} 新增學習教材"
  git push origin main
  echo ""
  echo "✨ 部署完成！"
  echo "   🌐 網站：https://ronglife.github.io/jlptn1"
  echo "   ⏱  GitHub Pages 約 1 分鐘後更新"
fi
