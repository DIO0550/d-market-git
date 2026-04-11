---
name: init-pr-review-fix-config
description: PRレビュー修正の設定ファイル(.pr-review-fix/.pr-review-fix.yml)を対話的に生成するスキル。「pr-review-fixの設定を作って」「レビュー修正の設定を初期化して」「pr-review-fixのテンプレート作って」などのリクエスト時に使用。プロジェクトにまだ設定ファイルがない場合や、設定を変更したい場合に使う。
disable-model-invocation: true
allowed-tools: Read, Write, Edit, AskUserQuestion
argument-hint: (引数なし)
---

# PRレビュー修正 設定ファイル生成

`.pr-review-fix/.pr-review-fix.yml` を対話的に作成するスキル。

## デフォルトテンプレート

`references/default-template.yml` をベースに、プロジェクトの `.pr-review-fix/.pr-review-fix.yml` に設定ファイルを生成する。

## ワークフロー

1. `references/default-template.yml` の内容を読み込む
2. プロジェクトルートに既存の `.pr-review-fix/.pr-review-fix.yml` があるか確認する
   - 既にある場合: 内容を読み込んで表示し、上書きするか確認する
3. ユーザーに以下を順番に質問する
4. 回答に基づいて設定ファイルを生成する

## ヒアリング項目

### Q1: スレッド解決時の返信

レビュー指摘を修正してスレッドを解決する際に、返信コメントを残すかどうか。

> スレッド解決時に返信コメントを残しますか？（yes / no）
> - yes: 修正コミットのハッシュ付きで返信してからスレッドを解決します
> - no: 返信なしでスレッドを解決します（従来の動作）

### Q2: 返信テンプレート（Q1がyesの場合のみ）

返信メッセージの形式を固定テンプレートにするか、AIに自動生成させるか。

> 返信メッセージの形式を選んでください:
> 1. テンプレートを指定する（例: `✅ {commit_hash} で修正しました`）
> 2. AIに自動生成させる（指摘内容に応じてAIが適切なメッセージを生成します）

テンプレートを指定する場合は、テンプレート文字列も聞く。利用可能な変数は `{commit_hash}`（ショートコミットハッシュ）。

### Q3: プッシュ後のレビュー再依頼

修正コミットをプッシュした後に、PRの全レビュアーへ再レビュー依頼を出すかどうか。

> プッシュ後にレビュアーへ再レビュー依頼を出しますか？
> 1. skip: 再依頼しない（デフォルト／従来動作）
> 2. auto: 全レビュアーに自動で再依頼する
> 3. ask:  プッシュ時にユーザーへ都度確認する

選択結果を `re-request-review.mode` として設定ファイルに書き込む。

## 生成する設定ファイル

パス: `{プロジェクトルート}/.pr-review-fix/.pr-review-fix.yml`

最終的な YAML は `resolve-reply`（Q1・Q2 の結果）と `re-request-review`（Q3 の結果）の 2 セクションを常に合成して出力する。以下は各セクションのパターン。

### `resolve-reply` セクションのパターン

**パターン1: 返信OFF**

```yaml
resolve-reply:
  # true: 解決時にスレッドへ返信する / false: 返信しない
  enabled: false
```

**パターン2: 返信ON + テンプレート指定**

```yaml
resolve-reply:
  # true: 解決時にスレッドへ返信する / false: 返信しない
  enabled: true
  # 返信テンプレート（利用可能な変数: {commit_hash}）
  template: "{ユーザーが指定したテンプレート}"
```

**パターン3: 返信ON + AI自動生成**

```yaml
resolve-reply:
  # true: 解決時にスレッドへ返信する / false: 返信しない
  enabled: true
  # template省略時はAIが指摘内容に応じて返信メッセージを生成する
```

### `re-request-review` セクション

Q3 の回答をそのまま `mode` に書き込む（`skip` / `auto` / `ask` のいずれか）。

```yaml
re-request-review:
  # auto: 全レビュアーに自動で再レビュー依頼を出す
  # skip: 再依頼しない（従来動作）
  # ask:  プッシュ後にユーザーへ確認する
  mode: {skip | auto | ask}
```

### 合成例

```yaml
# レビュー指摘修正の設定

resolve-reply:
  enabled: true
  # template省略時はAIが指摘内容に応じて返信メッセージを生成する

re-request-review:
  mode: ask
```

## 完了時

生成した設定内容を表示して確認を促す。
