# memex

自分とAIエージェントの外部記憶装置。
Slack, Linear の情報をObsidian vaultにdumpし、永続的な外部記憶として活用する。
Notionは必要に応じて都度参照する（定期同期はしない）。

## Architecture

- **このリポジトリ**: 収集の「仕組み」（スキル・設定）
- **Obsidian vault**: データの「置き場」（markdown files）

## Configuration

- 設定ファイル: `config.yaml`（リポジトリルート）
- **スキルはこのファイルから vault パスや各種設定を読み取ること。**

### Vault Directory Structure

```
vault/
├── context/          # 構造化・整理済みの長期記憶
├── snapshot/         # Linear / Slack の定期ダンプ（日付ベース）
│   └── YYYY-MM-DD/   # 日付フォルダ
│       ├── slack.md
│       └── linear.md
├── journal/          # 日次の思考・感想・ふりかえり
└── MEMORY.md         # vaultの読み方・構造説明
```

## Writing Rules

- 全レイヤーAI書き込み可
- `snapshot/` は日付フォルダ単位で保存。同日の再実行は**上書き**
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

# 日付フォルダ一覧
ls "$VAULT"/snapshot/

# 特定日付の snapshot を読む
cat "$VAULT/snapshot/2026-03-31/slack.md"

# 2日分を比較する
diff "$VAULT/snapshot/2026-03-30/slack.md" "$VAULT/snapshot/2026-03-31/slack.md"
```

## Frontmatter Format

すべてのファイルに以下のfrontmatterを付与する:

```yaml
---
source: linear | slack | manual
collected_at: 2026-04-01T09:00
ttl: 7d
auto_generated: true    # falseなら人間が書いた
---
```

## Skills

- `/sync-all`: sync-slack と sync-linear を並列実行し snapshot を一括更新する
- `/sync-linear`: LinearからIssue・スプリント情報を収集し `snapshot/linear.md` に書き出す
- `/sync-slack`: Slackからメンション・参加スレッド情報を収集し `snapshot/slack.md` に書き出す
- `/sync-notion`: config.yaml で指定した Notion ページをカスタム prompt に従って vault に書き出す
- `/distill`: snapshot + journal を読み context/ に構造化ナレッジを生成・更新する
- `/daily-planner`: 指定日のカレンダー・Linear・Slack を統合して TODO を生成し journal に書き出す（省略時は明日）
- `/journal`: 日次の思考・感想・ふりかえりを `journal/YYYY-MM-DD.md` に書き出す
