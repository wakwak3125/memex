# memex

自分と AI エージェントのための外部記憶装置。

Slack・Linear・Notion の情報を Obsidian vault に dump し、永続的な外部記憶として活用する。

## アーキテクチャ

- **このリポジトリ**: 収集の「仕組み」（Claude Code スキル・設定）
- **Obsidian vault**: データの「置き場」（markdown files）

```
vault/
├── context/          # 構造化・整理済みの長期記憶
├── snapshot/         # Linear / Slack / Notion の定期ダンプ（日付ベース）
│   └── YYYY-MM-DD/
│       ├── slack.md
│       └── linear.md
├── journal/          # 日次の思考・感想・ふりかえり
└── MEMORY.md         # vault の読み方・構造説明
```

## セットアップ

1. [Claude Code](https://claude.ai/code) をインストール
2. このリポジトリをクローン
3. `config.yaml` の `vault.path` を自分の Obsidian vault パスに変更
4. Slack・Linear・Notion・Google Calendar の MCP 連携を有効化

## 設定

`config.yaml`（リポジトリルート）で vault パスや監視対象を管理する。

```yaml
vault:
  path: ~/Documents/Note/00-memex/

slack:
  watch_channels:
    - name: "channel-name"
      limit: 50

notion:
  watch_pages:
    - url: "https://www.notion.so/..."
      prompt: |
        ページの内容をどう処理するかの指示
```

## スキル一覧

| スキル | 説明 |
|--------|------|
| `/sync-all` | sync-slack・sync-linear・sync-notion を並列実行し snapshot を一括更新 |
| `/sync-slack` | Slack からメンション・参加スレッド・主要チャンネルの情報を収集 |
| `/sync-linear` | Linear から Issue・スプリント情報を収集 |
| `/sync-notion` | config.yaml で指定した Notion ページをカスタム prompt に従って書き出し |
| `/distill` | snapshot + journal を読み、context/ に構造化ナレッジを生成・更新 |
| `/daily-planner` | カレンダー・Linear・Slack を統合して TODO を生成し journal に書き出し |
| `/journal` | 日次の思考・感想・ふりかえりを記録 |

## 書き込みルール

- 全レイヤー AI 書き込み可
- `snapshot/` は日付フォルダ単位で保存。同日の再実行は**上書き**
- `journal/` は**追記**。同日に複数回書いても積み重ねる
- `context/` は 1 ファイル 200 行以内。詳細は SaaS 側へのリンクで代替

## vault の Git 管理

vault は Git リポジトリとして管理し、snapshot 書き出し後は自動コミットで日単位の履歴を残す。

```bash
# vault へのコミット（同日は amend でまとめる）
bash scripts/commit-vault.sh
```

## Frontmatter

すべての vault ファイルに付与:

```yaml
---
source: linear | slack | manual
collected_at: 2026-04-01T09:00
ttl: 7d
auto_generated: true
---
```
