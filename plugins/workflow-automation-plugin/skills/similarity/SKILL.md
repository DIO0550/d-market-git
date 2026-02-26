---
name: similarity
description: similarity-tsで重複コード検出とリファクタリング計画を立てるスキル。「重複コード検出」「類似コード」「共通化」などのリクエスト時に使用。
disable-model-invocation: true
allowed-tools: Bash(similarity-ts *)
argument-hint: [threshold] [min-lines]
---

# 重複コード検出

similarity-ts を利用してコードの意味的な類似を検出し、リファクタリング計画を立てるスキル。

## 使用方法

```bash
similarity-ts . --threshold 0.8 --min-lines 10
```

- `--threshold`: 類似度の閾値（0.0〜1.0、デフォルト: 0.8）
- `--min-lines`: 最小行数（デフォルト: 10）

細かいオプションは `similarity-ts -h` で確認。

## ワークフロー

1. `similarity-ts` を実行して重複コードを検出
2. 検出結果を分析し、共通化可能な箇所を特定
3. リファクタリング計画を立案して報告
