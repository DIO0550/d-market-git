---
name: spec-to-issues
description: 仕様書・設計書からGitHub Issueを自動生成するスキル。仕様書を解析してEpic・Issue・Sub-issueの3階層に分解し、依存関係を明示してGitHub Issuesとして起票する。「仕様書からIssue作成」「仕様書からIssue作って」「設計書をIssueに変換して」「specからIssue生成」などのリクエスト時に使用。
---

# Spec to Issues

仕様書・設計書のMDファイルからGitHub Issueを自動生成するスキル。
Epic → Issue → Sub-issue の3階層構成で、Issue間の依存関係を明示する。

2つのエージェントで分担して実行する:
- **spec-analyzer-agent**: 仕様書を解析し `.issues-plan.md` に分解計画を書き出す
- **issues-creator-agent**: `.issues-plan.md` からGitHub Issueを作成する

---

## Part 1: 仕様書解析（spec-analyzer-agent が使用）

### ワークフロー

```
1. MDファイルの読み込みと解析
   ↓
2. ユーザー設定の確認（.spec-to-issues.yml）
   ↓
3. 3階層 + 依存関係の分解計画を作成
   ↓
4. .issues-plan.md に書き出し
```

### Step 1: MDファイルの読み込みと解析

1. ユーザーが指定したMDファイルのパスを確認
2. ファイルを読み込み、ドキュメント構造を解析
3. 以下を特定する:
   - ドキュメントタイトル（H1）
   - 主要セクション（H2）
   - サブセクション（H3以下）
   - 機能要件、技術詳細、依存関係

#### MD解析ガイドライン

**見出しレベルとIssue構造の対応:**

| 見出しレベル | Issue構造への対応 |
|:--|:--|
| H1 | Epicのタイトルソース |
| H2 | Issue候補（中粒度の作業単位） |
| H3 | Sub-issue候補（細粒度のタスク） |
| H4以下 | Sub-issueの本文に含める（独立Issueにしない） |

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
- Issue（中粒度）: 1-3日で完了可能な単位
- Sub-issue（細粒度）: 半日〜1日で完了可能な単位
- 1 Issueあたり Sub-issue 2-5件が目安
- 3日以上かかりそうなセクションは複数Issueに分割する

**依存関係の判定ルール:**

| 依存パターン | 判定基準 |
|:--|:--|
| データモデル → API → UI | 基盤となる実装を先に |
| スキーマ変更 → マイグレーション → アプリコード | DB変更は先行 |
| 共通コンポーネント → 個別画面 | 共通部品を先に |
| 機能実装 → テスト | テストは実装後 |
| 機能実装 → ドキュメント | Docsは実装後 |

- 依存関係はIssue間で設定する（Sub-issue間では不要）

### Step 2: ユーザー設定の確認

プロジェクトルートに `.spec-to-issues.yml` が存在するか確認する。

- **設定ファイルがある場合**: 読み込んでカスタムルールを適用
- **設定ファイルがない場合**: ビルトインのデフォルト設定を使用

設定スキーマの詳細は `references/config-schema.md` を参照。

### Step 3: `.issues-plan.md` への書き出し

分解計画をプロジェクトルートの `.issues-plan.md` に書き出す。

#### 出力フォーマット

```markdown
# Issue分解計画

## Epic

- title: {Epicタイトル}
- labels: type:epic

## Issues

### 1. {Issueタイトル}

- labels: {label1}, {label2}, ...
- blocked_by: []
- body: |
    ## 概要
    {概要テキスト}

    ## タスク
    - [ ] タスク1
    - [ ] タスク2

    ## 依存関係
    - Blocked by: なし

#### Sub-issues

1. {Sub-issueタイトル}
   - labels: {label1}, {label2}
   - body: |
       ## 概要
       {概要テキスト}
       ## タスク
       - [ ] タスク1

2. {Sub-issueタイトル}
   - labels: {label1}, {label2}
   - body: |
       ## 概要
       {概要テキスト}
       ## タスク
       - [ ] タスク1

### 2. {Issueタイトル}

- labels: {label1}, {label2}, ...
- blocked_by: [1]
- body: |
    ## 概要
    {概要テキスト}

    ## タスク
    - [ ] タスク1

    ## 依存関係
    - Blocked by: （Issue作成時に実番号に置換）

#### Sub-issues
...

## 依存関係グラフ

#1 → #2
#1 → #3
```

#### フォーマットルール

- Issueは `### {連番}. {タイトル}` で定義
- `labels`: カンマ区切りのラベル一覧
- `blocked_by`: 依存先Issueの連番リスト（`[]` は依存なし）
- `body`: `|` の後にインデント付きでIssue本文（Markdown）
- Sub-issuesは `#### Sub-issues` セクション内に番号付きリストで定義
- 依存関係グラフは `#連番 → #連番` 形式

---

## Part 2: Issue作成（issues-creator-agent が使用）

### ワークフロー

```
1. .issues-plan.md の読み込みとパース
   ↓
2. ユーザーに確認・承認
   ↓
3. TaskCreateで全タスク事前作成
   ↓
4. Epic Issue作成
   ↓
5. Issue作成（依存関係順に1件ずつ）
   ↓
6. Epic ← Issue 親子リンク設定
   ↓
7. Sub-issue作成（各Issueごと）
   ↓
8. Issue ← Sub-issue 親子リンク設定
   ↓
9. Epic本文をIssue番号で更新
   ↓
10. 完了サマリー報告
```

### Step 1: `.issues-plan.md` の読み込みとパース

プロジェクトルートの `.issues-plan.md` を読み込み、以下を抽出する:

- **Epic**: タイトル、ラベル
- **Issues**: 各Issueのタイトル、ラベル、依存関係（blocked_by）、本文
- **Sub-issues**: 各Issue配下のSub-issueタイトル、ラベル、本文
- **依存関係グラフ**

#### パースルール

- `### {数字}. ` で始まる行がIssue定義の開始
- `- labels:` の値はカンマ区切りでsplit
- `- blocked_by: [{...}]` は数値配列としてパース（`[]` は依存なし）
- `- body: |` の次行以降、インデントされた行がIssue本文
- `#### Sub-issues` 以降の番号付きリストがSub-issue定義

### Step 2: ユーザー確認

パース結果をユーザーに提示し、承認を得る。

### Step 3: タスク管理

- **承認後、作成に着手する前に全タスクをTaskCreateで作成する**
- タスクは1 Issue = 1タスクで管理（Epic + 各Issue + Sub-issue一括 + リンク設定）
- `activeForm`を必ず設定する
- 作成開始時: `TaskUpdate`で`status: "in_progress"`に更新
- 作成完了後: `TaskUpdate`で`status: "completed"`に更新

### Step 4: Epic Issue作成

テンプレート: `references/templates/epic.template.md`

```bash
EPIC_URL=$(gh issue create \
  --title "[Epic] {タイトル}" \
  --body "$(cat <<'EOF'
## 概要
{概要}

## Issue一覧
（作成後に更新）
EOF
)" \
  --label "type:epic")

EPIC_NUM=$(echo "$EPIC_URL" | grep -oE '[0-9]+$')
```

### Step 5: Issue作成

`blocked_by` に基づいてトポロジカルソートし、依存元を先に作成。
作成時に連番を実際のGitHub Issue番号に置換して本文に埋め込む。

#### Issue種類とテンプレート

| 種類 | テンプレート | ラベル |
|:--|:--|:--|
| Feature | `references/templates/feature.template.md` | `type:feature` |
| Migration | `references/templates/migration.template.md` | `type:migration` |
| Test | `references/templates/test.template.md` | `type:test` |
| Docs | `references/templates/docs.template.md` | `type:docs` |
| Chore | `references/templates/chore.template.md` | `type:chore` |

```bash
CHILD_URL=$(gh issue create \
  --title "{タイトル}" \
  --body "{本文（blocked_byを実番号に置換済み）}" \
  --label "{label1}" --label "{label2}" ...)
```

### Step 6: Epic ← Issue 親子リンク設定

```bash
REPO_OWNER=$(gh repo view --json owner --jq '.owner.login')
REPO_NAME=$(gh repo view --json name --jq '.name')

# Node ID取得
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      issue(number: $number) { id }
    }
  }
' -f owner="$REPO_OWNER" -f repo="$REPO_NAME" -F number={issue_number}

# 紐付け
gh api graphql -f query='
  mutation($parentId: ID!, $childId: ID!) {
    addSubIssue(input: {issueId: $parentId, subIssueId: $childId}) {
      issue { id title }
      subIssue { id title }
    }
  }
' -f parentId="{epic_node_id}" -f childId="{issue_node_id}"
```

### Step 7: Sub-issue作成

各Issueに対して `.issues-plan.md` に定義されたSub-issueを作成。
タイトルは親Issueのプレフィックスを引き継ぐ。

```bash
SUB_URL=$(gh issue create \
  --title "{parent_prefix} - {sub_issue_title}" \
  --body "{Sub-issue本文}" \
  --label "{label1}" --label "{label2}")
```

### Step 8: Issue ← Sub-issue 親子リンク設定

```bash
gh api graphql -f query='
  mutation($parentId: ID!, $childId: ID!) {
    addSubIssue(input: {issueId: $parentId, subIssueId: $childId}) {
      issue { id title }
      subIssue { id title }
    }
  }
' -f parentId="{issue_node_id}" -f childId="{sub_issue_node_id}"
```

### Step 9: Epic本文更新

全Issue作成後、Epicの「Issue一覧」を実番号で更新。

```markdown
## Issue一覧
- [ ] #{issue_1} {タイトル}
- [ ] #{issue_2} {タイトル} (Blocked by #{issue_1})
```

### Step 10: 完了サマリー報告

```
## Issue作成サマリー

### Epic
- #{epic_number} [Epic] {タイトル}

### Issue（{n}件）+ Sub-issue（{m}件）
- [x] #{issue_1} {タイトル} (Sub-issues: #{s1}, #{s2})
- [x] #{issue_2} {タイトル} (Blocked by #{issue_1}) (Sub-issues: #{s3})

### リンク状態
- 全 {n} 件のIssueがEpicにリンク済み
- 全 {m} 件のSub-issueが各親Issueにリンク済み
```

---

## ラベル

リポジトリにラベルがない場合、`scripts/create-github-labels.sh`で一括作成:

```bash
bash plugins/spec-to-issues-plugin/scripts/create-github-labels.sh
```

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

## エラーハンドリング

| 状況 | 対応 |
|:--|:--|
| MDファイルが見つからない | エラー報告、正しいパスを確認 |
| MDファイルが空 | エラー報告、処理中止 |
| H1見出しがない | ファイル名をEpicタイトルとして使用 |
| H2セクションがない | 警告を出し、Epic単体の作成を提案 |
| `.spec-to-issues.yml`が不正 | YAML解析エラーを報告、デフォルトにフォールバック |
| `.issues-plan.md`が既に存在 | 上書きするか確認 |
| `.issues-plan.md`が見つからない | spec-analyzer-agentの実行を案内 |
| `.issues-plan.md`のパース失敗 | エラー箇所を報告、フォーマット修正を案内 |
| `gh` CLIが未認証 | `gh auth login` の実行を案内 |
| ラベルが未作成 | `create-github-labels.sh` の実行を案内 |
| Issue作成APIエラー | エラー報告、1回リトライ、それでも失敗ならユーザーに確認 |
| GraphQL `addSubIssue`失敗 | 報告するが続行（手動リンクを案内） |
| Issue数が20件超 | 作成前にユーザーに確認 |
| Sub-issue数が多すぎる（1 Issueあたり8件超） | 粒度の再検討を提案 |

## 禁止事項

- ユーザーの承認なしにIssueを作成しない
- 元のMDファイルを変更しない
- 重複Issueを作成しない（既存Issueを事前確認）
- `gh issue create` 以外の方法でIssueを作成しない
