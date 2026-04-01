---
name: sync-notion
description: config.yamlで指定されたNotionページを取得し、ページごとのカスタムpromptに従ってvaultに書き出す
user-invocable: true
argument-hint: (引数なし)
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

# sync-notion

config.yaml の `notion.watch_pages` で指定された Notion ページを取得し、
ページごとに設定されたカスタム prompt に従って vault に書き出す。

## Output

ページごとの prompt 指定による（snapshot/ や context/ など）

## Configuration

リポジトリルートの `config.yaml` から設定を読み取る。

```yaml
notion:
  watch_pages:
    - url: "https://www.notion.so/xxxxx"
      prompt: |
        このページはスプリント計画の議事録です。
        snapshot/{作成日}/notion-sprint-plan.md に要点をまとめて書き出してください。
        - 決定事項を箇条書きで抽出
        - アクションアイテムと担当者を明記
    - url: "76ef9eff7d174ccca3a199c44bd83f98"
      prompt: |
        このDBの各ページはメモです。
        context/memo-{slug}.md に構造化して書き出してください。
```

### config フォーマット

| フィールド | 必須 | 説明 |
|-----------|------|------|
| `url` | はい | Notion ページの URL または ID |
| `prompt` | はい | ページ取得後に実行するカスタム指示 |

prompt 内で使える変数（スキルが自動で展開する）:
- `{vault.path}` — vault のパス
- `{page_title}` — ページタイトル
- `{page_url}` — ページの Notion URL
- `{page_id}` — ページ ID
- `{created_date}` — ページ作成日（YYYY-MM-DD）
- `{today}` — 実行日（YYYY-MM-DD）
- `{slug}` — ページタイトルから生成したスラッグ

## Procedure

### 1. 設定の読み込み

`config.yaml` を読み、`vault.path` と `notion.watch_pages` を取得する。
`date` コマンドで現在日時を取得する。

### 2. 各ページの処理

`notion.watch_pages` の各エントリについて順に処理する:

#### a) Notion ページの取得

`notion-fetch(id={url}, include_discussions=true)` でページ内容を取得する。

必要に応じて `notion-get-comments(page_id={ID}, include_all_blocks=true)` でコメントも取得する。

#### b) 変数の展開

prompt 内の変数を実際の値に置き換える。

#### c) prompt の実行

展開された prompt に従って、取得したページ内容を処理する。

prompt が指示する内容に従い:
- 指定されたパスにファイルを書き出す
- 指定されたフォーマットで整形する
- 指定されたフィルタリング・抽出を行う

### 3. vault へのコミット

全ページの処理完了後、`scripts/commit-vault.sh` を実行する。

```bash
bash scripts/commit-vault.sh
```

## Rules

- prompt がファイルパスを指定していない場合のデフォルト: `snapshot/{created_date}/notion-{slug}.md`
- prompt の指示を最優先する。スキルのデフォルト動作より prompt が優先
- Notion ページの全文コピーはしない（prompt で明示的に指示されない限り）
- ページ末尾に Notion リンクを必ず記載する
- frontmatter は出力先に合わせる（snapshot なら `auto_generated: true`、context なら `false`）
- `watch_pages` が空配列 or url が空文字の場合はスキップする
