---
name: fetch-notion
description: NotionページURLを指定して内容を取得し、snapshot/に書き出す
user-invocable: true
argument-hint: "<NotionページURL or ID> (例: https://www.notion.so/xxxxx)"
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - ToolSearch
  - mcp__claude_ai_Notion__notion-fetch
  - mcp__claude_ai_Notion__notion-get-comments
---

# fetch-notion

Notion ページの内容を取得し、vault の snapshot/ に保存する。
定期同期ではなく、必要な時に必要なページだけ取り込むオンデマンド方式。
context/ への構造化は `/distill` で別途行う。

## Output

- `{vault.path}/snapshot/{ページ作成日}/notion-{slug}.md`

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Procedure

### 1. 設定の読み込み

`config.yaml` を読み、`vault.path` を取得する。

### 2. Notion ページの取得

`notion-fetch(id={URL or ID}, include_discussions=true)` でページ内容を取得する。

取得結果から以下を記録:
- ページタイトル
- ページ作成日（メタデータまたはプロパティから。不明な場合は実行日を使う）
- ページ URL

ディスカッションがある場合は `notion-get-comments(page_id={ID}, include_all_blocks=true)` でコメント詳細も取得する。

### 3. snapshot/ への書き出し

`{vault.path}/snapshot/{ページ作成日}/notion-{slug}.md` に書き出す。

- `{ページ作成日}`: Notion ページの作成日（YYYY-MM-DD 形式）
- `{slug}`: ページタイトルからスラッグ生成（日本語 OK、スペースはハイフン、小文字化）

```markdown
---
source: notion
collected_at: {現在のISO-8601日時}
ttl: 7d
auto_generated: true
---

# {ページタイトル}

{Notion ページの内容（markdown）}

---
Notion: [{ページタイトル}]({ページURL})
```

同じページを再取得した場合は上書きする。

### 4. vault へのコミット

```bash
bash scripts/commit-vault.sh
```

## Rules

- 事実ベース。Notion ページにない情報は書かない
- ページ末尾に Notion リンクを必ず記載する
- 同じページの再取得は上書き
