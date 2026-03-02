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

examples:
  - title: "PRタイトル例"
```

### カスタマイズ

プロジェクトに不要なタイプやセクションは削除してよい。必要に応じて独自タイプやルールを追加してよい。

デフォルトテンプレートは `references/default-template.yml` を参照。
