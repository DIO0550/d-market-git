---
name: pr-fix-review
description: PRのレビュー指摘修正スキル。未解決のレビューコメントを確認し、1つずつ順番に修正してコミットし、スレッドを解決済みにする。「レビュー指摘を直して」「レビュー対応して」などのリクエスト時に使用。
allowed-tools: Bash(gh *), Bash(git *), Read, Grep, Glob, Edit, Write, Skill
argument-hint: [PR番号]
---

# レビュー指摘修正

PRのレビュー指摘を1つずつ修正するスキル。

## ワークフロー

```
1. レビュー指摘の洗い出し（未解決スレッドのみ取得、スレッドIDを記録）
   ↓
2. 妥当性チェック（各指摘 + 該当ソースコードを読み、修正すべきか判断）
   ↓
3. 指摘ごとにTaskCreateでタスク作成（妥当性チェックで修正対象と判定されたもののみ）
   ↓
4. タスクをin_progressに更新 → 修正方針を説明 → コード修正 → コミット → 解決済み処理 → タスクをcompletedに更新
   ↓
5. 次のタスクへ（全完了まで繰り返し）
   ↓
6. 全修正完了後に git push
   ↓
7. 設定に応じてレビュー再依頼（auto / skip / ask）
   ↓
8. サマリー報告
   ↓
9. copilot-review-watch でレビュー監視を起動
```

### タスク管理ルール

- **妥当性チェック完了後、修正に着手する前に全タスクを作成する**（修正対象と判定された指摘のみ）
- タスクは細かく分ける（1指摘 = 1タスク）
- タスクの`subject`には具体的な修正対象を書く（例: `レビュー指摘対応 - UserService.tsのエラーハンドリング`）
- `activeForm`を必ず設定する（例: `UserService.tsのエラーハンドリングを修正中`）
- 修正開始時: `TaskUpdate`で`status: "in_progress"`に更新
- 修正＆コミット完了後: 解決済み処理を実行してから`TaskUpdate`で`status: "completed"`に更新
- 全タスク完了後にサマリーを報告

## 対象

- 未解決（unresolved）のレビューコメントのみ
- resolved済みはスキップ

## 修正ルール

### 必須
- **1指摘 = 1タスク = 1コミット**（まとめて修正しない）
- 修正前に指摘内容と方針を説明
- コミットメッセージに修正対象を明記
- **修正完了後は必ずTaskUpdateでタスクをcompletedにする**
- **修正＆コミット後は、該当スレッドを解決済みにする**（後述の「解決済み処理」参照）

## 設定ファイル

プロジェクトに `.pr-review-fix/.pr-review-fix.yml` が存在する場合、その設定を読み込んで動作を制御する。

### 設定項目

```yaml
resolve-reply:
  enabled: true          # 解決時にスレッドへ返信するか（デフォルト: false）
  template: "✅ {commit_hash} で修正しました"  # 省略時はAIが生成

re-request-review:
  mode: skip             # プッシュ後のレビュー再依頼: auto / skip / ask（デフォルト: skip）

review-watch:
  reviewers:
    - copilot            # 監視対象レビュアーのログイン名トークン（部分一致・大文字小文字無視）
  on-unresolved: notify  # auto: pr-fix-review へ自動チェーン / notify: 報告のみ（デフォルト: notify）
  poll-interval: 60      # ポーリング間隔（秒、デフォルト: 60）
```

- `resolve-reply.enabled`: `true` の場合、スレッド解決前に返信コメントを投稿する
- `resolve-reply.template`: 返信メッセージのテンプレート。`{commit_hash}` をショートコミットハッシュに置換する。**省略時はAIが指摘内容・修正内容に応じて適切な返信メッセージを生成する**
- `re-request-review.mode`: プッシュ後に PR の全レビュアーへ再レビュー依頼を出すかの挙動
  - `auto`: `gh pr view` で取得した全レビュアーへ自動で再依頼する
  - `skip`: 再依頼しない（従来動作）
  - `ask`:  プッシュ直後にレビュアー一覧を提示し、ユーザーに再依頼するか確認する
- `review-watch`: `copilot-review-watch` スキルが参照する設定（PR 作成後のレビュー完了待ち）
  - `reviewers`: 監視対象レビュアーのログイン名トークン（配列）。**部分一致・大文字小文字無視**。`copilot` の 1 語で `Copilot` / `copilot-pull-request-reviewer` の両方にマッチする
  - `on-unresolved`: 未解決スレッドを検知したときの挙動
    - `auto`: `pr-fix-review <PR番号>` を自動チェーン呼び出しする（本スキルを `copilot-review-watch` から起動されるエントリポイントとして利用する）
    - `notify`: 指摘件数と `path:line` を報告して監視を終了する（デフォルト）
  - `poll-interval`: 監視スクリプトのポーリング間隔（秒）。デフォルト 60
- 設定ファイルが存在しない、または各キーが無い場合はそれぞれ「返信なし」「再依頼なし」「監視対象 copilot / on-unresolved=notify / poll-interval=60」（従来の動作）とみなす

## 妥当性チェック（指摘の検証）

レビュー指摘の洗い出し後、タスク作成の前に各コメントの妥当性を検証する。指摘内容と該当ソースコードを照合し、修正が不要と判断したものはスキップする。

### 評価手順

指摘ごとに以下を実行する。同一ファイルに複数の指摘がある場合は、ファイルを 1 回だけ Read してまとめて評価する。

1. コメント `body` を読み、要求内容を理解する
2. `path:line` のソースコードを `Read` ツールで読む（前後 20 行程度のコンテキスト）
3. 以下の基準でスキップ対象か判断する

### スキップ基準

以下のいずれかに該当する指摘はスキップする:

- **誤検知**: 指摘が指すコードに実際には問題がない
- **修正済み**: 既に別のコミットで対応済み
- **根拠のないスタイル指摘**: プロジェクト規約（CLAUDE.md、lintrc、editorconfig等）に裏付けがない命名・フォーマットの好み
- **コード意図の誤解**: レビュアーがコードの目的や文脈を誤って理解している
- **矛盾**: 同一ファイル・関数に対して相反する指摘が存在する場合、両方をスキップする

上記に該当しない指摘は修正対象とする。

### チェック結果の報告

妥当性チェック後、スキップ対象がある場合は修正着手前に報告する:

```
## 妥当性チェック結果

以下の指摘はスキップします:
- {ファイル}:{行} ({投稿者}) {指摘内容の要約} → 理由: {スキップ理由}

修正対象: N件
スキップ: N件
```

## 解決済み処理

レビュー指摘を修正＆コミットした後、該当のレビュースレッドを解決済み（resolved）にする。

### 手順

1. **指摘の洗い出し時にスレッドIDを記録する**
   - `gh api graphql` でPRのレビュースレッド一覧を取得し、未解決スレッドのIDとコメント内容を紐づけて記録する
   ```bash
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $pr: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $pr) {
           reviewThreads(first: 100) {
             nodes {
               id
               isResolved
               comments(first: 1) {
                 nodes {
                   body
                   path
                   line
                 }
               }
             }
           }
         }
       }
     }' -f owner='{owner}' -f repo='{repo}' -F pr={pr_number}
   ```

2. **修正＆コミット後、設定に応じてスレッドに返信する**
   - `.pr-review-fix/.pr-review-fix.yml` を読み込み、`resolve-reply.enabled` が `true` の場合のみ返信する
   - `resolve-reply.template` がある場合: テンプレートの `{commit_hash}` をコミットのショートハッシュに置換して返信
   - `resolve-reply.template` がない場合: 指摘内容と修正内容を踏まえて、AIが簡潔な返信メッセージを生成して返信（コミットハッシュは必ず含める）
   ```bash
   gh api graphql -f query='
     mutation($threadId: ID!, $body: String!) {
       addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
         comment {
           id
         }
       }
     }' -f threadId='{thread_id}' -f body='{reply_message}'
   ```

3. **スレッドを解決済みにする**
   ```bash
   gh api graphql -f query='
     mutation($threadId: ID!) {
       resolveReviewThread(input: {threadId: $threadId}) {
         thread {
           isResolved
         }
       }
     }' -f threadId='{thread_id}'
   ```

## プッシュとレビュー再依頼

全タスクが completed になった後、修正コミットをリモートへプッシュし、設定に応じて PR のレビュアーへ再レビュー依頼を出す。

### 手順

1. **プッシュ**
   ```bash
   git push
   ```

2. **設定値の読み込み**
   - `.pr-review-fix/.pr-review-fix.yml` の `re-request-review.mode` を読む
   - ファイルまたはキーが存在しない場合は `skip` として扱う

3. **`skip` の場合**
   - 何もしない。サマリー報告へ進む

4. **`auto` / `ask` の場合、レビュアーを取得する**
   ```bash
   gh pr view <PR番号> --json reviews --jq '[.reviews[].author.login] | unique | map(select(. != null))'
   ```
   - 取得結果が 0 人の場合は再依頼をスキップしてサマリー報告へ進む
   - **Copilot が過去にレビューしている場合の注意**: `.reviews[].author.login` では Copilot のハンドルが取得できない／別名になることがある。Copilot によるレビューの有無は以下で判定する:
     ```bash
     gh pr view <PR番号> --json reviews --jq '[.reviews[] | select(.author.login == "Copilot" or (.author.login // "") | test("copilot"; "i"))] | length'
     ```
     1 以上なら再依頼対象に `copilot-pull-request-reviewer` を追加する（`gh pr edit --add-reviewer` に渡すハンドルはこの固定値）

5. **`ask` の場合、ユーザーに確認する**
   - 取得したレビュアー一覧を提示し、「このレビュアーに再レビュー依頼を出しますか？」と質問する
   - 「いいえ」ならスキップする

6. **再依頼の実行**
   ```bash
   gh pr edit <PR番号> --add-reviewer <user1>,<user2>,...
   ```
   - `gh pr edit --add-reviewer` は既にレビュー済みのユーザーにも再レビューリクエストを送信できる
   - Copilot へ再依頼する場合は `copilot-pull-request-reviewer` を指定する:
     ```bash
     gh pr edit <PR番号> --add-reviewer copilot-pull-request-reviewer
     ```

## プッシュ後のレビュー監視

全修正のプッシュとレビュー再依頼が完了した後、`copilot-review-watch` スキルを起動してCopilot等のレビュー完了をバックグラウンド監視する。

### 起動条件

- `.pr-review-fix/.pr-review-fix.yml` の `review-watch.enabled` を参照する
- `false` に明示されている場合は監視しない
- `true` または未指定の場合は監視を起動する（デフォルト: `true`）

### 起動手順

1. `.pr-review-fix/.pr-review-fix.yml` の `review-watch.reviewers` を読む（無ければ `["copilot"]` をデフォルト）
2. `Skill` ツールで `copilot-review-watch <PR番号>` を呼び出し、以降は `copilot-review-watch` の仕様に従う

## コマンド実行規約

- **1回のBash呼び出し = 1コマンド**（`&&`, `||`, `;` による複合化禁止）
- コミットメッセージは **heredoc** で渡す（ファイル書き出し `-F` は使わない）:
  ```bash
  git commit -m "$(cat <<'EOF'
  ♻️ [Refactoring]: レビュー指摘対応 - エラーハンドリング改善
  EOF
  )"
  ```

## コミット形式

プロジェクトに `.commit-templates/.commit-template.yml` が存在する場合、そのテンプレートのルールを優先して使用する。テンプレートがない場合は以下のデフォルト形式に従う。

```
♻️ [Refactoring]: {指摘内容}
```

## 完了時の報告

```
## レビュー指摘修正サマリー

### 修正済み
- [x] {指摘1} → {対応内容} (resolved)
- [x] {指摘2} → {対応内容} (resolved)

### スキップ
- [ ] {指摘3} → スキップ理由: {理由}（{投稿者}）

- 再レビュー依頼: @user1, @user2  (または "スキップ")
```

スキップ対象がない場合は「スキップ」セクションを省略する。
