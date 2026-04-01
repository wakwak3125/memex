---
name: journal
description: 日次の思考・感想・ふりかえりをvaultのjournal/に書き出す
user-invocable: true
argument-hint: "<自由テキスト> (例: 今日はタグ機能の実装がいい感じに進んだ)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
---

# journal

日次の思考・感想・ふりかえりを vault に記録する。

## Output

- `{vault.path}/journal/YYYY-MM-DD.md`

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Procedure

### 1. 設定の読み込み

`config.yaml` を読み、`vault.path` を取得する。
`date` コマンドで現在の日付・時刻を取得する（**推測しない。必ずコマンドで取得する**）。
出力ファイルパス: `{vault.path}/journal/YYYY-MM-DD.md`

### 2. 内容の整理

ユーザーから渡された引数（自由テキスト）をもとに、journal エントリを構成する。

- ユーザーの言葉をそのまま活かす。過度に要約したり装飾しない
- 箇条書きでも文章でも、ユーザーの書き方に合わせる
- 引数が空の場合はユーザーに何を書きたいか聞く

### 3. ファイルへの書き出し

#### その日のファイルが存在しない場合 → 新規作成

```markdown
---
date: YYYY-MM-DD
auto_generated: true
---

# YYYY-MM-DD

## HH:MM

{ユーザーの内容}
```

#### その日のファイルが既に存在する場合 → 追記

ファイル末尾に新しいセクションを追記する:

```markdown

## HH:MM

{ユーザーの内容}
```

### 4. vault へのコミット

`scripts/commit-vault.sh` を実行して vault リポジトリにコミットする。

```bash
bash scripts/commit-vault.sh
```

## Rules

- ファイル名は `YYYY-MM-DD.md` 形式で統一する（例: `2026-04-01.md`）
- 時刻見出し（`## HH:MM`）は24時間表記、JST
- 既存ファイルへの追記時、既存の内容は絶対に変更しない
- ユーザーの言葉を尊重する。言い換えや補足は最小限にする
- frontmatter の `auto_generated` は AI が書いた場合 `true`、ユーザーが口述した内容でも AI が記録した場合は `true`
