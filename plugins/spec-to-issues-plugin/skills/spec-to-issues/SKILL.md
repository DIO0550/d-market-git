---
name: spec-to-issues
description: 仕様書・設計書からGitHub Issueを自動生成するスキル。仕様書を解析してEpicと子Issue（Feature、Migration、Test、Docs、Chore）に分解し、GitHub Issuesとして起票する。「仕様書からIssue作成」「仕様書からIssue作って」「設計書をIssueに変換して」「specからIssue生成」などのリクエスト時に使用。
---

# Spec to Issues

仕様書・設計書のMDファイルからGitHub Issueを自動生成するスキル。

## ワークフロー

```
1. MDファイルの読み込みと解析
   ↓
2. ユーザー設定の確認（.spec-to-issues.yml）
   ↓
3. Issue分解計画の作成 → ユーザー承認
   ↓
4. TaskCreateで全タスク事前作成
   ↓
5. Epic Issue作成
   ↓
6. 子Issue作成（1件ずつ、TaskUpdateで進捗管理）
   ↓
7. 親子リンク設定（GraphQL API）
   ↓
8. Epic本文を子Issue番号で更新
   ↓
9. 完了サマリー報告
```

## 前提・準備

### ラベル作成

リポジトリにラベルがない場合、`scripts/create-github-labels.sh`で一括作成:

```bash
# カレントリポジトリに作成
bash plugins/spec-to-issues-plugin/scripts/create-github-labels.sh

# ドライラン（実行内容のみ表示）
DRY_RUN=1 bash plugins/spec-to-issues-plugin/scripts/create-github-labels.sh

# 既存ラベルも上書き更新
FORCE_UPDATE=1 bash plugins/spec-to-issues-plugin/scripts/create-github-labels.sh
```

### ラベル一覧

| カテゴリ | ラベル | 説明 |
|:--|:--|:--|
| 種別 | `type:epic` | エピック/親Issue |
| 種別 | `type:feature` | 新機能/機能追加 |
| 種別 | `type:migration` | マイグレーション/移行 |
| 種別 | `type:chore` | 雑務/設定 |
| 種別 | `type:test` | テスト関連 |
| 種別 | `type:docs` | ドキュメント関連 |
| 領域 | `area:frontend` | フロントエンド |
| 領域 | `area:server` | バックエンド/サーバ |
| 領域 | `area:shared` | 共有/横断 |
| 優先度 | `priority:P1` | 最優先（ブロッカー） |
| 優先度 | `priority:P2` | 高優先度 |
| 優先度 | `priority:P3` | 通常優先度 |
| 規模 | `size:S` | 小（1日以内） |
| 規模 | `size:M` | 中（1-3日） |
| 規模 | `size:L` | 大（3日以上） |

## Step 1: MDファイルの読み込みと解析

1. ユーザーが指定したMDファイルのパスを確認
2. ファイルを読み込み、ドキュメント構造を解析
3. 以下を特定する:
   - ドキュメントタイトル（H1）
   - 主要セクション（H2）
   - サブセクション（H3以下）
   - 機能要件、非機能要件、技術詳細、依存関係

### MD解析ガイドライン

**見出しレベルとIssueの対応:**

| 見出しレベル | Issue構造への対応 |
|:--|:--|
| H1 | Epicのタイトルソース |
| H2 | 子Issue候補（主要な機能・作業単位） |
| H3以下 | 子Issueの本文に含める（独立Issueにしない） |

**Issueタイプの判定ルール:**

| MDの内容 | Issueタイプ |
|:--|:--|
| 新機能、コンポーネント設計、画面実装 | `Feature` |
| DB変更、スキーマ移行、API移行、リファクタリング | `Migration` |
| テスト戦略、テストケース、品質基準 | `Test` |
| ドキュメント作成、README更新、API仕様書 | `Docs` |
| CI/CD、ツール設定、依存更新、リント設定 | `Chore` |

**エリア判定キーワード:**

| エリア | キーワード例 |
|:--|:--|
| `area:frontend` | UI, component, page, screen, CSS, React, Vue, Next.js |
| `area:server` | API, endpoint, database, server, handler, middleware |
| `area:shared` | shared, common, utils, types, interface, schema |

**優先度の判定:**

| 優先度 | 判定基準 |
|:--|:--|
| `priority:P1` | コア機能、他タスクのブロッカー、基盤となる実装 |
| `priority:P2` | 重要だがブロッカーではない機能 |
| `priority:P3` | あると良い機能、最適化、改善 |

**規模の見積もり:**

| 規模 | 判定基準 |
|:--|:--|
| `size:S` | 単純な変更、1ファイル、設定変更（1日以内） |
| `size:M` | 複数ファイル、中程度のロジック（1-3日） |
| `size:L` | 複雑なロジック、複数コンポーネント（3日以上） |

**分解の粒度ルール:**
- 1 Issueは1-3日で完了可能な単位にする
- 3日以上かかりそうなセクションは複数Issueに分割する
- 各Issueは独立して実装・テスト可能であること

## Step 2: ユーザー設定の確認

プロジェクトルートに `.spec-to-issues.yml` が存在するか確認する。

- **設定ファイルがある場合**: 読み込んでカスタムルールを適用
- **設定ファイルがない場合**: ビルトインのデフォルト設定を使用

設定スキーマの詳細は `references/config-schema.md` を参照。

### カスタマイズ可能な項目

- タイトルフォーマット
- デフォルトラベル
- カスタムラベル（自動付与）
- エリア判定キーワード
- テンプレート上書き
- Issue分解の制約（最大作業日数、最大Issue数）
- Assignee、Milestone、Project

## Step 3: Issue分解計画の作成と承認

MDファイルの解析結果をもとに、Issue分解計画を作成してユーザーに提示する。

**提示フォーマット:**

```
## Issue作成計画

### 元仕様書
- ファイル: `{md_file_path}`

### Epic
- [Epic] {タイトル}: 実装計画と進行管理

### 子Issue（計 {n}件）
1. [Feature][{area}] {Component}: {要約} (size:{S/M/L}, priority:{P1/P2/P3})
2. [Migration] {要約} (size:{S/M/L}, priority:{P1/P2/P3})
3. [Test] {要約} (size:{S/M/L}, priority:{P1/P2/P3})
4. [Docs] {要約} (size:{S/M/L}, priority:{P1/P2/P3})

この計画でIssueを作成してもよろしいですか？
```

**ユーザーが計画を修正可能:**
- Issueの追加/削除/名前変更
- 優先度/規模の変更
- Issueタイプの変更

**承認を得てから次のステップに進む。**

## Step 4: タスク管理

### タスク管理ルール

- **Issue分解計画の承認後、作成に着手する前に全タスクをTaskCreateで作成する**
- タスクは1 Issue = 1タスクで管理（Epic作成 + 各子Issue作成 + リンク設定）
- タスクの`subject`には具体的なIssue内容を書く
- `activeForm`を必ず設定する
- 作成開始時: `TaskUpdate`で`status: "in_progress"`に更新
- 作成完了後: `TaskUpdate`で`status: "completed"`に更新
- 全タスク完了後にサマリーを報告

**タスク作成例:**

```
TaskCreate:
  subject: "Epic Issue作成 - [Epic] ユーザープロフィール機能"
  activeForm: "Epic Issueを作成中"

TaskCreate:
  subject: "Issue作成 - [Feature][frontend] ProfilePage: プロフィール画面の実装"
  activeForm: "[Feature] ProfilePage Issueを作成中"

TaskCreate:
  subject: "親子リンク設定"
  activeForm: "親子リンクを設定中"
```

## Step 5: Epic Issue作成

テンプレート: `references/templates/epic.template.md`

**デフォルトタイトル形式**: `[Epic] {ドキュメントタイトル}: 実装計画と進行管理`

```bash
EPIC_URL=$(gh issue create \
  --title "[Epic] {タイトル}: 実装計画と進行管理" \
  --body "$(cat <<'EOF'
## 概要
{仕様書の概要}

## 対象仕様書
- ファイル: `{md_file_path}`

## 子Issue一覧
（作成後に更新）

## 受け入れ条件（DoD）
- [ ] 全子Issueの完了
- [ ] 結合テスト完了
- [ ] ドキュメント更新完了
EOF
)" \
  --label "type:epic")

EPIC_NUM=$(echo "$EPIC_URL" | grep -oE '[0-9]+$')
echo "Created Epic: #${EPIC_NUM}"
```

## Step 6: 子Issue作成

各子Issueを1件ずつ作成する。

### Issue種類とテンプレート

| 種類 | テンプレート | デフォルトタイトル形式 | ラベル |
|:--|:--|:--|:--|
| Feature | `references/templates/feature.template.md` | `[Feature][{area}] {Component}: {要約}` | `type:feature` |
| Migration | `references/templates/migration.template.md` | `[Migration] {要約}` | `type:migration` |
| Test | `references/templates/test.template.md` | `[Test] {要約}` | `type:test` |
| Docs | `references/templates/docs.template.md` | `[Docs] {要約}` | `type:docs` |
| Chore | `references/templates/chore.template.md` | `[Chore] {要約}` | `type:chore` |

### 作成コマンド

```bash
CHILD_URL=$(gh issue create \
  --title "{タイトル}" \
  --body "$(cat <<'EOF'
{テンプレートに基づいた本文}
EOF
)" \
  --label "{type_label}" \
  --label "{area_label}" \
  --label "{priority_label}" \
  --label "{size_label}")

CHILD_NUM=$(echo "$CHILD_URL" | grep -oE '[0-9]+$')
echo "Created: #${CHILD_NUM}"
```

### 子Issue本文の必須項目

- **概要**: 仕様書の該当セクションの要約
- **背景**: 元仕様書ファイルパス + 親Epic番号
- **タスク**: チェックリスト形式の作業項目
- **受け入れ条件**: 完了判定基準
- **参考**: 仕様書の関連セクション抜粋（必要に応じて）

## Step 7: 親子リンク設定

GitHub GraphQL APIで`addSubIssue` mutationを使用して親子関係を設定する。

### Node ID取得

```bash
# リポジトリ情報
REPO_OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO_NAME=$(gh repo view --json name --jq '.name')

# Issue番号からNode IDを取得
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) {
        id
        title
      }
    }
  }
' -f owner="$REPO_OWNER" -f repo="$REPO_NAME" -F number={issue_number}
```

### Sub-issue紐付け

```bash
gh api graphql -f query='
  mutation($parentId: ID!, $childId: ID!) {
    addSubIssue(input: {issueId: $parentId, subIssueId: $childId}) {
      issue { id title }
      subIssue { id title }
    }
  }
' -f parentId="{epic_node_id}" -f childId="{child_node_id}"
```

## Step 8: Epic本文更新

全子Issue作成後、Epic本文の「子Issue一覧」セクションを実際のIssue番号で更新する。

```bash
gh issue edit {epic_number} --body "{更新された本文}"
```

子Issue一覧のフォーマット:

```markdown
## 子Issue一覧
- [ ] #{child_1} [Feature][frontend] ProfilePage: プロフィール画面の実装
- [ ] #{child_2} [Feature][server] ProfileAPI: プロフィールAPIエンドポイント
- [ ] #{child_3} [Test] プロフィール機能のテスト
- [ ] #{child_4} [Docs] プロフィールAPI仕様書
```

## Step 9: 完了サマリー報告

全タスク完了後、以下のサマリーを報告する:

```
## Issue作成サマリー

### Epic
- #{epic_number} [Epic] {タイトル}: 実装計画と進行管理

### 子Issue（{n}件）
- [x] #{issue_1} [Feature][frontend] {要約}
- [x] #{issue_2} [Feature][server] {要約}
- [x] #{issue_3} [Test] {要約}
- [x] #{issue_4} [Docs] {要約}

### リンク状態
- 全 {n} 件の子IssueがEpicにリンク済み

### ラベル
- 種別/領域/優先度/規模ラベルが設定済み
```

## エラーハンドリング

| 状況 | 対応 |
|:--|:--|
| MDファイルが見つからない | エラー報告、正しいパスを確認 |
| MDファイルが空 | エラー報告、処理中止 |
| H1見出しがない | ファイル名をEpicタイトルとして使用 |
| H2セクションがない | 警告を出し、Epic単体の作成を提案 |
| `.spec-to-issues.yml`が不正 | YAML解析エラーを報告、デフォルトにフォールバック |
| `gh` CLIが未認証 | `gh auth login` の実行を案内 |
| ラベルが未作成 | `create-github-labels.sh` の実行を案内 |
| Issue作成APIエラー | エラー報告、1回リトライ、それでも失敗ならユーザーに確認 |
| GraphQL `addSubIssue`失敗 | 報告するが続行（Issue自体は存在するので手動リンクを案内） |
| Issue数が20件超 | 作成前にユーザーに確認 |

## 禁止事項

- ユーザーの承認なしにIssueを作成しない
- 元のMDファイルを変更しない
- 重複Issueを作成しない（既存Issueを事前確認）
- `gh issue create` 以外の方法でIssueを作成しない
