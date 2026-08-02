---
name: plan-template
description: プランIssue用のカスタムテンプレートを生成する。`${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/issues/plan-issue-template.md`（プラン本文）と `plan-report-template.md`（振り返りコメント）をビルトインをベースに対話でカスタマイズして配置。ユーザーが明示的に呼び出した場合のみ使用。
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Glob, AskUserQuestion
argument-hint: [plan / report / both（省略時は both）]
---

# プランテンプレート生成

`plan-issue` / `plan-issue-report` スキルが使うテンプレートを、プロジェクト用にカスタマイズして生成するスキル。

## 概要

以下の 2 つのテンプレートを、ビルトインデフォルトをベースに `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/issues/` に生成する:

| テンプレート | 生成先 | 使うスキル |
|:--|:--|:--|
| プラン本文 | `.plugin-workspace/issues/plan-issue-template.md` | `plan-issue` |
| 振り返りコメント | `.plugin-workspace/issues/plan-report-template.md` | `plan-issue-report` |

生成後は各スキルが自動的にカスタムテンプレートを優先して使用する（カスタム → ビルトインの解決順）。
プロジェクト固有のカスタマイズが不要であれば、このスキルを実行せずとも両スキルはビルトインで正常に動作する。

## 生成ワークフロー

```
1. 対象テンプレートの確認（plan / report / both）
   ↓
2. ビルトインデフォルトの読み込み
   ↓
3. 既存のカスタムテンプレートがあるか確認
   ↓
4. ユーザーにカスタマイズ内容をヒアリング
   ↓
5. ${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/issues/ に生成
```

### Step 1: 対象テンプレートの確認

引数で指定されていればそれに従う。省略時は両方（both）を対象とする。

### Step 2: ビルトインデフォルトの読み込み

ベースとなる構成を読み込む:

- プラン本文: `${CLAUDE_PLUGIN_ROOT}/skills/plan-issue/references/plan-issue-template.md`
- 振り返りコメント: `${CLAUDE_PLUGIN_ROOT}/skills/plan-issue-report/references/plan-report-template.md`

### Step 3: 既存テンプレートの確認

`${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/issues/` に対象ファイルが既に存在する場合:

- 内容を読み込み、ユーザーに「上書き」か「既存をベースに更新」か確認する
- 「更新」の場合は既存のカスタマイズを引き継ぐ

### Step 4: ユーザーへのヒアリング

以下を確認する（全項目スキップ可能。スキップ時はビルトインの構成をそのまま使用）:

**プラン本文テンプレート（plan-issue-template.md）:**

1. **セクション構成**: デフォルト（メタ情報 / 背景 / ゴール / 非ゴール / 検討した選択肢 / 決定 / 実装方針 / リスク / 検証方法 / 参考資料）で十分か、追加・削除したいセクションがあるか
2. **実装方針の粒度**: サブセクション（全体設計 / インターフェース設計 / 変更対象と影響範囲 / 実装の順序 / 採用する規約）を増減したいか
3. **メタ情報の項目**: ベースブランチ・作業ブランチ・関連Issue 以外に記録したい項目があるか（例: 対象マイルストーン、レビュアー）

**振り返りコメントテンプレート（plan-report-template.md）:**

1. **セクション構成**: デフォルト（結果 / 想定と違った点 / プランからの変更 / 積み残し / 学び・メモ）で十分か、追加・削除したいセクションがあるか
2. **結果の項目**: ステータス・PR/コミット・作業ブランチ以外に記録したい項目があるか（例: 実績工数）

### Step 5: テンプレートの生成

ヒアリング結果を反映して `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/issues/` に生成する。

**生成時のルール:**

- プレースホルダーは `{説明}` 形式を維持する（各スキルが埋める箇所の目印になる）
- セクションを削除する場合でも、`plan-issue` スキルの必須セクション（メタ情報 / 背景 / ゴール / 検討した選択肢 / 決定 / 実装方針 / 検証方法）を削る場合はその影響（記録が薄くなる）を説明して確認する
- チェックリスト形式の「実装ステップ（作業手順）」セクションの追加を求められた場合、プランIssueの設計方針（手順ではなく判断の記録）と衝突する旨を説明したうえで、それでも必要なら追加する

## エラーハンドリング

| 状況 | 対応 |
|:--|:--|
| ビルトインテンプレートが読み込めない | エラー報告、プラグインの再インストールを案内 |
| `.plugin-workspace/issues/` が作成できない | エラー報告、権限を確認 |
| 既存カスタムテンプレートが不正な内容 | 内容を提示し、上書きするか確認 |

## 禁止事項

- ユーザーの確認なしに既存のカスタムテンプレートを上書きしない
- ビルトインテンプレート（`skills/*/references/` 配下）を書き換えない
