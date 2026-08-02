# CLAUDE.md

## プロジェクト概要

d-market-git は Claude Code プラグインのマーケットプレイスリポジトリ。Git ワークフロー全般（コミット・PR・レビュー・CI 修正・仕様書→Issue 変換）を自動化する 3 つのプラグインを提供する。

## リポジトリ構成

- `plugins/git-workflow-plugin/` - Git 操作支援（コミット・PR 作成・レビュー・ブランチ保護）
- `plugins/workflow-automation-plugin/` - ワークフロー自動化（CI エラー修正・レビュー指摘修正・類似コード検出）
- `plugins/issues-workflow-plugin/` - 仕様書から GitHub Issue 自動生成（Epic→Issue→Sub-issue→Task の最大 4 階層。分解の深さは実行時に選択）。実装プランを MD ファイルの代わりに Issue として直接書く plan-issue も提供
- `.claude-plugin/marketplace.json` - プラグインレジストリ

各プラグインは `plugin.json` を持ち、skills・agents・hooks で構成される。

## コミットメッセージ規約

```
<emoji> [<tag>]: #<Issue番号> <subject>

<意思決定の記録（本文）>
```

- 1 コミット = 1 変更（粒度を細かく保つ）
- `git add -A` / `git add --all` / `git add .` は禁止（フックで強制）
- 主要タグ: `✨ New Feature`, `🐛 Bug fix`, `♻️ Refactoring`, `📝 Documentation`, `🚀 Performance`, `🧪 Tests`, `👷 CI`, `🚚 Move`, `🔥 Remove`

### 意思決定はコミット本文に残す

実装プランや設計メモを別ファイルに残すと、完了後に検索ノイズになり仕様変更で陳腐化する。意思決定（背景・なぜこの方法か・検討した代替案・影響とトレードオフ）はコミット本文に書く。

- 本文の詳細度は `.commit-template.yml` の `decision_record.mode` で制御（`off` / `minimal` / `standard` / `detailed`、デフォルト `standard`）
- 本文の見出しは `<見出し>:` を単独行に置く。行頭 `#` の Markdown 見出しは使わない（git がコメント行として除去しうる）
- 本文が長くなってもコミットを大きくしない（1 コミット = 1 変更は維持）
- PR 本文も同様に `.pr-template.yml` の `decision_record` で「意思決定と経緯」を制御する

## 開発時の注意事項

- スキル定義は `SKILL.md`（Markdown）で記述する
- エージェント定義は `agents/*.md` に配置する
- フックは `hooks/hooks.json` で定義し、シェルスクリプトで実装する
- テンプレートのデフォルト値は `references/` ディレクトリに配置する
- プラグインの説明文やスキルの内容は日本語で記述する
- 外部依存は GitHub CLI (`gh`) のみ。パッケージマネージャは使用しない

## バージョン管理

- 各プラグインのバージョンは `plugin.json` の `version` フィールドで管理する（セマンティックバージョニング）
- プラグインのスキル・エージェント・フックを変更した場合、該当プラグインのバージョンを更新する
  - バグ修正: パッチバージョン（例: 1.0.0 → 1.0.1）
  - 機能追加・スキル改善: マイナーバージョン（例: 1.0.0 → 1.1.0）
  - 破壊的変更: メジャーバージョン（例: 1.0.0 → 2.0.0）
- コミットメッセージに `🔧 [Config]: <プラグイン名> v<バージョン>` の形式でバージョンを明記する

## ブランチ保護

main, master, production, release, develop, staging ブランチへの直接編集は `branch-protection` フックにより禁止されている。

## テンプレートファイルの配置規則

プロジェクトごとに値が変わる設定（`decision_record.mode` など）はプロジェクト直下の `.claude/` に、複数プロジェクトで共有する設定は `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/` 配下に置く。スキルは **プロジェクト直下 → プラグイン配下 → スキルの既定値** の順に探す。

- git-workflow-plugin（探索順に対応済み）:
  - `.claude/.commit-template.yml` → `.plugin-workspace/commit/.commit-template.yml`
  - `.claude/.pr-template.yml` → `.plugin-workspace/pull-request/.pr-template.yml`

以下の2プラグインは未対応で、`${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/` のみを参照する:

- workflow-automation-plugin:
  - `.plugin-workspace/pull-request/.pr-review-fix.yml`
  - `.plugin-workspace/pull-request/review-fix-report-template.md`
- issues-workflow-plugin:
  - `.plugin-workspace/issues/issue-template.yml`
  - `.plugin-workspace/issues/config.yml`
  - `.plugin-workspace/issues/issues-plan.md`
  - `.plugin-workspace/issues/plan-issue-template.md`
  - `.plugin-workspace/issues/plan-report-template.md`
