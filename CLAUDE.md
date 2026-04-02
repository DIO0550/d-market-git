# CLAUDE.md

## プロジェクト概要

d-market-git は Claude Code プラグインのマーケットプレイスリポジトリ。Git ワークフロー全般（コミット・PR・レビュー・CI 修正・仕様書→Issue 変換）を自動化する 3 つのプラグインを提供する。

## リポジトリ構成

- `plugins/git-workflow-plugin/` - Git 操作支援（コミット・PR 作成・レビュー・ブランチ保護）
- `plugins/workflow-automation-plugin/` - ワークフロー自動化（CI エラー修正・レビュー指摘修正・類似コード検出）
- `plugins/spec-to-issues-plugin/` - 仕様書から GitHub Issue 自動生成（Epic→Issue→Sub-issue の 3 階層）
- `.claude-plugin/marketplace.json` - プラグインレジストリ

各プラグインは `plugin.json` を持ち、skills・agents・hooks で構成される。

## コミットメッセージ規約

```
<emoji> [<tag>]: #<Issue番号> <subject>
```

- 1 コミット = 1 変更（粒度を細かく保つ）
- `git add -A` / `git add --all` / `git add .` は禁止（フックで強制）
- 主要タグ: `✨ New Feature`, `🐛 Bug fix`, `♻️ Refactoring`, `📝 Documentation`, `🚀 Performance`, `🧪 Tests`, `👷 CI`, `🚚 Move`, `🔥 Remove`

## 開発時の注意事項

- スキル定義は `SKILL.md`（Markdown）で記述する
- エージェント定義は `agents/*.md` に配置する
- フックは `hooks/hooks.json` で定義し、シェルスクリプトで実装する
- テンプレートのデフォルト値は `references/` ディレクトリに配置する
- プラグインの説明文やスキルの内容は日本語で記述する
- 外部依存は GitHub CLI (`gh`) のみ。パッケージマネージャは使用しない

## ブランチ保護

main, master, production, release, develop, staging ブランチへの直接編集は `branch-protection` フックにより禁止されている。

## テンプレートファイルの配置規則

プロジェクト利用時にユーザーが生成するテンプレート:
- `.commit-templates/.commit-template.yml`
- `.pr-templates/.pr-template.yml`
- `.spec-to-issues/issue-template.yml`
- `.spec-to-issues/config.yml`
- `.pr-review-fix/.pr-review-fix.yml`
