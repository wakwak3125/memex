---
name: reflect
description: daily/weekly/monthlyの振り返りを生成しjournal/に書き出す
user-invocable: true
argument-hint: "<daily|weekly|monthly> [日付] (例: daily, weekly 2026-03-31, monthly 2026-03)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# reflect

振り返りを生成し、journal/ 配下に書き出す。
daily / weekly / monthly の3種類に対応し、それぞれ異なる粒度・観点でまとめる。

## Output

- `{vault.path}/journal/daily/{YYYY-MM-DD}.md`
- `{vault.path}/journal/weekly/{YYYY-MM-DD}〜{YYYY-MM-DD}.md` （週の開始日〜終了日）
- `{vault.path}/journal/monthly/{YYYY-MM}.md`

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Procedure

### 1. 設定と日時の取得

- `config.yaml` を読み、`vault.path` を取得する
- `date` コマンドで**現在の日時**を取得する（推測しない）
- 引数からモードと対象期間を決定する:
  - 第1引数: `daily` / `weekly` / `monthly`（必須。省略時はユーザーに確認する）
  - 第2引数: 対象日付（省略時は今日を基準にする）

### 2. データソースの収集

対象期間に応じて以下のデータを読み込む:

#### daily

- `{vault.path}/snapshot/{対象日}/` 配下の全ファイル（slack.md, linear.md, claude-log.md 等）
- `{vault.path}/journal/timeline/{対象日}.md`

#### weekly

- `{vault.path}/snapshot/{月曜〜日曜の各日}/` 配下の全ファイル
- `{vault.path}/journal/timeline/{月曜〜日曜の各日}.md`
- `{vault.path}/journal/daily/{月曜〜日曜の各日}.md`（あれば）

#### monthly

- `{vault.path}/journal/weekly/{対象月内の各週}.md`（あれば）
- `{vault.path}/journal/daily/{対象月内の各日}.md`（あれば）
- `{vault.path}/journal/timeline/{対象月内の各日}.md`
- `{vault.path}/snapshot/{対象月内の各日}/` 配下

データが多い場合、weekly と monthly では daily/weekly の振り返りを優先的に参照し、
生の snapshot は補足的に使う。

### 3. 振り返りの生成

#### daily — その日やったこと

観点:
- **やったこと**: 具体的な作業内容を箇条書きで列挙
- **進捗**: 各タスクの進捗状況（完了 / 途中 / ブロック）
- **メモ**: 気づき・学び・明日に持ち越すこと

フォーマット:

```markdown
---
type: reflect-daily
date: YYYY-MM-DD
collected_at: YYYY-MM-DDThh:mm
auto_generated: true
---

# Daily Reflect: YYYY-MM-DD

## やったこと

- {具体的な作業内容}
- {具体的な作業内容}

## 進捗

| タスク | ステータス | メモ |
|--------|-----------|------|
| {タスク名} | 完了 / 途中 / ブロック | {補足} |

## メモ

- {気づき・学び・持ち越し}
```

#### weekly — その週にやったこと・得たもの・ふりかえり

観点:
- **サマリー**: 週全体を1-2文で総括
- **やったこと**: 主要な成果・完了タスクを列挙
- **得たもの**: 新しく学んだこと・知見・スキル
- **よかったところ**: うまくいったこと・良い判断だったこと
- **もう少しよくできたところ**: 改善点・反省点
- **来週に向けて**: 持ち越しタスク・意識すること

フォーマット:

```markdown
---
type: reflect-weekly
week_start: YYYY-MM-DD
week_end: YYYY-MM-DD
collected_at: YYYY-MM-DDThh:mm
auto_generated: true
---

# Weekly Reflect: YYYY-MM-DD〜YYYY-MM-DD

## サマリー

{週全体の総括 1-2文}

## やったこと

- {主要な成果・完了タスク}

## 得たもの

- {新しく学んだこと・知見}

## よかったところ

- {うまくいったこと}

## もう少しよくできたところ

- {改善点・反省点}

## 来週に向けて

- {持ち越し・意識すること}
```

#### monthly — 中長期的なキャリア形成に紐付く内容

**追加の入力データ**: monthly では上記データソースに加えて以下を必ず読む:
- `{vault.path}/context/career.md` — キャリア目標・ギャップ・アクションプラン

観点:
- **サマリー**: 月全体を2-3文で総括
- **主な成果**: プロジェクト単位での成果
- **インパクト**: 自分の仕事が組織・プロダクト・チームに与えた影響を定量・定性で記述。数字があれば数字で（パフォーマンス改善、バグ修正による障害削減、リリースしたチケット数等）
- **判断の振り返り**: 月中にした重要な意思決定（技術選定、やらない判断、方針決定等）をリストアップし、結果がどうだったかを評価する。snapshot/slack.md や journal/timeline/ から判断の瞬間とその後の展開を追跡する
- **成長・学び**: スキル・知識面での成長
- **キャリアへの接続**: `context/career.md` のキャリア目標を参照し、今月の活動が目標にどう寄与したか、ギャップは縮まったかを評価する。アクションプランの進捗も確認する
- **他者からの評価**: #all-thank-you での言及、他チームからの相談・感謝など、外部からの評価シグナルを抽出する
- **来月に向けて**: フォーカスすべきテーマ・取り組み

フォーマット:

```markdown
---
type: reflect-monthly
month: YYYY-MM
collected_at: YYYY-MM-DDThh:mm
auto_generated: true
---

# Monthly Reflect: YYYY-MM

## サマリー

{月全体の総括 2-3文}

## 主な成果

### {プロジェクト名}
- {成果の概要}

## インパクト

- {定量データ: パフォーマンス改善値、完了チケット数、レビュー数等}
- {定性データ: チームへの影響、顧客への影響}

## 判断の振り返り

| 判断 | 背景 | 結果・学び |
|------|------|-----------|
| {何を決めたか} | {なぜその判断をしたか} | {結果どうなったか} |

## 成長・学び

- {スキル・知識面での成長}

## キャリアへの接続

- {career.md の目標に対する今月の寄与}
- {ギャップの変化: 縮まったか、新たに見えたか}
- {アクションプランの進捗}

## 他者からの評価

- {#all-thank-you での言及}
- {他チームからの相談・感謝}
- {1on1でのフィードバック（journal に記録があれば）}

## 来月に向けて

- {フォーカスすべきテーマ}
```

### 4. ファイルへの書き出し

- 出力先ディレクトリが存在しない場合は作成する
- 同じ対象期間のファイルが既に存在する場合は**上書き**する（再生成）
- 1ファイル200行以内を守る

### 5. vault へのコミット

```bash
bash scripts/commit-vault.sh
```

## Rules

- `date` コマンドで日時を取得する。推測しない
- データソースにない情報は書かない。推測で内容を埋めない
- daily は事実ベースで淡々と。weekly/monthly は少し俯瞰した視点で
- monthly はキャリア・成長の観点を意識する。単なる作業ログにしない
- monthly では必ず `context/career.md` を読み、キャリア目標との接続を言語化する
- 既存の context/ ファイル（me.md, projects.md 等）と重複する内容は書かない。振り返りに固有の観点に集中する
- frontmatter の `auto_generated` は `true`
- 1ファイル200行以内を厳守
