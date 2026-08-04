# d-market-git

Git ワークフローを自動化する Claude Code プラグイン集です。コミット・PR 作成・コードレビュー・CI 修正・仕様書からの Issue 生成まで、開発フローの各段階を支援します。

## プラグイン一覧

### 1. git-workflow-plugin

Git 操作支援プラグイン。コミット・PR 作成・ブランチ保護を提供します。

| スキル | 説明 |
|---|---|
| `/commit` | 絵文字ベースのコミットメッセージ規約に従ったコミット作成 |
| `/pull-request` | テンプレート・システム図付きの PR 作成（stacked PR 対応） |
| `/pr-review` | 多角的なコードレビュー（バグ・セキュリティ・パフォーマンス・設計） |
| `/commit-template` | コミットメッセージテンプレート（YAML）の生成 |
| `/pr-template` | PR テンプレート（YAML）の生成 |

**エージェント:**
- `git-commit-agent` - コミットルールに従った自動コミット
- `pr-creation-agent` - PR の自動作成

**フック:**
- `branch-protection` - 保護ブランチ（main, master, production 等）への直接編集を禁止
- `no-git-add-all` - `git add -A / --all / .` による一括ステージングを禁止
- `no-commit-md-heading` - コミット本文の行頭 `#` 見出しを禁止（git のコメント除去による本文の欠落を防ぐ）

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

<意思決定の記録（本文）>
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

### 変更内容と意思決定はコミット本文に残す

実装プランや設計メモを別ファイル（`docs/plans/` 等）に残すと、完了後は検索ノイズになり、仕様変更のたびに更新するか否かが曖昧になって陳腐化します。このプラグインでは、変更内容の要約と意思決定を、変更差分と不可分なコミット本文に書きます。

```
♻️ [Refactoring]: #45 認証トークンの検証をAuthTokenVerifierに集約

変更内容:
- 3箇所に複製されていたトークン検証をAuthTokenVerifierに集約
- 検証失敗を真偽値ではなく例外型で返すよう変更

背景:
トークン検証がミドルウェア・APIハンドラ・バッチの3箇所に複製されていた。

採用理由:
共通関数ではなくクラスに集約した。検証には公開鍵のキャッシュという状態が
伴い、関数のままでは呼び出し側でキャッシュを持ち回る必要があったため。

トレードオフ:
検証の失敗理由が例外型で返るようになり、呼び出し側が型で分岐できる。
真偽値を返す既存APIは残していない。
```

`git log --grep="採用理由" -p` のように、判断理由と差分を並べて追えます。

書く量は `decision_record.mode` で切り替えられます。

| mode | 本文に含めるセクション |
|---|---|
| `off` | 本文なし（subject のみ） |
| `minimal` | 変更内容 / 採用理由 |
| `standard` | 変更内容 / 背景 / 採用理由 / トレードオフ（デフォルト） |
| `detailed` | + 代替案 / 参考 |

設定は `/commit-template` で生成する `.commit-template.yml`（PR は `/pr-template` の `.pr-template.yml`）に置かれます。PR 本文にも同じ mode 体系で「意思決定と経緯」セクションが出力されます。

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

プロジェクトごとにテンプレートをカスタマイズできます。

```
/commit-template    # .claude/.commit-template.yml を生成
/pr-template        # .claude/.pr-template.yml を生成
/issue-template     # .plugin-workspace/issues/issue-template.yml を生成
/plan-template      # .plugin-workspace/issues/plan-issue-template.md, plan-report-template.md を生成
```

`/commit-template` と `/pr-template` はプロジェクト直下の `.claude/` に生成します（`decision_record.mode` のような運用方針はプロジェクトごとに変わるため）。スキルは **プロジェクト直下 → `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/` → 既定値** の順で探すので、複数プロジェクトで共有したい設定は後者に置けます。issues 系のテンプレートは `.plugin-workspace/` のみを参照します。

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
