---
name: commit-template
description: コミットメッセージテンプレート生成スキル。プロジェクトに配置するYAML形式のコミットテンプレートファイルを生成する。「コミットテンプレートを作成」「テンプレート生成」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Read, Write, Glob
---

# コミットテンプレート生成

プロジェクト用のコミットメッセージテンプレートをYAML形式で生成するスキル。

## 概要

`references/default-template.yml` をベースに、プロジェクトの `.commit-templates/.commit-template.yml` にテンプレートを生成する。

## 生成ルール

1. `references/default-template.yml` の内容を読み込む
2. プロジェクトの要件に応じてタイプを取捨選択する
3. `.commit-templates/.commit-template.yml` として出力する

## テンプレート仕様

### フォーマット

```
<emoji> [<tag>]: #<Issue番号> <subject>
```

### YAML構造

```yaml
format: "<emoji> [<tag>]: #<issue> <subject>"

types:
  カテゴリ名:
    - emoji: "絵文字"
      tag: "タグ名"
      description: "説明"

rules:
  granularity: "分割ルール"
  max_lines: 変更行数の目安
  forbidden_commands: [禁止コマンド]

examples:
  - "コミットメッセージ例"
```

### カスタマイズ

プロジェクトに不要なカテゴリやタイプは削除してよい。必要に応じて独自のタイプを追加してもよい。

デフォルトテンプレートは `references/default-template.yml` を参照。
