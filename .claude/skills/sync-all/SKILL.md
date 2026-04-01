---
name: sync-all
description: sync-slack, sync-linear, sync-notion を並列実行し、snapshot を一括更新する
user-invocable: true
argument-hint: (引数なし)
allowed-tools:
  - Read
  - Bash
  - Skill
  - Agent
---

# sync-all

sync-slack, sync-linear, sync-notion をサブエージェントとして並列実行し、snapshot を一括更新するオーケストレータースキル。

## Procedure

### 1. サブエージェントの並列起動

Agent ツールを使い、以下の3つを**同時に**起動する（1つのメッセージで3つの Agent tool call を送る）:

#### Agent 1: sync-slack
```
prompt: "/sync-slack を実行してください。リポジトリルートは /Users/wakwak/src/github.com/wakwak3125/memex です。"
description: "sync-slack execution"
```
Skill ツールで `sync-slack` を呼び出す。

#### Agent 2: sync-linear
```
prompt: "/sync-linear を実行してください。リポジトリルートは /Users/wakwak/src/github.com/wakwak3125/memex です。"
description: "sync-linear execution"
```
Skill ツールで `sync-linear` を呼び出す。

#### Agent 3: sync-notion
```
prompt: "/sync-notion を実行してください。リポジトリルートは /Users/wakwak/src/github.com/wakwak3125/memex です。"
description: "sync-notion execution"
```
Skill ツールで `sync-notion` を呼び出す。

### 2. 結果の報告

すべてのエージェントが完了したら、結果をまとめてユーザーに報告する:

- 各スキルの成功/失敗
- エラーがあった場合はその内容
