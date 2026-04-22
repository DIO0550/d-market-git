---
name: pr-template
description: PRテンプレート生成スキル。AIがPR本文を生成するためのYAML形式テンプレートを作成する。「PRテンプレートを作成」「プルリクテンプレート生成」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Read, Write, Glob
---

# PRテンプレート生成

プロジェクト用のPR生成テンプレートをYAML形式で生成するスキル。

## 概要

`references/default-template.yml` をベースに、プロジェクトの `.pr-templates/.pr-template.yml` にテンプレートを生成する。

## 生成ルール

1. `references/default-template.yml` の内容を読み込む
2. プロジェクトの開発フローに合わせてタイプ・必須項目・チェック項目を調整する
3. `.pr-templates/.pr-template.yml` として出力する

## テンプレート仕様

### フォーマット

```yaml
title_format: "<emoji> [<tag>]: #<issue> <subject>"

base_branch: "auto"  # "auto" = 親ブランチ（分岐元）を自動検出 / ブランチ名を直接指定も可能

types:
  カテゴリ名:
    - emoji: "絵文字"
      tag: "タグ名"
      description: "説明"

body_sections:
  - key: "summary"
    title: "概要"
    required: true

rules:
  issue_link:
    required: true
    close_keywords: ["Closes", "Fixes"]
    reference_keywords: ["Refs", "Relates to"]

checklist:
  - "セルフレビュー実施"
  - "テスト実施"

pr_watch:
  enabled: false

examples:
  - title: "PRタイトル例"
```

### base_branch フィールド

PRのマージ先ブランチを制御する。`"auto"` を指定すると、`pull-request` スキルが `git log --first-parent --decorate=short --simplify-by-decoration` で親ブランチ（分岐元）を自動検出する。特定のブランチ名（例: `"develop"`）を指定するとそのブランチを固定で使用する。未指定時は `"auto"` として扱う。

### pr_watch セクション

PR作成後にCI完了とCopilot等のレビュー完了を自動監視するかを制御するフラグ。`enabled: true` にすると、`pr-creation-agent` が PR 作成成功後に `pr-watch` スキルを起動する。監視対象レビュアー・CI失敗時の挙動・未解決時の挙動・ポーリング間隔は `.pr-review-fix/.pr-review-fix.yml` の `pr-watch` セクションで指定する。

後方互換: `pr_watch` が無い場合は `review_watch` にフォールバックする。

### カスタマイズ

プロジェクトに不要なタイプやセクションは削除してよい。必要に応じて独自タイプやルールを追加してよい。

デフォルトテンプレートは `references/default-template.yml` を参照。
