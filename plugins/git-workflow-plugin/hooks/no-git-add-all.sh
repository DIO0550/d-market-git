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
# 対象: git add -A, git add --all, git add .
# git add -Aや--allは意図しないファイル(.env, credentials等)をステージングするリスクがある
if echo "$command" | grep -qE '(^|&&|;|\||\$\()\s*git\s+add\s+(-A|--all|\.)\b'; then
    cat <<'EOF'
{
    "decision": "block",
    "reason": "⛔ `git add -A` / `git add --all` / `git add .` の使用は禁止されています。\n\n📋 理由:\n- 一括ステージングは意図しないファイル（.env, credentials, 大容量バイナリ等）をコミットに含めるリスクがあります\n- セキュリティ上の問題やリポジトリの肥大化を防ぐため、ファイルは個別に指定してください\n\n💡 推奨手順:\n1. `git status` で変更ファイルを確認\n2. `git add <ファイル名>` で必要なファイルのみを個別にステージング\n3. 複数ファイルの場合: `git add file1.txt file2.txt` またはディレクトリ指定 `git add src/`"
}
EOF
    exit 0
fi

# 問題なければ正常終了
exit 0
