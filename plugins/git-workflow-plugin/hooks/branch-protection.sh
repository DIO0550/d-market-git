#!/bin/bash

# Claude Code pre-hook script for branch protection
# このスクリプトはPreToolUseイベントで編集系ツールの実行前に現在のブランチをチェックします

# 保護されたブランチのリスト（ここを編集してブランチを追加・削除）
PROTECTED_BRANCHES=(
    "main"
    "master"
    "production"
    "release"
    "develop"
    "staging"
)

# 標準入力からJSONを読み込む
json_input=$(cat)

# jqを使用してツール名を抽出
tool_name=$(echo "$json_input" | jq -r '.tool_name')

# 編集系ツールのリスト
WRITE_TOOLS=("Write" "Edit" "MultiEdit")

# 現在のツールが編集系かチェック
is_write_tool=false
for tool in "${WRITE_TOOLS[@]}"; do
    if [[ "$tool_name" == "$tool" ]]; then
        is_write_tool=true
        break
    fi
done

# 編集系ツールでない場合は正常終了
if [[ "$is_write_tool" == false ]]; then
    exit 0
fi

# 現在のGitブランチを取得
get_current_branch() {
    # .gitディレクトリが存在するか確認
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        return 1
    fi
    
    # 現在のブランチ名を取得
    local branch=$(git branch --show-current 2>/dev/null)
    
    # detached HEAD状態の場合
    if [ -z "$branch" ]; then
        branch=$(git describe --contains --all HEAD 2>/dev/null)
    fi
    
    echo "$branch"
}

# 現在のブランチを取得
current_branch=$(get_current_branch)

# Gitリポジトリでない場合は何もしない
if [ -z "$current_branch" ]; then
    exit 0
fi

# 保護されたブランチかチェック
is_protected=false
for protected_branch in "${PROTECTED_BRANCHES[@]}"; do
    if [[ "$current_branch" == "$protected_branch" ]]; then
        is_protected=true
        break
    fi
done

# 保護されたブランチの場合はブロック
if [[ "$is_protected" == true ]]; then
    # 保護されたブランチのリストを作成
    protected_list=$(IFS=', '; echo "${PROTECTED_BRANCHES[*]}")
    
    # JSON形式でブロックメッセージを出力
    jq -n --arg branch "$current_branch" --arg branches "$protected_list" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: ("保護されたブランチ\u0027" + $branch + "\u0027での編集は禁止されています。\n\n実装ルール:\n- 保護されたブランチ（" + $branches + "）への直接的な変更は禁止です\n- 機能開発や修正は必ず別ブランチで行ってください\n- 作業完了後、プルリクエスト経由でマージしてください\n\n推奨手順:\n1. 新しいブランチを作成: git checkout -b feature/your-feature-name\n2. 変更を実装\n3. プルリクエストを作成してレビューを受ける")
        }
    }'
    exit 0
fi

# 保護されたブランチでない場合は正常終了
exit 0