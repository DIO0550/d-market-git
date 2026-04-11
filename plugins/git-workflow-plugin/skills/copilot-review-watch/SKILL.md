---
name: copilot-review-watch
description: PRに対してCopilotなどのレビュー完了をMonitorツール経由でバックグラウンド監視し、未解決指摘があればpr-fix-reviewへチェーンするスキル。PR作成直後にレビュー完了を待ち受ける場面で使う。「Copilotレビュー待って」「レビュー監視」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Bash(gh *), Bash(git *), Read, Monitor, Skill
argument-hint: [PR番号]
---

# Copilotレビュー監視

PRに対してCopilot等のレビュー完了をバックグラウンドで待ち受け、完了したら次のアクションにつなぐスキル。

## ワークフロー

```
1. owner/repo/PR番号を解決
   ↓
2. .pr-review-fix/.pr-review-fix.yml の review-watch 設定を読む
   ↓
3. Monitor ツールで監視スクリプトを起動
   ↓
4. ストリーミング行の行頭タグで分岐
   ↓
5. 終了条件（DONE / UNRESOLVED）でアクション実行
```

## 引数

- `<PR番号>` 必須。monitor 対象のPR

owner/repo は `gh repo view --json owner,name -q '.owner.login + "/" + .name'` で解決する。

## 設定ファイル

`.pr-review-fix/.pr-review-fix.yml` の `review-watch` セクションを読み込む。

```yaml
review-watch:
  reviewers:
    - copilot
  on-unresolved: notify  # auto: pr-fix-review へ自動チェーン / notify: 報告のみ
  poll-interval: 30      # 秒
```

### 各キーの意味

- `reviewers`: 監視対象レビュアーのログイン名トークン（配列）。**部分一致・大文字小文字無視**。`copilot` の1語で `Copilot` と `copilot-pull-request-reviewer` の両方にマッチする
- `on-unresolved`: 未解決スレッドを検知したときの挙動
  - `auto`: 検知と同時に `pr-fix-review <PR番号>` スキルをチェーン呼び出し
  - `notify`: 指摘件数と `path:line` を報告して監視を終了する（デフォルト）
- `poll-interval`: GraphQL ポーリング間隔（秒）。デフォルト 30

設定ファイルまたはキーが存在しない場合のデフォルト: `reviewers=["copilot"]` / `on-unresolved=notify` / `poll-interval=30`。

## 手順

### 1. 設定読み込み

```bash
# 設定ファイルがあれば読む。無ければデフォルトを使う
CONFIG=.pr-review-fix/.pr-review-fix.yml
```

設定値の取得は `yq` に依存せず、`grep` と `awk` で十分（キー構造が固定のため）。読み取れない場合はデフォルトにフォールバックする。

### 2. Monitor ツールで監視起動

```
Monitor tool:
  command: ${CLAUDE_PLUGIN_ROOT}/skills/copilot-review-watch/scripts/monitor-copilot-review.sh <owner> <repo> <PR番号>
  env:
    WATCH_REVIEWERS=<reviewers をカンマ区切りに変換>
    POLL_INTERVAL=<poll-interval>
```

スクリプトは stdout に以下のいずれかを1行ずつ出力する:

| タグ | 意味 |
|:-|:-|
| `COPILOT_PENDING reason=...` | 対象レビュアーのレビューが未提出 |
| `COPILOT_UNRESOLVED count=N locations=path1:line1,...` | 未解決スレッドあり |
| `COPILOT_DONE submitted=<iso8601> all_resolved=true` | 完了 |

### 3. 行頭タグで分岐

- `COPILOT_PENDING`: 何もしない（次の行を待つ）
- `COPILOT_UNRESOLVED`:
  - 監視を停止
  - `on-unresolved=auto` の場合: `Skill` ツールで `pr-fix-review <PR番号>` を呼ぶ
  - `on-unresolved=notify` の場合: `locations` の `path:line` と件数をユーザーへ報告して終了
- `COPILOT_DONE`: 監視停止、完了を報告

## 注意事項

### パイプのバッファリング

監視スクリプトを拡張してパイプを追加する場合、バッファリング解除を**必須**とする。これを怠ると Monitor tool へのイベント到達が数分遅延する:

- `grep --line-buffered`
- `jq --unbuffered`
- `sed -u` (GNU sed)

現状のスクリプトは単発の `gh api` → `jq` → `printf` なのでバッファリング問題は発生しない。

### Copilot ハンドルの揺れ

Copilot のレビュー投稿者ログインは文脈により `Copilot` / `copilot-pull-request-reviewer` / その他の揺れが発生する。`reviewers` に `copilot`（部分一致）で指定しておけばすべてにマッチする。再レビュー依頼時の `gh pr edit --add-reviewer` で渡すハンドルは固定値 `copilot-pull-request-reviewer` を使う。

### 完了時の報告フォーマット

```
## Copilot レビュー監視結果

- 状態: DONE / UNRESOLVED / (タイムアウト時) PENDING
- 提出時刻: {submitted_at}
- 未解決件数: {n}
- 未解決箇所: {path:line, ...}
- 次のアクション: {pr-fix-review 起動 / 報告のみ}
```
