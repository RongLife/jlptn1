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

def guess_tags(title):
    tags = []
    if any(w in title for w in ["語彙","単語","言葉","語"]): tags.append("語彙")
    if any(w in title for w in ["文法","Grammar","こそ","〜","ば","たら","のに"]): tags.append("文法")
    if not tags: tags = ["語彙", "文法"]
    return tags

lessons = []
for f in files:
    # filename: N1_YYYY-MM-DD_title.html
    m = re.match(r"N1_(\d{4}-\d{2}-\d{2})_(.*?)\.html$", f.name)
    if not m: continue
    date, raw_title = m.group(1), m.group(2)
    title = raw_title.replace("_", " ").replace("＋", " ＋ ")
    # Try to extract subtitle from inside the file
    try:
        content = f.read_text(encoding="utf-8")
        meta = re.search(r'<div class="meta">[^<]*\|([^<]+)</div>', content)
        subtitle = meta.group(1).strip() if meta else ""
    except:
        subtitle = ""
    lessons.append({
        "date": date,
        "title": title,
        "subtitle": subtitle,
        "file": f.name,
        "tags": guess_tags(title)
    })

with open("lessons.json", "w", encoding="utf-8") as out:
    json.dump(lessons, out, ensure_ascii=False, indent=2)

print(f"  ✅ 找到 {len(lessons)} 份教材")
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
