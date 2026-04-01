# memex

自分とAIエージェントの外部記憶装置。
Slack, Notion, Linear の情報をObsidian vaultにdumpし、永続的な外部記憶として活用する。

## Architecture

- **このリポジトリ**: 収集の「仕組み」（スキル・設定）
- **Obsidian vault**: データの「置き場」（markdown files）

## Vault

- Path: `~/Documents/vault/00-memex/`
- **スキルはこのパスを参照すること。** ユーザーが変更した場合はここだけ書き換えれば全スキルに反映される。

### Directory Structure

```
memex/
├── context/     # 構造化・整理済みの長期記憶
├── snapshot/    # Linear / Slack / Notion の定期ダンプ
├── inbox/       # 未分類の一時置き場
└── MEMORY.md    # vaultの読み方・構造説明
```

## Writing Rules

- 全レイヤーAI書き込み可
- 書き込みは**上書き**（追記しない）。履歴はGitで管理
- `context/` は1ファイル200行以内。詳細はSaaS側へのリンクで代替
- `inbox/` の内容は `context/` に昇格後、元エントリを削除

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
