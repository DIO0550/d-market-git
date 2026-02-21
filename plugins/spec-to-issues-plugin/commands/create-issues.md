# Create Issues from Spec

## Description

仕様書・設計書のMDファイルからGitHub Issueを自動生成します。Epic → Issue → Sub-issue の3階層構成。

## Prompt Template

`spec-to-issues`スキル（`plugins/spec-to-issues-plugin/skills/spec-to-issues/SKILL.md`）を使用して、指定されたMDファイルからGitHub Issueを作成してください。

以下のタスクを実行してください：

1. **MDファイルの読み込み**

   - ユーザーが指定したMDファイルのパスを確認
   - ファイルを読み込み、内容を解析

2. **ユーザー設定の確認**

   - プロジェクトルートに `.spec-to-issues.yml` が存在するか確認
   - 存在する場合は設定を読み込み、存在しない場合はデフォルト設定を使用
   - 設定スキーマは `plugins/spec-to-issues-plugin/skills/spec-to-issues/references/config-schema.md` を参照

3. **Issue分解計画の作成と確認**

   - MDファイルの内容を分析し、3階層（Epic + Issue + Sub-issue）の分解計画を作成
   - Issue間の依存関係（Blocked by）を明示
   - ユーザーに計画を提示し、承認を得る

4. **Issue作成**

   - Epic Issueを作成
   - Issueを依存関係順に1つずつ作成（TaskCreateで進捗管理）
   - Epic ← Issue の親子リンクをGraphQL APIで設定
   - 各IssueにSub-issueを作成
   - Issue ← Sub-issue の親子リンクをGraphQL APIで設定

5. **完了報告**

   - 作成したIssue・Sub-issueのサマリーを報告
   - 依存関係とリンク状態を確認

## Notes

- MDファイルのパスは絶対パスまたは相対パスで指定可能
- Issue作成前に必ずユーザーの承認を得る
- 各Issueの作成はTaskCreateで進捗を管理する
- ラベルが未作成の場合は `scripts/create-github-labels.sh` の実行を案内する
- テンプレートは `plugins/spec-to-issues-plugin/skills/spec-to-issues/references/templates/` を参照
