# memex

自分とAIエージェントの外部記憶装置。
Slack, Notion, Linear の情報をObsidian vaultにdumpし、永続的な外部記憶として活用する。

## Architecture

- **このリポジトリ**: 収集の「仕組み」（スキル・設定）
- **Obsidian vault**: データの「置き場」（markdown files）

## Configuration

- 設定ファイル: `config.yaml`（リポジトリルート）
- **スキルはこのファイルから vault パスや各種設定を読み取ること。**

### Vault Directory Structure

```
vault/
├── context/     # 構造化・整理済みの長期記憶
├── snapshot/    # Linear / Slack / Notion の定期ダンプ
├── journal/     # 日次の思考・感想・ふりかえり
└── MEMORY.md    # vaultの読み方・構造説明
```

## Writing Rules

- 全レイヤーAI書き込み可
- `snapshot/` は**上書き**（追記しない）。履歴はGitで管理
- `journal/` は**追記**。同日に複数回書いても積み重ねる
- `context/` は1ファイル200行以内。詳細はSaaS側へのリンクで代替

## Vault の Git 管理

vault は Git リポジトリとして管理する。snapshot の書き出し後は自動コミットを行い、日単位で履歴を残す。

### コミットルール

vault への変更コミットは `scripts/commit-vault.sh` を実行する。
同日のコミットは amend でまとめ、コミットメッセージは `snapshot: YYYY-MM-DD` 形式で統一される。

```bash
bash scripts/commit-vault.sh
```

### 過去の snapshot を参照する

ユーザーから「昨日の〜」「前回の〜」「〜と比較して」等の指示があった場合:

```bash
VAULT="{vault.path}"

# 履歴一覧（日付単位のコミット）
git -C "$VAULT" log --oneline snapshot/

# 特定日付のコミットを探す
git -C "$VAULT" log --oneline --grep="snapshot: 2026-03-31"

# 直前の内容を取得
git -C "$VAULT" show HEAD~1:snapshot/slack.md

# 現在との差分
git -C "$VAULT" diff HEAD~1 -- snapshot/slack.md

# 特定コミットの内容
git -C "$VAULT" show {commit_hash}:snapshot/slack.md
```

## Frontmatter Format

すべてのファイルに以下のfrontmatterを付与する:

```yaml
---
source: linear | slack | notion | manual
collected_at: 2026-04-01T09:00
ttl: 7d
auto_generated: true    # falseなら人間が書いた
---
```

## Skills

- `/sync-linear`: LinearからIssue・スプリント情報を収集し `snapshot/linear.md` に書き出す
- `/sync-slack`: Slackからメンション・参加スレッド情報を収集し `snapshot/slack.md` に書き出す
- `/journal`: 日次の思考・感想・ふりかえりを `journal/YYYY-MM-DD.md` に書き出す
