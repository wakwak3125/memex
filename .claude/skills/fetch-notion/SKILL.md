---
name: fetch-notion
description: NotionページURLを指定して内容を取得し、snapshot/とcontext/に書き出す
user-invocable: true
argument-hint: "<NotionページURL or ID> [context/ファイル名] (例: https://www.notion.so/xxxxx 検体検査)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - ToolSearch
  - mcp__claude_ai_Notion__notion-fetch
  - mcp__claude_ai_Notion__notion-get-comments
---

# fetch-notion

Notion ページの内容を取得し、vault に書き出す。
snapshot/ に生データを保存し、context/ に構造化して書き出す。
定期同期ではなく、必要な時に必要なページだけ取り込むオンデマンド方式。

## Output

- `{vault.path}/snapshot/{ページ作成日}/notion-{slug}.md` — 生データ
- `{vault.path}/context/{ファイル名}.md` — 構造化データ

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Procedure

### 1. 設定の読み込み

`config.yaml` を読み、`vault.path` を取得する。

### 2. 引数の解析

引数は2つ:
- **第1引数（必須）**: Notion ページの URL または ID
- **第2引数（任意）**: context/ に書き出すファイル名（拡張子なし）

第2引数が省略された場合、ページタイトルをファイル名に使う（スペースはハイフンに変換）。

### 3. Notion ページの取得

`notion-fetch(id={URL or ID}, include_discussions=true)` でページ内容を取得する。

取得結果から以下を記録:
- ページタイトル
- ページ作成日（メタデータまたはプロパティから。不明な場合は実行日を使う）
- ページ URL

ディスカッションがある場合は `notion-get-comments(page_id={ID}, include_all_blocks=true)` でコメント詳細も取得する。

### 4. snapshot/ への生データ保存

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

snapshot は上書き。同じページを再取得した場合は最新の内容で置き換える。

### 5. context/ への構造化データ書き出し

`{vault.path}/context/{ファイル名}.md` に書き出す。

既存ファイルがある場合は読み込んで差分更新する。

```markdown
---
source: manual
collected_at: {現在のISO-8601日付}
ttl: null
auto_generated: false
---

# {トピック名}

{Notion ページの内容を構造化したもの}

---
Notion: [{ページタイトル}]({ページURL})
```

#### 書き出しルール

- **1ファイル200行以内**
- Notion ページの全文コピーはしない。要点を抽出・構造化する
- 元ページへのリンクを末尾に記載する
- ディスカッション・コメントがあれば重要なもののみ要約して含める
- 既存ファイルの更新時は、前回の内容を尊重し差分更新する

### 6. vault へのコミット

```bash
bash scripts/commit-vault.sh
```

## Rules

- snapshot/ は生データを保存。context/ は構造化データを保存
- context/ は1ファイル200行以内を厳守
- 事実ベース。Notion ページにない情報は書かない
- ページ末尾に Notion リンクを必ず記載する
- frontmatter: snapshot は `auto_generated: true`、context は `auto_generated: false`
- context の `ttl: null`（期限なし）
