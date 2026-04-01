---
name: distill
description: snapshot + journal を読み、context/ に構造化されたナレッジを生成・更新する
user-invocable: true
argument-hint: "[トピック] (省略時は全体更新。例: 検体検査, projects)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# distill

snapshot/ と journal/ のデータを読み込み、context/ に構造化されたナレッジとして書き出す。
情報の「収集」から「知識」への昇華プロセス。

## Output

- `{vault.path}/context/` 配下のファイル

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Procedure

### 1. 設定の読み込み

`config.yaml` を読み、`vault.path` を取得する。

### 2. 入力データの収集

以下のファイルをすべて読み込む:

- `{vault.path}/snapshot/{最新日付}/*.md` — 最新の snapshot（日付フォルダの中で最も新しいもの）
- `{vault.path}/journal/*.md` — 直近7日分の journal
- `{vault.path}/context/*.md` — 既存の context（更新のベースにする）

Git 履歴がある場合、snapshot の前回との差分も参考にする:

```bash
VAULT="{vault.path}"
# 最新と前回の日付フォルダを比較
ls -d "$VAULT"/snapshot/*/  # 日付フォルダ一覧から最新2つを比較
```

### 3. モードの判定

引数によって動作を分岐する:

#### a) トピック指定あり（例: `/distill 検体検査`）

- 指定トピックに関連する情報を snapshot + journal から抽出
- `context/{トピック名}.md` を新規作成 or 更新
- ファイル名は日本語 OK、スペースはハイフンに変換

#### b) 既存ファイル名指定（例: `/distill projects`）

- `context/projects.md` を snapshot + journal の情報で更新
- 既存の構造（見出し等）を尊重しつつ内容を埋める

#### c) 引数なし（全体更新）

- 既存の context/ ファイル（me.md, projects.md, domain.md）を順に更新
- snapshot + journal から新たなトピックが見つかれば提案する（自動作成はしない）

### 4. context ファイルの書き出し

#### フォーマット

```markdown
---
source: manual
collected_at: {現在のISO-8601日付}
ttl: null
auto_generated: false
---

# {トピック名}

{構造化された内容}
```

#### 書き出しルール

- **1ファイル200行以内**（CLAUDE.md のルール）
- 詳細は SaaS 側へのリンクで代替（Linear の Issue URL、Notion ページ URL 等）
- 事実ベースで記述。推測や感想は入れない
- snapshot の生データをコピペしない。要点を抽出・構造化する
- 既存ファイルの更新時は、前回の内容を読んだ上で差分を反映する。全面書き換えはしない

#### 既存テンプレの構造ガイド

**me.md**:
- Role: 組織内での役割・責任範囲（linear の Project/Team 情報から）
- Work Style: 働き方の傾向（journal から）
- Environment: 技術スタック・ツール

**projects.md**:
- 担当プロジェクト一覧（linear snapshot から）
- 各プロジェクトの目的・現状・自分の役割
- チーム構成

**domain.md**:
- 業務ドメインの知識（slack/notion の技術的議論から）
- 用語集・概念の整理

### 5. 新規トピックの提案（引数なし時のみ）

snapshot + journal を分析し、独立したトピックとして切り出すべきものがあれば提案する。

```
以下のトピックを新しい context ファイルとして作成できます:
- 検体検査: 検体検査マスターの仕様・改定対応に関する知識
- データ移行: 患者データ移行の手順・注意点

作成する場合は `/distill 検体検査` のように実行してください。
```

### 6. vault へのコミット

書き出し完了後、`scripts/commit-vault.sh` を実行して vault リポジトリにコミットする。

```bash
bash scripts/commit-vault.sh
```

## Rules

- context/ の既存内容は尊重する。全面書き換えではなく差分更新
- 1ファイル200行以内を厳守
- 事実ベース。snapshot/journal にない情報は書かない
- SaaS の URL があればリンクとして保持する
- frontmatter の `auto_generated` は `false` のまま（context は手動管理扱い）
- `ttl: null`（context は期限なし）
