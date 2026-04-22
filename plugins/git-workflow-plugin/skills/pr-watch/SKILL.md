---
name: pr-watch
description: PRのCI完了とレビュー完了をMonitorツール経由でバックグラウンド監視し、失敗・未解決指摘があれば次のアクションにチェーンするスキル。PR作成直後やプッシュ後にCI通過とレビュー完了を待ち受ける場面で使う。「CI監視」「レビュー監視」「PR監視して」などのリクエスト時に使用。
allowed-tools: Bash(gh *), Bash(git *), Bash(*monitor-pr.sh*), Read, Monitor, Skill
argument-hint: [PR番号]
---

# PR監視（CI＋レビュー）

PRに対してCI完了とレビュー完了をバックグラウンドで待ち受け、完了したら次のアクションにつなぐスキル。

## ワークフロー

```
1. owner/repo/PR番号を解決
   ↓
2. workflow-automation-plugin の .plugin-workspace/pull-request/.pr-review-fix.yml の pr-watch 設定を読む
   （pr-watch が無ければ review-watch にフォールバック）
   ↓
3. Monitor ツールで監視スクリプトを起動
   （auto モードでは REVIEW_LOOP / CI_LOOP を有効化）
   ↓
4. イベント処理ループ（Monitor プロセス終了まで繰り返す）
   - 通知の行頭タグで分岐（CI_* / REVIEW_*）
   - auto: 即座に Skill でアクション → ステップ4に戻る
   - notify: 記録 → ステップ4に戻る
   ↓
5. Monitor プロセス終了（両方が最終状態に達した） → 完了報告
```

## 引数

- `<PR番号>` 必須。monitor 対象のPR

owner/repo は `gh repo view --json owner,name -q '.owner.login + "/" + .name'` で解決する。

## 設定ファイル

workflow-automation-plugin の `.plugin-workspace/pull-request/.pr-review-fix.yml` の `pr-watch` セクションを読み込む（Glob: `**/workflow-automation-plugin/.plugin-workspace/pull-request/.pr-review-fix.yml`）。

```yaml
pr-watch:
  ci:
    on-failure: notify   # auto: pr-ci-fix へ自動チェーン / notify: 報告のみ
  review:
    reviewers:
      - copilot
    on-unresolved: notify  # auto: pr-fix-review へ自動チェーン / notify: 報告のみ
  poll-interval: 60        # 秒
```

### 各キーの意味

- `ci.on-failure`: CI失敗を検知したときの挙動
  - `auto`: 検知と同時に `pr-ci-fix <PR番号>` スキルをチェーン呼び出し
  - `notify`: 失敗したチェック名と詳細URLを報告して終了する（デフォルト）
- `review.reviewers`: 監視対象レビュアーのログイン名トークン（配列）。**部分一致・大文字小文字無視**。`copilot` の1語で `Copilot` と `copilot-pull-request-reviewer` の両方にマッチする
- `review.on-unresolved`: 未解決スレッドを検知したときの挙動
  - `auto`: 検知と同時に `pr-fix-review <PR番号>` スキルをチェーン呼び出し
  - `notify`: 指摘件数と `path:line` を報告して監視を終了する（デフォルト）
- `poll-interval`: ポーリング間隔（秒）。デフォルト 60

### 後方互換性

`pr-watch` セクションが存在せず `review-watch` セクションがある場合、以下のように読み替える:

| 旧キー（review-watch） | 新キー（pr-watch） |
|:-|:-|
| `reviewers` | `review.reviewers` |
| `on-unresolved` | `review.on-unresolved` |
| `poll-interval` | `poll-interval` |

この場合 `ci` セクションは存在しないものとして扱い、CI監視はデフォルト（`on-failure: notify`）で動作する。

設定ファイルまたはキーが存在しない場合のデフォルト: `ci.on-failure=notify` / `review.reviewers=["copilot"]` / `review.on-unresolved=notify` / `poll-interval=60`。

## 手順

### 1. 設定読み込み

```bash
# workflow-automation-plugin の設定ファイルがあれば読む。無ければデフォルトを使う
# Glob: **/workflow-automation-plugin/.plugin-workspace/pull-request/.pr-review-fix.yml
CONFIG=$(find "$(dirname "${CLAUDE_PLUGIN_ROOT}")" -path "*/workflow-automation-plugin/.plugin-workspace/pull-request/.pr-review-fix.yml" 2>/dev/null | head -1)
```

設定値の取得は `yq` に依存せず、`grep` と `awk` で十分（キー構造が固定のため）。読み取れない場合はデフォルトにフォールバックする。

`pr-watch` セクションが無い場合は `review-watch` セクションを読み取り、上記の後方互換テーブルに従って読み替える。

### 2. Monitor ツールで監視起動

```
Monitor tool:
  command: ${CLAUDE_PLUGIN_ROOT}/skills/pr-watch/scripts/monitor-pr.sh <owner> <repo> <PR番号>
  env:
    WATCH_REVIEWERS=<reviewers をカンマ区切りに変換>
    WATCH_CI=true
    POLL_INTERVAL=<poll-interval>
    REVIEW_LOOP=<"true" if review.on-unresolved=auto, else "false">
    CI_LOOP=<"true" if ci.on-failure=auto, else "false">
```

スクリプトは stdout に以下のいずれかを1行ずつ出力する:

#### CI タグ

| タグ | 意味 |
|:-|:-|
| `CI_PENDING checks_in_progress=build,test` | CIチェック実行中 |
| `CI_PASSED` | 全チェック成功（チェック0件で猶予回数超過の場合も含む） |
| `CI_FAILED failed_checks=lint,test details=url1,url2` | 一部チェック失敗 |

#### レビュータグ

| タグ | 意味 |
|:-|:-|
| `REVIEW_PENDING reason=review-requested` | レビューリクエスト中（まだレビュー未開始） |
| `REVIEW_PENDING reason=no-review-yet` | 対象レビュアーのレビューが存在しない |
| `REVIEW_PENDING reason=review-in-progress` | レビュー作成中（state=PENDING） |
| `REVIEW_UNRESOLVED count=N locations=path1:line1,...` | 未解決スレッドあり |
| `REVIEW_DONE submitted=<iso8601> all_resolved=true` | 完了 |

1回のポーリングサイクルで最大2行（CIタグ1行 + レビュータグ1行）が出力される。

### 3. イベント処理ループ

Monitor の通知を1行ずつ処理する。**Monitor プロセスが終了するまで以下を繰り返す。途中で終了してはならない。**

監視スクリプトは状態変化時のみイベントを出力する（同一タグの連続出力は抑制される）。

#### ループ手順

1. Monitor の次の通知を待つ
2. 行頭タグを確認し、ディスパッチテーブルに従って処理する
3. **処理（Skill 呼び出しを含む）が完了したら、必ずステップ1に戻る**

#### ディスパッチテーブル

| タグ | auto モード | notify モード |
|:-|:-|:-|
| `CI_PENDING` | 記録のみ → ステップ1 | 同左 |
| `CI_PASSED` | CI完了（成功）を記録 → ステップ1 | 同左 |
| `CI_FAILED` | `Skill` ツールで `pr-ci-fix <PR番号> --from-watch` → **ステップ1に戻る** | CI失敗を記録 → ステップ1 |
| `REVIEW_PENDING` | 記録のみ → ステップ1 | 同左 |
| `REVIEW_DONE` | レビュー完了を記録 → ステップ1 | 同左 |
| `REVIEW_UNRESOLVED` | `Skill` ツールで `pr-fix-review <PR番号> --from-watch` → **ステップ1に戻る** | レビュー未解決を記録 → ステップ1 |

**重要**:
- **Skill 呼び出しが完了しても、Monitor プロセスはバックグラウンドで動作し続けている。Skill 完了はループ終了条件ではない。必ずステップ1に戻って次の通知を待つこと**
- `CI_FAILED` と `REVIEW_UNRESOLVED` が同一通知に含まれる場合は、CI を先に処理する（CI修正後にレビュー指摘が不要になることがあるため）
- `--from-watch` を付けることで、sub-skill が pr-watch を再起動しないようにする（監視は本ループが継続中のため）

#### ループ終了

Monitor プロセスが exit したらループを抜け、完了報告に移る。スクリプトは CI とレビューの両方が最終状態に達すると exit する。

#### 完了報告

notify モードで失敗/未解決がある場合:

1. CI失敗 → 失敗したチェック名と詳細URLをユーザーへ報告
2. レビュー未解決 → `locations` の `path:line` と件数をユーザーへ報告

auto モード / 両方成功 → 成功を報告して終了

## 注意事項

### パイプのバッファリング

監視スクリプトを拡張してパイプを追加する場合、バッファリング解除を**必須**とする。これを怠ると Monitor tool へのイベント到達が数分遅延する:

- `grep --line-buffered`
- `jq --unbuffered`
- `sed -u` (GNU sed)

現状のスクリプトは単発の `gh api` / `gh pr checks` → `jq` → `printf` なのでバッファリング問題は発生しない。

### Copilot ハンドルの揺れ

Copilot のレビュー投稿者ログインは文脈により `Copilot` / `copilot-pull-request-reviewer` / その他の揺れが発生する。`reviewers` に `copilot`（部分一致）で指定しておけばすべてにマッチする。再レビュー依頼時の `gh pr edit --add-reviewer` で渡すハンドルは固定値 `copilot-pull-request-reviewer` を使う。

### CIチェックの登録遅延

PR作成直後はCIチェックがまだ登録されていない場合がある。スクリプトはチェック0件の場合 `CI_PENDING` を出力し、3回連続でチェック0件が続いた場合にCIが未設定と判断して `CI_PASSED` を出力する。

### 完了時の報告フォーマット

```
## PR監視結果

### CI
- 状態: PASSED / FAILED / (タイムアウト時) PENDING
- 失敗チェック: {check1, check2}
- 詳細URL: {url1, url2}
- 次のアクション: {pr-ci-fix 起動 / 報告のみ}

### レビュー
- 状態: DONE / UNRESOLVED / (タイムアウト時) PENDING
- 提出時刻: {submitted_at}
- 未解決件数: {n}
- 未解決箇所: {path:line, ...}
- 次のアクション: {pr-fix-review 起動 / 報告のみ}
```
