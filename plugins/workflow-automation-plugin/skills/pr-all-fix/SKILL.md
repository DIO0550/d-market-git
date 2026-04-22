---
name: pr-all-fix
description: PRのCIエラーとレビュー指摘を一括修正するスキル。CIエラーを先に修正し、次にレビュー指摘を処理する。「PR全部直して」「CIもレビューも直して」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Bash(gh *), Bash(git *), Read, Grep, Glob, Edit, Write
argument-hint: [PR番号]
---

# PR問題修正

PRのレビュー指摘事項とCIエラーを1つずつ修正するスキル。

## ワークフロー

```
1. 問題の洗い出し（CI → レビュー指摘の順で優先度判断）
   ↓
2. レビュー指摘の妥当性チェック（各指摘 + 該当ソースコードを読み、修正すべきか判断。CIエラーはチェック対象外）
   ↓
3. 問題ごとにTaskCreateでタスク作成（CIエラーは全件、レビュー指摘は妥当性チェックで修正対象と判定されたもののみ）
   ↓
4. タスクをin_progressに更新 → 修正方針を説明 → コード修正 → コミット → 解決済み処理 → タスクをcompletedに更新
   ↓
5. 次のタスクへ（全完了まで繰り返し）
   ↓
6. サマリー報告
```

### タスク管理ルール

- **妥当性チェック完了後、修正に着手する前に全タスクを作成する**（CIエラーは全件、レビュー指摘は修正対象と判定されたもののみ）
- タスクは細かく分ける（例: 「テスト失敗3件」→ テストケースごとに3タスク）
- CIエラーとレビュー指摘はカテゴリを分けてタスク化
- タスクの`subject`には具体的な修正対象を書く（例: `CIエラー修正 - UserService.tsの型エラー`）
- `activeForm`を必ず設定する（例: `UserService.tsの型エラーを修正中`）
- 修正開始時: `TaskUpdate`で`status: "in_progress"`に更新
- 修正＆コミット完了後: レビュー指摘の場合は解決済み処理を実行してから`TaskUpdate`で`status: "completed"`に更新
- 全タスク完了後にサマリーを報告

## 対象

### CIエラー
- ビルドエラー
- テスト失敗
- Lint/型エラー

### レビュー指摘
- 未解決（unresolved）のコメントのみ対象
- resolved済みはスキップ

## 修正ルール

### 必須
- **1問題 = 1タスク = 1コミット**（まとめて修正しない）
- 修正前に問題内容と方針を説明
- コミットメッセージに修正対象を明記
- **修正完了後は必ずTaskUpdateでタスクをcompletedにする**
- **レビュー指摘の修正＆コミット後は、該当スレッドを解決済みにする**（後述の「解決済み処理」参照）

### 優先順位
1. CIエラー（先に直すとレビュー対応がスムーズになることが多い）
2. レビュー指摘事項

## 設定ファイル

プロジェクトに `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/pull-request/.pr-review-fix.yml` が存在する場合、その設定を読み込んで動作を制御する。

### 設定項目

```yaml
resolve-reply:
  enabled: true          # 解決時にスレッドへ返信するか（デフォルト: false）
  template: "✅ {commit_hash} で修正しました"  # 省略時はAIが生成
```

- `resolve-reply.enabled`: `true` の場合、スレッド解決前に返信コメントを投稿する
- `resolve-reply.template`: 返信メッセージのテンプレート。`{commit_hash}` をショートコミットハッシュに置換する。**省略時はAIが指摘内容・修正内容に応じて適切な返信メッセージを生成する**
- 設定ファイルが存在しない場合は返信なし（従来と同じ動作）

## 妥当性チェック（レビュー指摘の検証）

レビュー指摘の洗い出し後、タスク作成の前に各コメントの妥当性を検証する。**CIエラーはチェック対象外**（全件修正対象）。

妥当性チェックの評価手順・スキップ基準・結果報告は `pr-fix-review` スキルの「妥当性チェック（指摘の検証）」セクションと同一の仕様に従う。

## 解決済み処理

レビュー指摘を修正＆コミットした後、該当のレビュースレッドを解決済み（resolved）にする。

### 手順

1. **問題の洗い出し時にスレッドIDを記録する**
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
   - `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/pull-request/.pr-review-fix.yml` を読み込み、`resolve-reply.enabled` が `true` の場合のみ返信する
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

4. **CIエラーはスレッド解決・返信の対象外**（レビュー指摘のみ）

## コミット形式

git-workflow-plugin の `.plugin-workspace/commit/.commit-template.yml` が存在する場合、そのテンプレートのルールを優先して使用する（Glob: `**/git-workflow-plugin/.plugin-workspace/commit/.commit-template.yml`）。テンプレートがない場合は以下のデフォルト形式に従う。

```
🐛 [Bug fix]: CIエラー修正 - {エラー内容}
```

```
♻️ [Refactoring]: {指摘内容}
```

## 完了時の報告

```
## 修正サマリー

### CIエラー
- [x] {エラー1} → {対応内容}
- [x] {エラー2} → {対応内容}

### レビュー指摘（修正済み）
- [x] {指摘1} → {対応内容} (resolved)
- [x] {指摘2} → {対応内容} (resolved)

### レビュー指摘（スキップ）
- [ ] {指摘3} → スキップ理由: {理由}（{投稿者}）
```

スキップ対象がない場合は「スキップ」セクションを省略する。
