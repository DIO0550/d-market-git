# プルリクエストテンプレート

## 概要

<!-- このプルリクエストで何を変更したかを簡潔に説明してください -->

## 変更内容

### 🎯 変更の種類

<!-- 該当するものにチェックを入れてください -->

- [ ] 🐛 バグ修正 (Bug fix)
- [ ] ✨ 新機能 (New feature)
- [ ] ♻️ リファクタリング (Refactoring)
- [ ] 🎨 UI/UX 改善 (UI/UX improvement)
- [ ] 🐎 パフォーマンス改善 (Performance improvement)
- [ ] 🚨 テスト追加/修正 (Tests)
- [ ] 📖 ドキュメント更新 (Documentation)
- [ ] 🔧 設定変更 (Configuration)
- [ ] 🗑️ 削除 (Removal)

### 📝 詳細な変更内容

<!-- 以下の形式で変更内容を記載してください -->

#### 追加された機能・修正

-

#### 変更されたファイル

-

#### 削除されたファイル・機能

-

## 📊 システム図

<!-- テンプレート(.pr-template.yml)で diagrams が有効な場合のみ記載。無効の場合はセクションごと削除 -->

### 状態マシン / フロー図

```
{ここに状態マシン図またはフロー図を記述すること}
{すべての状態・遷移条件・分岐を含めること}
{変更箇所には [NEW] や [CHANGED] で注釈をつけること}
```

<!--
例 (Mermaid flowchart — デフォルトはこれ):

```mermaid
flowchart TD
    Start([注文作成]) --> Draft[Draft]
    Draft -->|確認| Pending[Pending]
    Draft -->|キャンセル| Cancelled[Cancelled]:::new
    Pending -->|決済完了| Paid[Paid]
    Pending -->|キャンセル| Cancelled
    Paid -->|発送| Shipped[Shipped]
    Shipped -->|配達完了| Delivered[Delivered]
    Delivered --> End([終了])
    Cancelled --> End

    classDef new fill:#ffe4b5,stroke:#d97706,stroke-width:2px
```

例 (ASCII art — flowchart で収まらない場合のフォールバック):

```
                 ┌─────────┐
                 │  Draft  │
                 └────┬────┘
                      │ 確認
          キャンセル   │
     ┌────────────────┤
     │                ▼
     │          ┌──────────┐
     │          │ Pending  │
     │          └────┬─────┘
     │               │
     │    ┌──────────┤
     │    │ キャンセル │ 決済完了
     ▼    ▼          ▼
┌───────────┐  ┌──────────┐
│ Cancelled │  │   Paid   │
│   [NEW]   │  └────┬─────┘
└───────────┘       │ 発送
                    ▼
              ┌──────────┐
              │ Shipped  │
              └────┬─────┘
                   │ 配達完了
                   ▼
              ┌───────────┐
              │ Delivered │
              └───────────┘
```
-->

### データフロー

```
{ここにデータフロー図を記述すること}
{コンポーネント間のデータの流れを含めること}
{変更箇所には [NEW] や [CHANGED] で注釈をつけること}
```

<!--
例:

```
Client (POST /orders/:id/cancel)
    ↓
OrderController.cancel()
    ↓
OrderService.cancel()
    ├─→ OrderRepository.updateStatus(id, 'cancelled')  [NEW]
    │       ↓
    │   Database (orders テーブル)
    │
    └─→ NotificationService.sendCancelEmail()  [NEW]
            ↓
        Email送信 (ユーザーへキャンセル通知)
```
-->

## 📋 関連 Issue

<!-- 関連するIssueがある場合は記載してください -->

- GitHub の PR 画面「Development」セクションで、関連する Issue を必ず Link してください（Linked issues）。
- 本文にも連携キーワードを記載してください。**PRの内容に応じて Close / Refs を使い分ける**:
  - **閉じる場合**: `Closes #<番号>` または `Fixes #<番号>`
    - PRがIssueの要求を完全に実装・解決している
    - ブランチがそのIssue専用に作成されている
    - Bug fixでIssueが報告したバグを直接修正している
  - **参照のみ**: `Refs #<番号>` または `Relates to #<番号>`
    - PRがIssueの一部のみを対応している（Epic等の部分対応）
    - 間接的に関連するが直接的な解決ではない
    - Issueは別PRでCloseされる予定で、このPRは補助的な変更

例:

- Closes #123（このPRで機能を完全に実装）
- Refs #456（Epic の一部対応）

## 🧪 テスト

### テスト実行方法

```bash
# テストコマンドを記載
```

### テスト項目

<!-- 実施したテストについてチェックしてください -->

- [ ] 単体テスト (Unit tests)
- [ ] 統合テスト (Integration tests)
- [ ] E2E テスト (End-to-end tests)
- [ ] 手動テスト (Manual testing)

### テスト結果

<!-- テスト結果を記載してください -->

## 📸 スクリーンショット/動画

<!-- UI変更がある場合は、Before/Afterのスクリーンショットや動画を添付してください -->

### Before

<!-- 変更前のスクリーンショット -->

### After

<!-- 変更後のスクリーンショット -->

## 🔍 レビューポイント

<!-- レビュアーに特に注目してもらいたい点を記載してください -->

-
-
-

## ⚠️ 破壊的変更

<!-- 破壊的変更がある場合はチェックして詳細を記載してください -->

- [ ] この変更は既存の API に破壊的変更を含みます

### 破壊的変更の詳細

<!-- 破壊的変更がある場合、その詳細と移行方法を記載してください -->

## 📚 追加情報

### 参考資料

<!-- 参考にした資料やドキュメントがある場合は記載してください -->

-

### 注意事項

<!-- レビュアーや今後のメンテナンスで注意すべき点があれば記載してください -->

-

## ✅ チェックリスト

<!-- プルリクエストを出す前に以下をチェックしてください -->

- [ ] コードレビューの準備ができている
- [ ] テストが正常に実行される
- [ ] ドキュメントが更新されている（必要に応じて）
- [ ] コミットメッセージが適切な形式で書かれている
- [ ] 関連する Issue が PR の「Development」に Linked されている
- [ ] PR 本文に `Closes #` / `Fixes #` / `Refs #` などで Issue が記載されている
- [ ] セルフレビューを実施した
- [ ] 破壊的変更がある場合は明記されている

## 🤝 レビュアーへのお願い

<!-- レビュアーに対する特別なお願いがあれば記載してください -->

-
-

