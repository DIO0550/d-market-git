# Create Issues from Spec

## Description

仕様書・設計書のMDファイルからGitHub Issueを自動生成します。2つのエージェントで分担:

1. **spec-analyzer-agent**: 仕様書を解析し `.issues-plan.md` に分解計画を書き出す
2. **issues-creator-agent**: 分解計画ファイルからGitHub Issueを作成する

## Prompt Template

### Step 1: 分解計画の作成

`spec-analyzer`スキル（`plugins/spec-to-issues-plugin/skills/spec-analyzer/SKILL.md`）を使用して、指定されたMDファイルからIssue分解計画を作成してください。

1. **MDファイルの読み込み**: ユーザー指定のMDファイルを読み込み解析
2. **ユーザー設定の確認**: `.spec-to-issues.yml` があれば適用
3. **分解計画の作成**: 3階層（Epic + Issue + Sub-issue）＋依存関係の計画を作成
4. **ファイル出力**: `.issues-plan.md` に書き出し

### Step 2: Issue作成

`issues-creator`スキル（`plugins/spec-to-issues-plugin/skills/issues-creator/SKILL.md`）を使用して、`.issues-plan.md` からGitHub Issueを作成してください。

1. **計画ファイルの読み込み**: `.issues-plan.md` をパース
2. **ユーザー確認**: 内容を提示し承認を得る
3. **Issue作成**: Epic → Issue → Sub-issue の順で作成、親子リンク設定
4. **完了報告**: サマリーを報告

## Notes

- Step 1とStep 2は別々に実行可能（間にユーザーが計画を手動編集できる）
- ラベルが未作成の場合は `scripts/create-github-labels.sh` の実行を案内する
- テンプレートは `plugins/spec-to-issues-plugin/skills/issues-creator/references/templates/` を参照
