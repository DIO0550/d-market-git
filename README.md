# d-market-git

Git ワークフローを自動化する Claude Code プラグイン集です。コミット・PR 作成・コードレビュー・CI 修正・仕様書からの Issue 生成まで、開発フローの各段階を支援します。

## プラグイン一覧

### 1. git-workflow-plugin

Git 操作支援プラグイン。コミット・PR 作成・ブランチ保護を提供します。

| スキル | 説明 |
|---|---|
| `/commit` | 絵文字ベースのコミットメッセージ規約に従ったコミット作成 |
| `/pull-request` | テンプレート・システム図付きの PR 作成 |
| `/pr-review` | 多角的なコードレビュー（バグ・セキュリティ・パフォーマンス・設計） |
| `/commit-template` | コミットメッセージテンプレート（YAML）の生成 |
| `/pr-template` | PR テンプレート（YAML）の生成 |

**エージェント:**
- `git-commit-agent` - コミットルールに従った自動コミット
- `pr-creation-agent` - PR の自動作成

**フック:**
- `branch-protection` - 保護ブランチ（main, master, production 等）への直接編集を禁止
- `no-git-add-all` - `git add -A / --all / .` による一括ステージングを禁止

### 2. workflow-automation-plugin

PR の CI エラー修正・レビュー指摘修正を自動化するプラグインです。

| スキル | 説明 |
|---|---|
| `/pr-ci-fix` | CI エラー（ビルド・テスト・Lint）を 1 エラー = 1 コミットで修正 |
| `/pr-fix-review` | 未解決のレビューコメントを 1 指摘 = 1 コミットで修正 |
| `/pr-all-fix` | CI エラー + レビュー指摘を一括修正（CI 優先） |
| `/pr-review-fix-template` | レビュー修正時の設定ファイル生成 |
| `/similarity` | コードの類似度検出（リファクタリング候補の特定） |

### 3. issues-workflow-plugin

GitHub Issue ワークフロープラグインです。仕様書からの Issue 自動生成と、実装プランの Issue 直書きを提供します。

| スキル | 説明 |
|---|---|
| `/spec-to-issues` | 仕様書を Epic > Issue > Sub-issue の 3 階層に分解して Issue 作成 |
| `/plan-issue` | 実装プランを MD ファイルの代わりに Issue として直接書き起こす（意思決定・実装方針の記録） |
| `/plan-issue-report` | 実装完了後にプラン Issue へ振り返りコメント（想定と違った点・プランからの変更等）を投稿してクローズ |
| `/issue-template` | Issue テンプレート（YAML）の生成 |
| `/plan-template` | プラン Issue・振り返りコメントのカスタムテンプレート生成 |

**エージェント:**
- `spec-analyzer-agent` - 仕様書を解析し、Issue 分解計画を作成
- `issues-creator-agent` - 計画に基づき GitHub Issue を作成（親子リンク付き）

**ラベル体系:**
- タイプ: `type:epic`, `type:feature`, `type:migration`, `type:test`, `type:docs`, `type:chore`, `type:task`, `type:plan`
- 領域: `area:frontend`, `area:server`, `area:shared`
- 優先度: `priority:P1`, `priority:P2`, `priority:P3`
- サイズ: `size:S`, `size:M`, `size:L`

## コミットメッセージ規約

```
<emoji> [<tag>]: #<Issue番号> <subject>
```

主要なタイプ:

| 絵文字 | タグ | 用途 |
|---|---|---|
| ✨ | New Feature | 新機能 |
| 🐛 | Bug fix | バグ修正 |
| ♻️ | Refactoring | リファクタリング |
| 📝 | Documentation | ドキュメント |
| 🚀 | Performance | パフォーマンス改善 |
| 🧪 | Tests | テスト追加 |
| 👷 | CI | CI 設定 |
| 💄 | UI/UX | UI/スタイル変更 |

## セットアップ

### 前提条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) がインストール済みであること
- [GitHub CLI (`gh`)](https://cli.github.com/) が認証済みであること

### インストール

対象プロジェクトの `.claude/settings.json` にプラグインを追加してください。

```json
{
  "plugins": [
    {
      "type": "project",
      "source": "/path/to/d-market-git/plugins/git-workflow-plugin"
    },
    {
      "type": "project",
      "source": "/path/to/d-market-git/plugins/workflow-automation-plugin"
    },
    {
      "type": "project",
      "source": "/path/to/d-market-git/plugins/issues-workflow-plugin"
    }
  ]
}
```

### テンプレートの初期化（任意）

プロジェクトごとにテンプレートをカスタマイズできます。各テンプレートは `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/` 配下に生成されます。

```
/commit-template    # .plugin-workspace/commit/.commit-template.yml を生成
/pr-template        # .plugin-workspace/pull-request/.pr-template.yml を生成
/issue-template     # .plugin-workspace/issues/issue-template.yml を生成
/plan-template      # .plugin-workspace/issues/plan-issue-template.md, plan-report-template.md を生成
```

## ディレクトリ構成

```
d-market-git/
├── .claude-plugin/
│   └── marketplace.json          # プラグインレジストリ
├── plugins/
│   ├── git-workflow-plugin/      # Git 操作支援
│   │   ├── agents/               # コミット・PR 作成エージェント
│   │   ├── hooks/                # ブランチ保護・add 制限
│   │   └── skills/               # commit, pull-request, pr-review 等
│   ├── workflow-automation-plugin/ # ワークフロー自動化
│   │   └── skills/               # pr-ci-fix, pr-fix-review 等
│   └── issues-workflow-plugin/    # GitHub Issue ワークフロー
│       ├── agents/               # 解析・作成エージェント
│       ├── scripts/              # ラベル作成スクリプト
│       └── skills/               # spec-to-issues, plan-issue, issue-template
└── LICENSE                       # MIT
```

## ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照してください。
