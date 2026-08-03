---
name: commit-template
description: コミットメッセージテンプレート生成スキル。プロジェクトに配置するYAML形式のコミットテンプレートファイルを生成する。「コミットテンプレートを作成」「テンプレート生成」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Read, Write, Glob
---

# コミットテンプレート生成

プロジェクト用のコミットメッセージテンプレートをYAML形式で生成するスキル。

## 概要

`references/default-template.yml` をベースに、プロジェクト直下の `.claude/.commit-template.yml` にテンプレートを生成する。

## 出力先

既定はプロジェクト直下の `.claude/.commit-template.yml`。`decision_record.mode` のような運用方針はプロジェクトごとに変わるため、プラグインのインストール先ではなくプロジェクト側に置く。

複数プロジェクトで共通の設定を使いたい場合のみ `${CLAUDE_PLUGIN_ROOT}/.plugin-workspace/commit/.commit-template.yml` に出力する。`commit` スキルはプロジェクト直下 → プラグイン配下 → 既定値の順で探す。

## 生成ルール

1. `references/default-template.yml` の内容を読み込む
2. プロジェクトの要件に応じてタイプを取捨選択し、`decision_record.mode` を決める
3. `.claude/.commit-template.yml` として出力する

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

decision_record:
  mode: "standard"          # off | minimal | standard | detailed
  escalate_when: [mode を1段階上げる変更]
  skip_when: [mode を1段階下げる変更]
  modes:
    "standard": [出力するセクションのkey]
  sections:
    - key: "セクションキー"
      title: "見出し"
      prompt: "何を書くかの指示"
  format:
    heading_style: "<title>:"
    wrap_width: 72

rules:
  granularity: "分割ルール"
  max_lines: 変更行数の目安
  forbidden_commands: [禁止コマンド]

examples:
  - subject: "コミットメッセージ例"
    mode: "standard"
    body: |
      本文例
```

### decision_record セクション

コミット本文に意思決定（背景・なぜ・代替案・影響）をどこまで書くかを制御する。実装プランを別ファイルに残す代わりに、判断の経緯をコミット本文へ蓄積する運用のための設定。

`mode`（`off` / `minimal` / `standard` / `detailed`）と各 mode が出力するセクションの対応は `references/default-template.yml` の `decision_record.modes` が正典。

- `decision_record` 自体が無い場合、`commit` スキルは `standard` として扱う
- `modes` のキーは必ずクォートする（YAML 1.1 では `off` が真偽値として解釈されるため）
- `sections` の `title` はコミット本文の見出し文字列になる。`git log --grep` の検索性に直結するため、プロジェクト内で表記を統一する
- 見出しに行頭 `#` の Markdown 記法は使わない（エディタ経由の編集時に git がコメント行として除去することがある）

### カスタマイズ

プロジェクトに不要なカテゴリやタイプは削除してよい。必要に応じて独自のタイプを追加してもよい。

`decision_record` はプロジェクトの運用に合わせて調整する。

- 本文を書かない運用にする → `mode: "off"`
- 設計判断を厚く残す → `mode: "detailed"`
- 独自のセクション（例: 「移行手順」「ロールバック方法」）を足す → `sections` に追加し、`modes` の対象 mode に key を並べる

デフォルトテンプレートは `references/default-template.yml` を参照。
