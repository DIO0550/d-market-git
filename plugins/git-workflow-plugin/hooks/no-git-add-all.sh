#!/bin/bash

# Claude Code pre-hook script for prohibiting `git add -A` / `git add .` / `git add --all`
# このスクリプトはPreToolUseイベントでBashツールの実行前にコマンドをチェックし、
# 全ファイルを一括ステージングする危険なgit addコマンドをブロックします

# 標準入力からJSONを読み込む
json_input=$(cat)

# jqを使用してコマンドを抽出
command=$(echo "$json_input" | jq -r '.tool_input.command // empty')

# コマンドが空の場合は正常終了
if [ -z "$command" ]; then
    exit 0
fi

# git add の危険なパターンをチェック
# 対象: git add -A, git add --all, git add ., git add -a
# git add -Aや--allは意図しないファイル(.env, credentials等)をステージングするリスクがある
# プレフィックスコマンド(command, env, sudo等)や-Aが先頭引数でないケース(-v -A等)にも対応
if echo "$command" | grep -qE '\bgit\s+add\b.*(\s-[a-zA-Z]*A[a-zA-Z]*\b|\s--all\b|\s\.\s|\s\.$)' \
   || echo "$command" | grep -qE '\bgit\s+add\s+(-A\b|--all\b|\.\s|\.$)' \
   || echo "$command" | grep -qE '\bgit\s+add\s+-a\b'; then
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: "`git add -A` / `git add --all` / `git add .` の使用は禁止されています。\n\n理由:\n- 一括ステージングは意図しないファイル（.env, credentials, 大容量バイナリ等）をコミットに含めるリスクがあります\n- セキュリティ上の問題やリポジトリの肥大化を防ぐため、ファイルは個別に指定してください\n\n推奨手順:\n1. `git status` で変更ファイルを確認\n2. `git add <ファイル名>` で必要なファイルのみを個別にステージング\n3. 複数ファイルの場合: `git add file1.txt file2.txt` またはディレクトリ指定 `git add src/`"
        }
    }'
    exit 0
fi

# 問題なければ正常終了
exit 0
