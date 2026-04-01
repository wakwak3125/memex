---
name: sync-memory
description: vault の MEMORY.md と context/ を現在の vault 状態に合わせて整備する
user-invocable: true
argument-hint: "[sync | status] (省略時は sync。status で現在の状態を表示)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# sync-memory

vault の `MEMORY.md`（ナビゲーションガイド）と `context/` を現在の vault 状態に合わせて整備するスキル。

## 対象

| ファイル | 役割 |
|----------|------|
| `{vault.path}/MEMORY.md` | vault のナビゲーションガイド。エージェントが vault を読む際の起点 |
| `{vault.path}/context/*.md` | 構造化された長期記憶。ユーザー情報・プロジェクト・ドメイン知識 |

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Procedure

### 1. 設定の読み込み

`config.yaml` を読み、`vault.path` を取得する。

```
VAULT="{vault.path}"
```

### 2. 現在の状態を収集

以下をすべて読み込む:

- `$VAULT/MEMORY.md` — 現在のナビゲーションガイド
- `$VAULT/context/*.md` — context ファイル（memo/ 配下含む）
- `$VAULT/snapshot/` — 日付フォルダ一覧（`ls -d "$VAULT"/snapshot/*/`）
- `$VAULT/journal/` — journal ファイル一覧

### 3. モードの判定

#### a) `status`（状態表示）

vault の現在の状態を表示して終了:
- MEMORY.md の内容
- context/ のファイル一覧と最終更新日
- snapshot/ の日付フォルダ一覧
- MEMORY.md と実際の vault 構造の不整合があればハイライト

#### b) `sync`（同期 — デフォルト）

以下のステップ 4〜6 を実行。

### 4. MEMORY.md の更新

`$VAULT/MEMORY.md` を vault の現在の状態に合わせて更新する。
このファイルは vault を初めて読むエージェントの起点になるため、正確さが重要。

#### 更新する内容

- **ディレクトリ構造**: 実際のフォルダ・ファイル構成と一致させる
  - `snapshot/` が日付フォルダベース（`YYYY-MM-DD/`）であることを明記
  - `context/memo/` サブディレクトリの存在を反映
  - `journal/` の追記ルールを反映
- **必読ファイル一覧**: `context/` 配下のファイルを列挙（memo/ 含む）
- **参照パス例**: snapshot の参照方法を日付フォルダベースで記載

#### フォーマット

```markdown
# memex

{一行説明}

## ディレクトリ構造

{実際の構造に合わせたツリー + 説明}

## 書き込みルール

{CLAUDE.md の Writing Rules と一致させる}

## エージェントへの指示

{必読ファイル・条件付き参照ファイルのリスト}
```

### 5. context/ の整合性チェック

context/ 配下のファイルを確認し、軽微な問題を修正する:

- MEMORY.md の必読ファイルリストに記載されているファイルが実際に存在するか
- context/ に新しいファイルが増えていれば MEMORY.md に反映
- 明らかに古くなった情報（完了済みプロジェクト等）があれば報告（自動修正はしない）

### 6. vault へのコミット

vault 側に変更があった場合のみ `scripts/commit-vault.sh` を実行する。

```bash
cd "$VAULT" && git status --porcelain
# 変更があれば
bash {repo_root}/scripts/commit-vault.sh
```

## Rules

- MEMORY.md は vault の「目次」。実際の vault 構造と常に一致させる
- context/ の大幅な書き換えは distill スキルの管轄。このスキルでは軽微な修正（typo、古い情報の更新）のみ許可
- 同期は冪等であること。何度実行しても同じ結果になる
