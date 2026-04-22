---
name: pull-request
description: プルリクエスト作成スキル。PRテンプレートに基づいた説明文の作成、変更種類の分類、チェックリストの確認を支援。「PR作成」「プルリクエスト」「レビュー依頼」などのリクエスト時に使用。
allowed-tools: Bash(git *), Bash(gh pr *), Read, Glob, Skill
---

# プルリクエスト作成

PRテンプレートに沿ったプルリクエスト説明文の作成を支援するスキル。

## テンプレート参照順序

PR本文を作成する際は、以下の順でテンプレートを参照する。

1. `.pr-templates/.pr-template.yml`
2. `references/pr-template.md`（フォールバック）

`.pr-templates/.pr-template.yml` がある場合は、その `title_format` / `types` / `body_sections` / `rules` / `checklist` に従ってPRタイトルと本文を生成する。テンプレートが未作成の場合は、`pr-template` スキルでテンプレート生成を提案してよい。

## ベースブランチの決定

PR作成時に `--base` フラグでマージ先ブランチを指定する。

### 決定順序

1. `.pr-templates/.pr-template.yml` の `base_branch` を確認
2. `"auto"` または未指定の場合 → 親ブランチを自動検出する:
   ```bash
   git log --first-parent --decorate=short --simplify-by-decoration --oneline
   ```
   出力の2行目以降で最初に現れるブランチ名が親ブランチ（分岐元）。検出できない場合は `main` にフォールバック
3. 明示的なブランチ名が指定されている場合はそのまま使用

## コマンド実行規約

- **1回のBash呼び出し = 1コマンド**（`&&`, `||`, `;` による複合化禁止）
- PRタイトル・本文は **heredoc** で渡す（ファイル書き出し `--body-file` は使わない）:
  ```bash
  gh pr create --base <base_branch> --title "PRタイトル" --body "$(cat <<'EOF'
  ## 概要
  - 変更内容

  ## テスト計画
  - テスト項目
  EOF
  )"
  ```

## 基本構成

1. **概要**: 変更の簡潔な説明
2. **変更の種類**: タイプ分類（絵文字付き）
3. **詳細な変更内容**: 追加・変更・削除の一覧
4. **システム図**: 変更の視覚的な図解（テンプレートで有効時）
5. **関連Issue**: Linked issues と連携キーワード
6. **テスト**: 実施したテストと結果
7. **レビューポイント**: 注目してほしい箇所

## システム図

テンプレートの `body_sections` で `diagrams` が有効な場合、変更内容に応じたシステム図をPR本文に含める。

### 図の種類と選択基準（優先度順）

原則として優先度の高い記法から順に検討する。上位で表現できるなら下位には降りない。

| 優先度 | 記法 | 使う場面 |
|:-|:-|:-|
| 1 | Mermaid `flowchart` | **デフォルト。** すべての変更（処理フロー・状態遷移・API通信・DBスキーマ・依存関係を含む）をまず四角＋矢印で表現する |
| 2 | ASCII art | flowchart では表現しにくい複雑なレイアウト・複数図の統合 |
| 3 | Mermaid `stateDiagram-v2` / `sequenceDiagram` / `erDiagram` / `graph` | flowchart でも ASCII でも本質を伝えきれない、極めて特殊なケースのみ |

### 記法の使い分け

1. **まず `flowchart` で描けないか検討する** — GitHub でネイティブにレンダリングされ、四角＋矢印で直感的
2. flowchart に収まらない複雑なレイアウトや複数図の統合は ASCII art
3. 専用図（状態マシン図・シーケンス図・ER図・依存関係図）は flowchart / ASCII の両方で本質を伝えきれない極めて特殊なケースのみの最終手段

### 生成ルール

1. **差分ベース**: `git diff` の内容から図に含める要素を判断する
2. **flowchart 優先**: 判断が曖昧・複合的・専用図と flowchart の両方で表現可能な場合は、常に `flowchart` を選ぶ
3. **変更箇所を強調**: 追加された状態・遷移・ノードは視覚的に区別する（Mermaidの `style` やノート、ASCII artの `[NEW]` 注釈など）
4. **簡潔さ優先**: 変更に関連する部分のみ図示し、無関係な全体像は含めない
5. **spec連携**: 対応する `.specs/` の `implementation-plan.md` が存在する場合は、そこに含まれるシステム図を参考にしつつ、実際の差分に基づいて更新・簡略化する

## 変更タイプ

| タイプ | 絵文字 |
|:-|:-|
| バグ修正 | 🐛 |
| 新機能 | ✨ |
| リファクタリング | ♻️ |
| UI/UX改善 | 🎨 |
| パフォーマンス改善 | 🐎 |
| テスト | 🚨 |
| ドキュメント | 📖 |
| 設定変更 | 🔧 |
| 削除 | 🗑️ |

## Issue連携

### 連携キーワード

- **閉じる**: `Closes #123` または `Fixes #123`
- **参照のみ**: `Refs #123` または `Relates to #123`

### 必須事項

- GitHub PR画面の「Development」セクションでIssueをLink
- 本文にも連携キーワードを記載

## チェックリスト

PR作成前の確認事項:

- [ ] コードレビューの準備完了
- [ ] テスト正常実行
- [ ] ドキュメント更新（必要に応じて）
- [ ] 適切なコミットメッセージ
- [ ] IssueがPRにLinked
- [ ] セルフレビュー実施
- [ ] 破壊的変更の明記（該当時）

デフォルトテンプレートは `references/pr-template.md` を参照。

## PR作成後の監視

PR作成成功後に `pr-watch` スキルを起動してCI完了とCopilot等のレビュー完了をバックグラウンド監視する。

### 起動条件

- `.pr-templates/.pr-template.yml` の `pr_watch.enabled`（または `review_watch.enabled`）を参照する
- `false` に明示されている場合は監視しない
- `true` または未指定の場合は監視を起動する（デフォルト: `true`）

### 起動手順

1. `.pr-review-fix/.pr-review-fix.yml` の `pr-watch.review.reviewers` を読む（`pr-watch` が無ければ `review-watch.reviewers` にフォールバック。いずれも無ければ `["copilot"]` をデフォルト）
2. 対象レビュアーを PR に追加する
   ```bash
   gh pr edit <PR番号> --add-reviewer <reviewer1>,<reviewer2>,...
   ```
   - Copilot を追加する場合のハンドルは `copilot-pull-request-reviewer` 固定
3. `Skill` ツールで `pr-watch <PR番号>` を呼び出し、以降は `pr-watch` の仕様に従う
