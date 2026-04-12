#!/bin/bash

# Claude Code pre-hook script for allowing plugin-related commands
# このスクリプトはPreToolUseイベントでBashツールの実行前にコマンドをチェックし、
# プラグイン関連コマンド（gh/git）を許可しつつ、複合コマンドをブロックします
#
# ルール:
# - gh/git コマンド: 許可（permissionDecision: allow）
# - 複合コマンド（&&, ||, ;）: 拒否（permissionDecision: deny）
# - パイプ（|）: gh は許可、git は拒否
# - その他のコマンド: 出力なし（通常の権限フローに委ねる）

# 標準入力からJSONを読み込む
json_input=$(cat)

# jqを使用してコマンドを抽出
command=$(echo "$json_input" | jq -r '.tool_input.command // empty')

# コマンドが空の場合は正常終了
if [ -z "$command" ]; then
    exit 0
fi

# gh/git コマンドか判定
is_gh=false
is_git=false
if echo "$command" | grep -qE '^\s*gh\s'; then
    is_gh=true
elif echo "$command" | grep -qE '^\s*git\s'; then
    is_git=true
fi

# プラグイン無関係なコマンドは無視（出力なし→通常の権限フローに委ねる）
if [ "$is_gh" = false ] && [ "$is_git" = false ]; then
    exit 0
fi

# 共通: &&, ||, ; をブロック
# heredoc（<<）のコンテンツ部分のみを除去し、コマンド構造はすべてチェックする
check_target="$command"
if echo "$command" | grep -qE '<<'; then
    # heredocデリミタを抽出（<<'EOF', <<"EOF", <<EOF, <<-EOF 等に対応）
    delim=$(echo "$command" | sed -n "s/.*<<-*[[:space:]]*['\"\`]*\([A-Za-z_][A-Za-z_0-9]*\)['\"\`]*.*/\1/p" | head -1)
    if [ -n "$delim" ]; then
        # heredocコンテンツ行（開始行の次〜デリミタ行）を除去、コマンド構造行は保持
        check_target=$(echo "$command" | awk -v d="$delim" '
            /<</ && !skip { skip=1; print; next }
            skip && $0 ~ "^[[:space:]]*"d"[[:space:]]*$" { skip=0; next }
            !skip { print }
        ')
    fi
fi
# 改行による複数コマンド分離もブロック（heredocコンテンツ除去後）
num_cmd_lines=$(echo "$check_target" | grep -cE '^\s*[a-zA-Z/\.]')
if [ "$num_cmd_lines" -gt 1 ]; then
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "改行による複数コマンドの実行は禁止されています。1コマンドずつ実行してください。"
        }
    }'
    exit 0
fi
if echo "$check_target" | grep -qE '&&|\|\||;'; then
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "コマンドの複合化（&&, ||, ;）は禁止されています。1コマンドずつ実行してください。"
        }
    }'
    exit 0
fi

# git のみ: パイプもブロック（heredoc部分を除外してチェック）
if [ "$is_git" = true ] && echo "$check_target" | grep -qE '\|'; then
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "git コマンドでのパイプ（|）は禁止されています。1コマンドずつ実行してください。"
        }
    }'
    exit 0
fi

# プラグイン関連コマンドを許可
jq -n '{
    hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "allow",
        permissionDecisionReason: "プラグイン関連コマンド（gh/git）を許可"
    }
}'
exit 0
