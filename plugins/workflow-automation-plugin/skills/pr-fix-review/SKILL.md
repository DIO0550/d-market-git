---
name: pr-fix-review
description: PRのレビュー指摘修正スキル。未解決のレビューコメントを確認し、1つずつ順番に修正してコミットし、スレッドを解決済みにする。「レビュー指摘を直して」「レビュー対応して」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Bash(gh *), Bash(git *), Read, Grep, Glob, Edit, Write
argument-hint: [PR番号]
---

# レビュー指摘修正

PRのレビュー指摘を1つずつ修正するスキル。

## ワークフロー

```
1. レビュー指摘の洗い出し（未解決スレッドのみ取得、スレッドIDを記録）
   ↓
2. 指摘ごとにTaskCreateでタスク作成（細分化して1タスク=1修正単位）
   ↓
3. タスクをin_progressに更新 → 修正方針を説明 → コード修正 → コミット → 解決済み処理 → タスクをcompletedに更新
   ↓
4. 次のタスクへ（全完了まで繰り返し）
   ↓
5. 全修正完了後に git push
   ↓
6. 設定に応じてレビュー再依頼（auto / skip / ask）
   ↓
7. サマリー報告
```

### タスク管理ルール

- **指摘の洗い出し後、修正に着手する前に全タスクを作成する**
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
```

- `resolve-reply.enabled`: `true` の場合、スレッド解決前に返信コメントを投稿する
- `resolve-reply.template`: 返信メッセージのテンプレート。`{commit_hash}` をショートコミットハッシュに置換する。**省略時はAIが指摘内容・修正内容に応じて適切な返信メッセージを生成する**
- `re-request-review.mode`: プッシュ後に PR の全レビュアーへ再レビュー依頼を出すかの挙動
  - `auto`: `gh pr view` で取得した全レビュアーへ自動で再依頼する
  - `skip`: 再依頼しない（従来動作）
  - `ask`:  プッシュ直後にレビュアー一覧を提示し、ユーザーに再依頼するか確認する
- 設定ファイルが存在しない、または各キーが無い場合はそれぞれ「返信なし」「再依頼なし」（従来の動作）とみなす

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

5. **`ask` の場合、ユーザーに確認する**
   - 取得したレビュアー一覧を提示し、「このレビュアーに再レビュー依頼を出しますか？」と質問する
   - 「いいえ」ならスキップする

6. **再依頼の実行**
   ```bash
   gh pr edit <PR番号> --add-reviewer <user1>,<user2>,...
   ```
   - `gh pr edit --add-reviewer` は既にレビュー済みのユーザーにも再レビューリクエストを送信できる

## コミット形式

プロジェクトに `.commit-templates/.commit-template.yml` が存在する場合、そのテンプレートのルールを優先して使用する。テンプレートがない場合は以下のデフォルト形式に従う。

```
♻️ [Refactoring]: {指摘内容}
```

## 完了時の報告

```
## レビュー指摘修正サマリー

- [x] {指摘1} → {対応内容} (resolved)
- [x] {指摘2} → {対応内容} (resolved)
- [x] {指摘3} → {対応内容} (resolved)

- 再レビュー依頼: @user1, @user2  (または "スキップ")
```
