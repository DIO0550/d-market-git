---
name: pr-watch
description: PRのCI完了とレビュー完了をMonitorツール経由でバックグラウンド監視し、失敗・未解決指摘があれば次のアクションにチェーンするスキル。PR作成直後やプッシュ後にCI通過とレビュー完了を待ち受ける場面で使う。「CI監視」「レビュー監視」「PR監視して」などのリクエスト時に使用。
allowed-tools: Bash(gh *), Bash(git *), Read, Monitor, Skill
argument-hint: [PR番号]
---

# PR監視（CI＋レビュー）

PRに対してCI完了とレビュー完了をバックグラウンドで待ち受け、完了したら次のアクションにつなぐスキル。

## ワークフロー

```
1. owner/repo/PR番号を解決
   ↓
2. .pr-review-fix/.pr-review-fix.yml の pr-watch 設定を読む
   （pr-watch が無ければ review-watch にフォールバック）
   ↓
3. Monitor ツールで監視スクリプトを起動
   （auto モードでは REVIEW_LOOP / CI_LOOP を有効化）
   ↓
4. ストリーミング行の行頭タグで分岐（CI_* / REVIEW_*）
   - auto: 即座にアクション → 監視継続（ループ）
   - notify: 記録して両方の終了条件を待つ
   ↓
5. 両方が最終的な成功状態に達したら終了
```

## 引数

- `<PR番号>` 必須。monitor 対象のPR

owner/repo は `gh repo view --json owner,name -q '.owner.login + "/" + .name'` で解決する。

## 設定ファイル

`.pr-review-fix/.pr-review-fix.yml` の `pr-watch` セクションを読み込む。

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
# 設定ファイルがあれば読む。無ければデフォルトを使う
CONFIG=.pr-review-fix/.pr-review-fix.yml
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

### 3. 行頭タグで分岐

CI とレビューの状態を独立して追跡する。監視スクリプトは状態変化時のみイベントを出力する（同一タグの連続出力は抑制される）。

#### 即時アクションモード（auto）

`REVIEW_LOOP=true`（`review.on-unresolved=auto`）の場合、監視スクリプトは `REVIEW_UNRESOLVED` でも終了しない。以下の流れで継続監視する:

1. `REVIEW_UNRESOLVED` を受信 → 即座に `Skill` ツールで `pr-fix-review <PR番号> --from-watch` を呼ぶ
2. pr-fix-review が修正をプッシュし、レビュー再依頼する
3. 監視スクリプトは次のポーリングで `REVIEW_PENDING`（レビュー再依頼中）と `CI_PENDING`（新CI実行中）を検知し、状態をリセットする
4. 再び `REVIEW_UNRESOLVED` または `REVIEW_DONE` が来るまでポーリング継続
5. `REVIEW_DONE` で全スレッド解決を確認 → レビュー側は終了

`CI_LOOP=true`（`ci.on-failure=auto`）の場合も同様:

1. `CI_FAILED` を受信 → 即座に `Skill` ツールで `pr-ci-fix <PR番号>` を呼ぶ
2. pr-ci-fix が修正をプッシュする
3. 監視スクリプトは `CI_PENDING` を検知し、状態をリセットする
4. 再び `CI_FAILED` または `CI_PASSED` が来るまでポーリング継続

**重要**: `--from-watch` 引数を付けることで、pr-fix-review が完了後に pr-watch を再起動しないようにする（監視は既に実行中のため）。

#### 通知モード（notify）

`on-unresolved=notify` / `on-failure=notify` の場合、監視スクリプトは従来どおり `REVIEW_UNRESOLVED` / `CI_FAILED` を終了条件として扱い、両方が終了条件に達したら監視を停止する。

**両方が終了条件に達したら**、以下のアクション優先順位に従う:

1. CI失敗 + `ci.on-failure=notify` → 失敗したチェック名と詳細URLをユーザーへ報告
2. レビュー未解決 + `review.on-unresolved=notify` → `locations` の `path:line` と件数をユーザーへ報告
3. 両方成功 → 成功を報告して終了

auto モードでは検知時に即座にアクションを起こすため、「両方が終了条件に達してからアクション」という流れにはならない。

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
