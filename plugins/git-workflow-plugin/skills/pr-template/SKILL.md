---
name: pr-template
description: PRテンプレート生成スキル。AIがPR本文を生成するためのYAML形式テンプレートを作成する。「PRテンプレートを作成」「プルリクテンプレート生成」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Read, Write, Glob
---

# PRテンプレート生成

プロジェクト用のPR生成テンプレートをYAML形式で生成するスキル。

## 概要

`references/default-template.yml` をベースに、プロジェクト直下の `.claude/.pr-template.yml` にテンプレートを生成する。

## 出力先

既定はプロジェクト直下の `.claude/.pr-template.yml`。`decision_record.mode` のような運用方針はプロジェクトごとに変わるため、プラグインのインストール先ではなくプロジェクト側に置く。

複数プロジェクトで共通の設定を使いたい場合のみ `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/pull-request/.pr-template.yml` に出力する。`pull-request` スキルはプロジェクト直下 → プラグイン配下 → `references/pr-template.md` の順で探す。

## 生成ルール

1. `references/default-template.yml` の内容を読み込む
2. プロジェクトの開発フローに合わせてタイプ・必須項目・チェック項目・`decision_record.mode` を調整する
3. `.claude/.pr-template.yml` として出力する

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

decision_record:
  mode: "standard"          # off | minimal | standard | detailed
  escalate_when: [mode を1段階上げる変更]
  source: "git log <base_branch>..HEAD --format=%B"
  modes:
    "standard": [出力する小見出しのkey]
  subsections:
    - key: "小見出しキー"
      title: "見出し"
      prompt: "何を書くかの指示"

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

### decision_record セクション

PR 本文の「意思決定と経緯」をどこまで書くかを制御する。設計メモを別ファイルに残す代わりに、判断の経緯をコミット本文と PR 本文へ蓄積する運用のための設定。

`mode`（`off` / `minimal` / `standard` / `detailed`）と、各 mode が出力する小見出しの対応は `references/default-template.yml` の `decision_record.modes` が正典。

- `decision_record` 自体が無い場合、`pull-request` スキルは `standard` として扱う
- `source` は各コミット本文に記録された意思決定の収集元コマンド。`commit` スキルの `decision_record` と対になる
- `modes` のキーは必ずクォートする（YAML 1.1 では `off` が真偽値として解釈されるため）
- `decisions` セクションの出力可否は `decision_record.mode` が決める。`body_sections` の `decisions` には `required: "by_decision_record"` を指定し、`true`/`false` は書かない（2箇所で同じことを制御すると優先順位が不定になる）
- `subsections` は `decisions` セクションの内部小見出し。PR本文のセクション群である `body_sections` とは別レイヤー

### pr_watch セクション

PR作成後にCI完了とCopilot等のレビュー完了を自動監視するかを制御するフラグ。`enabled: true` にすると、`pr-creation-agent` が PR 作成成功後に `pr-watch` スキルを起動する。監視対象レビュアー・CI失敗時の挙動・未解決時の挙動・ポーリング間隔は workflow-automation-plugin の `.plugin-workspace/pull-request/.pr-review-fix.yml` の `pr-watch` セクションで指定する（Glob: `**/.plugin-workspace/pull-request/.pr-review-fix.yml`）。

後方互換: `pr_watch` が無い場合は `review_watch` にフォールバックする。

### カスタマイズ

プロジェクトに不要なタイプやセクションは削除してよい。必要に応じて独自タイプやルールを追加してよい。

デフォルトテンプレートは `references/default-template.yml` を参照。
