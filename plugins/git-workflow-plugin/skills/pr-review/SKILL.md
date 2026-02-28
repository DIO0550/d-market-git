---
name: pr-review
description: コードレビュースキル。PR番号またはブランチ名を指定して、差分コードの総合レビューを実施しGitHubにレビューコメントを投稿する。「レビューして」「コードレビュー」「PRをレビュー」「ブランチのレビュー」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Bash(gh *), Bash(git *), Read, Grep, Glob
argument-hint: [PR番号 or ブランチ名（省略可）]
---

# コードレビュー

PR番号またはブランチ名から差分を取得し、プロジェクト規約に基づいた総合レビューを行い、GitHubにレビューコメントを投稿する。

## PR特定

### 引数ありの場合

以下の自動取得データを使用する。

- PR情報: !`[ -n "$0" ] && gh pr view "$0" --json number,title,body,baseRefName,headRefName 2>/dev/null || true`
- 変更ファイル一覧: !`[ -n "$0" ] && gh pr diff "$0" --name-only 2>/dev/null || true`
- diff: !`[ -n "$0" ] && gh pr diff "$0" 2>/dev/null || true`

### 引数なしの場合

オープン中のPR一覧を取得してユーザーに選択させる。

```bash
gh pr list --state open --json number,title,headRefName --template '{{range .}}#{{.number}} {{.title}} ({{.headRefName}}){{"\n"}}{{end}}'
```

番号とタイトルの一覧をユーザーに提示し、レビュー対象を選んでもらう。ユーザーが選択したPR番号で `gh pr view` / `gh pr diff` を実行して以降のワークフローに進む。

## ワークフロー

```
1. 上記の自動取得データを確認（取得失敗時はユーザーに報告して中断）
   ↓
2. プロジェクト規約の収集（CLAUDE.md、lint設定、tsconfig等）
   ↓
3. 変更ファイルの全文読み込み（差分だけでなくコンテキストを理解）
   ↓
4. レビュー観点ごとに分析
   ↓
5. レビュー結果をユーザーに提示して確認
   ↓
6. 承認後、GitHubにレビュー投稿
```

## プロジェクト規約の収集

レビューの精度を高めるため、プロジェクト固有のルールや規約を事前に収集する。以下のファイルが存在する場合は読み込む。

| ファイル | 目的 |
|:-|:-|
| `CLAUDE.md` | プロジェクト固有のルール・規約 |
| `.eslintrc.*` / `eslint.config.*` | ESLintルール |
| `tsconfig.json` | TypeScript設定 |
| `.prettierrc*` | フォーマットルール |
| `biome.json` / `biome.jsonc` | Biomeルール |
| `.editorconfig` | エディタ設定 |
| `package.json`（scriptsセクション） | lint/test/buildコマンド |

全ファイルを必ず読む必要はない。変更対象の言語・技術スタックに関連するものだけ読み込む。

## 変更ファイルの読み込み

diffだけでは文脈を把握できないため、変更があったファイルの全文を読み込む。

- 変更ファイルが多い場合（10ファイル以上）は、主要な変更ファイルを優先して読む
- テストファイルや設定ファイルの変更は、対応する実装ファイルとセットで読む
- 新規ファイルはdiffに全文含まれるため、別途読み込み不要

## レビュー観点

以下の観点で総合的にレビューする。すべての観点で問題がなければ無理に指摘を作る必要はない。本当に重要な問題にだけ集中する。

### 1. バグ・ロジックエラー

- null/undefined参照の可能性
- 境界値・エッジケースの考慮漏れ
- 条件分岐のミス（off-by-one等）
- 非同期処理の誤り（await漏れ、race condition）
- エラーハンドリングの欠如

### 2. セキュリティ

- インジェクション脆弱性（SQL, XSS, コマンド）
- 認証・認可の不備
- 機密情報のハードコード
- 安全でない暗号化・ハッシュの使用

### 3. パフォーマンス

- N+1クエリ
- 不要なループ・再計算
- メモリリークの可能性
- 大量データ処理での非効率

### 4. 可読性・保守性

- 変数名・関数名の適切さ
- 関数の責務過多（Single Responsibility違反）
- 重複コード
- マジックナンバーの使用

### 5. 設計・アーキテクチャ

- SOLID原則との整合性
- 既存パターンとの一貫性
- 適切な抽象化レベル
- 変更の影響範囲

### 6. プロジェクト規約準拠

- 収集した規約との整合性
- 命名規則の遵守
- ディレクトリ構成の慣例

## レビューコメントの作成

### コメントの分類

各指摘に重要度を付与する:

| レベル | ラベル | 説明 |
|:-|:-|:-|
| 高 | `[MUST]` | 修正必須。バグ、セキュリティ脆弱性、データ損失リスク |
| 中 | `[SHOULD]` | 強く推奨。パフォーマンス問題、設計上の懸念 |
| 低 | `[NITS]` | 軽微。命名改善、スタイル、コメント |
| - | `[QUESTION]` | 質問。意図の確認や設計判断の理由を聞く |

### コメントフォーマット

各指摘は以下の形式で記述する:

```
**[レベル]** 観点カテゴリ

指摘内容の説明。

なぜ問題なのか、どう修正すべきかを具体的に記載。

```suggestion（コード提案がある場合）
修正後のコード
```
```

### 全体サマリー

レビュー本文の冒頭に全体サマリーを記載する:

```
## コードレビュー

### 概要
{変更の概要を1-2文で}

### 指摘サマリー
- MUST: {件数}件
- SHOULD: {件数}件
- NITS: {件数}件
- QUESTION: {件数}件

### 良い点
{良い変更があれば言及する}

### 総合所見
{全体的な評価と主要な懸念点}
```

## GitHubへの投稿

GitHubの「Files changed」上で、レビュアーが各変更行にコメントを付けて最後にまとめてSubmitする、通常のレビューフローと同じ形式で投稿する。

具体的には:
- 各指摘 → 該当ファイルの該当行に紐づくレビューコメント（Files changedタブで差分の横に表示される）
- 全体サマリー → レビュー本文（Conversationタブに表示される）

これらが1つのレビューとしてまとまって投稿される。

### レビューイベントの選択

指摘の内容に応じて適切なレビューイベントを選択する:

| 条件 | イベント | 説明 |
|:-|:-|:-|
| MUSTの指摘あり | `REQUEST_CHANGES` | 変更を要求 |
| SHOULDのみ | `COMMENT` | コメントとして投稿 |
| NITSのみ or 指摘なし | `APPROVE` | 承認（軽微な指摘つき、または指摘なし） |

### 投稿手順

3ステップで投稿する。人間のレビュアーが「Files changed」でコメントを書き溜めてから「Submit review」するのと同じ流れをAPIで再現する。

#### Step 1: Pendingレビューを作成

```bash
gh api \
  "repos/{owner}/{repo}/pulls/{pr_number}/reviews" \
  --method POST \
  --field body="全体サマリー" \
  --jq '.id'
```

これでレビューIDが返る。この時点ではまだ下書き（PENDING）状態。

#### Step 2: 各指摘をレビューコメントとして追加

指摘ごとに、該当ファイル・該当行にコメントを追加する。すべて Step 1 で作成したレビューに紐づく。

```bash
gh api \
  "repos/{owner}/{repo}/pulls/{pr_number}/reviews/{review_id}/comments" \
  --method POST \
  --field path="src/utils/parser.ts" \
  --field line=42 \
  --field side="RIGHT" \
  --field body="**[MUST]** バグ

説明..."
```

コード修正の提案がある場合は、GitHub Suggested Changes形式を使う:

````bash
gh api \
  "repos/{owner}/{repo}/pulls/{pr_number}/reviews/{review_id}/comments" \
  --method POST \
  --field path="src/utils/parser.ts" \
  --field line=42 \
  --field side="RIGHT" \
  --field body='**[SHOULD]** パフォーマンス

`Array.find`の方が意図が明確です。

```suggestion
const user = users.find(u => u.id === targetId);
```'
````

全指摘を追加し終わるまで繰り返す。

#### Step 3: レビューをSubmit

全コメントの追加が完了したら、レビューを確定する。

```bash
gh api \
  "repos/{owner}/{repo}/pulls/{pr_number}/reviews/{review_id}/events" \
  --method POST \
  --field event="{APPROVE|COMMENT|REQUEST_CHANGES}"
```

これで全コメントが1つのレビューとしてまとめて公開される。

### コメントのフィールド仕様

| フィールド | 必須 | 説明 |
|:-|:-|:-|
| `path` | Yes | リポジトリルートからの相対ファイルパス |
| `line` | Yes | コメントを付ける行番号（diff上の新ファイル側の行番号） |
| `side` | Yes | `RIGHT`（新コード側）を指定する |
| `start_line` | No | 複数行に対するコメントの開始行（`line`が終了行になる） |
| `body` | Yes | コメント本文（Markdown対応） |

### 行番号の特定方法

コメントの`line`はdiffのハンク情報から特定する。diffの`@@`行に含まれる新ファイル側の行番号を使用する。

```
@@ -10,6 +12,8 @@
```

この場合、`+12`が新ファイルの開始行。diffの`+`行を数えて該当行の行番号を算出する。変更行（`+`で始まる行）だけでなく、コンテキスト行（` `で始まる行）にもコメントを付けられる。

### 投稿前のユーザー確認

投稿前に以下をユーザーに提示して確認を取る:

1. レビューイベント（APPROVE / COMMENT / REQUEST_CHANGES）
2. 指摘一覧（レベル、ファイル、行番号、内容の要約）
3. 全体サマリーの内容

ユーザーが承認したら投稿を実行する。

## 禁止事項

- diffを読まずにレビューすること
- 変更に関係のないコードへの指摘
- スタイルの好みだけに基づく指摘（プロジェクト規約にない限り）
- 過度に細かい指摘の大量投稿（重要な問題に集中する）
- ユーザーの承認なしにREQUEST_CHANGESイベントで投稿すること
