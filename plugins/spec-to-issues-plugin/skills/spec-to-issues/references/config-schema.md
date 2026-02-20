# `.spec-to-issues.yml` 設定スキーマ

プロジェクトルートに `.spec-to-issues.yml` を配置することで、Issue生成のルールをカスタマイズできます。
全フィールドはオプションです。未指定の場合はデフォルト値が使用されます。

## 全設定項目

```yaml
# タイトルフォーマットのカスタマイズ
# {title}, {area}, {component}, {summary}, {suffix} が使用可能
title_formats:
  epic: "[Epic] {title}: {suffix}"          # デフォルト
  feature: "[Feature][{area}] {component}: {summary}"
  migration: "[Migration] {summary}"
  test: "[Test] {summary}"
  docs: "[Docs] {summary}"
  chore: "[Chore] {summary}"

# Epicタイトルのサフィックス
epic_suffix: "実装計画と進行管理"              # デフォルト

# ラベル設定
labels:
  # デフォルトラベルの上書き
  defaults:
    priority: "priority:P2"                   # デフォルト優先度
    size: "size:M"                            # デフォルトサイズ
  # カスタムラベルの追加
  custom:
    - name: "sprint:current"
      auto_apply: true                        # 全Issueに自動付与
    - name: "team:backend"
      auto_apply: false                       # 手動で選択

# エリア判定のキーワードカスタマイズ
area_keywords:
  frontend:
    - "UI"
    - "component"
    - "page"
    - "screen"
    - "CSS"
    - "React"
    - "Vue"
  server:
    - "API"
    - "endpoint"
    - "database"
    - "server"
    - "handler"
  shared:
    - "shared"
    - "common"
    - "utils"
    - "types"
    - "interface"

# テンプレート上書き（ファイルパスで指定）
# 指定しないタイプはビルトインデフォルトを使用
templates:
  epic: ".github/issue-templates/epic.md"
  feature: ".github/issue-templates/feature.md"

# Issue分解の設定
decomposition:
  max_days_per_issue: 3                       # 1 Issueあたりの最大作業日数（超えたら分割推奨）
  min_issues: 2                               # 最小Issue数（少なすぎる場合は警告）
  max_issues: 20                              # 最大Issue数（多すぎる場合は確認）

# Assignee設定
assignees:
  default: ""                                 # デフォルトのassignee（空=なし）
  by_area:                                    # エリア別assignee
    frontend: "frontend-dev"
    server: "backend-dev"

# Milestone設定
milestone: ""                                 # マイルストーン名（空=なし）

# Project設定
project: ""                                   # GitHub Projectの名前またはID（空=なし）
```

## デフォルト値一覧

| フィールド | デフォルト値 |
|:--|:--|
| `title_formats.epic` | `[Epic] {title}: 実装計画と進行管理` |
| `title_formats.feature` | `[Feature][{area}] {component}: {summary}` |
| `title_formats.migration` | `[Migration] {summary}` |
| `title_formats.test` | `[Test] {summary}` |
| `title_formats.docs` | `[Docs] {summary}` |
| `title_formats.chore` | `[Chore] {summary}` |
| `epic_suffix` | `実装計画と進行管理` |
| `labels.defaults.priority` | `priority:P2` |
| `labels.defaults.size` | `size:M` |
| `decomposition.max_days_per_issue` | `3` |
| `decomposition.min_issues` | `2` |
| `decomposition.max_issues` | `20` |
| `assignees.default` | (なし) |
| `milestone` | (なし) |
| `project` | (なし) |

## 設定例

### 最小構成（デフォルトラベルのみ変更）

```yaml
labels:
  defaults:
    priority: "priority:P1"
```

### フロントエンドプロジェクト向け

```yaml
title_formats:
  feature: "[Feature] {component}: {summary}"

labels:
  custom:
    - name: "team:frontend"
      auto_apply: true

area_keywords:
  frontend:
    - "component"
    - "hook"
    - "page"
    - "React"
    - "Next.js"
    - "CSS"
    - "Tailwind"

assignees:
  default: "frontend-lead"
```

### 複数チーム向け

```yaml
labels:
  custom:
    - name: "sprint:2026-Q1"
      auto_apply: true

assignees:
  by_area:
    frontend: "fe-team-lead"
    server: "be-team-lead"
    shared: "tech-lead"

milestone: "v2.0"
project: "Product Roadmap"
```
