---
name: fetch-notion
description: NotionページURLを指定して内容を取得し、context/に構造化して書き出す
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

Notion ページの内容を取得し、vault の context/ に構造化して書き出す。
定期同期ではなく、必要な時に必要なページだけ取り込むオンデマンド方式。

## Output

- `{vault.path}/context/{ファイル名}.md`

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

ディスカッションがある場合は `notion-get-comments(page_id={ID}, include_all_blocks=true)` でコメント詳細も取得する。

### 4. 既存 context の確認

`{vault.path}/context/{ファイル名}.md` が既に存在するか確認する。

- **存在する**: 既存内容を読み、Notion の情報で差分更新する
- **存在しない**: 新規作成する

### 5. context ファイルへの書き出し

Notion ページの内容を構造化して context/ に書き出す。

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
- 元ページへのリンクを末尾に記載し、詳細はそちらで参照できるようにする
- ディスカッション・コメントがあれば重要なもののみ要約して含める
- 既存ファイルの更新時は、前回の内容を尊重し差分更新する

### 6. vault へのコミット

```bash
bash scripts/commit-vault.sh
```

## Rules

- 1ファイル200行以内を厳守
- 事実ベース。Notion ページにない情報は書かない
- ページ末尾に Notion リンクを必ず記載する
- frontmatter の `auto_generated` は `false`
- `ttl: null`（context は期限なし）
