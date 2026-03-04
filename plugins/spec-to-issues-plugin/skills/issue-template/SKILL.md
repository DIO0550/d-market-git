---
name: issue-template
description: Issueフォーマット定義YAMLを生成する。`.spec-to-issues/issue-template.yml`にタイプ別本文テンプレート・タイトル形式・ラベル体系・ルールを定義。ユーザーが明示的に呼び出した場合のみ使用。
user-invocable: true
disable-model-invocation: true
allowed-tools: Read, Write, Glob, AskUserQuestion
argument-hint: [プロジェクトパス（省略時はカレント）]
---

# Issueテンプレート生成

プロジェクト用のIssueフォーマットをYAML形式で定義・生成するスキル。

## 概要

`references/default-template.yml` をベースに、プロジェクトの `.spec-to-issues/issue-template.yml` にテンプレートを生成する。
このYAMLは `spec-to-issues` スキルがIssue作成時に参照するフォーマット定義として機能する。

## 生成ワークフロー

```
1. references/default-template.yml を読み込む
   ↓
2. 既存の .spec-to-issues/issue-template.yml があるか確認
   ↓
3. ユーザーにカスタマイズ内容をヒアリング
   ↓
4. .spec-to-issues/issue-template.yml を生成
```

### Step 1: デフォルトテンプレートの読み込み

`references/default-template.yml` を読み込み、ベースとなるYAML構造を把握する。

### Step 2: 既存テンプレートの確認

`.spec-to-issues/issue-template.yml` が既に存在する場合:
- 内容を読み込み、ユーザーに「上書き」か「既存をベースに更新」か確認する
- 「更新」の場合は既存の設定を引き継ぐ

### Step 3: ユーザーへのヒアリング

以下を確認する（全項目スキップ可能。スキップ時はデフォルト値を使用）:

1. **Issueタイプ**: デフォルト6種（Feature, Bug, Migration, Test, Docs, Chore）で十分か、追加・削除したいタイプがあるか
2. **タイトルフォーマット**: デフォルトの `[Type] subject` 形式でよいか
3. **ラベル体系**: 種別・エリア・優先度・サイズのラベル名をカスタマイズしたいか
4. **本文セクション**: タイプ別の必須/任意セクションを変更したいか

### Step 4: YAMLの生成

ヒアリング結果を反映して `.spec-to-issues/issue-template.yml` を生成する。

## YAML構造

デフォルトテンプレートの全体構造は `references/default-template.yml` を参照。主要セクションは以下の通り:

### title_formats

Issueタイプ別のタイトル形式。プレースホルダー `{title}`, `{area}`, `{component}`, `{summary}`, `{suffix}` が使用可能。

```yaml
title_formats:
  feature: "[Feature][{area}] {component}: {summary}"
  bug: "[Bug][{area}] {summary}"
```

### types

Issueタイプの定義。各タイプにラベル・説明・本文テンプレートを持つ。

```yaml
types:
  - name: feature
    label: "type:feature"
    description: "新機能・機能追加"
    body_sections:
      - key: overview
        title: "概要"
        required: true
```

### labels

ラベル体系の定義。種別・エリア・優先度・サイズの4カテゴリ。

```yaml
labels:
  area:
    - name: "area:frontend"
      keywords: ["UI", "component", "React"]
```

### rules

Issueの品質ルール。

```yaml
rules:
  require_acceptance_criteria: true
  require_task_checklist: true
```

## spec-to-issues スキルとの連携

このスキルで生成した `.spec-to-issues/issue-template.yml` は、`spec-to-issues` スキルが自動的に参照する。

### テンプレート解決の優先順位（spec-to-issues側）

```
1. .spec-to-issues/issue-template.yml が存在する → YAMLの定義を使用
2. YAMLが存在しない → references/templates/*.template.md にフォールバック
```

つまり:
- **YAMLを生成済み**: `spec-to-issues` はYAMLの `types[].body_sections` からIssue本文を組み立て、`title_formats` でタイトルを整形し、`labels` でラベルを付与する
- **YAMLが未生成**: `spec-to-issues` は従来通りビルトインの `.template.md` ファイルを使用する

プロジェクト固有のフォーマットが不要であれば、このスキルを実行せずとも `spec-to-issues` は正常に動作する。

## カスタマイズ

- プロジェクトに不要なタイプは削除してよい
- 独自タイプの追加も可能（`name`, `label`, `description`, `body_sections` を定義）
- ラベルのキーワードはプロジェクトの技術スタックに合わせて調整
- `body_sections` の `required: true/false` でIssue作成時の必須チェックを制御

デフォルトテンプレートは `references/default-template.yml` を参照。
