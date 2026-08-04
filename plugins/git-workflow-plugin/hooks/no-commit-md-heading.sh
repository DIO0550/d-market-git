#!/bin/bash

# Claude Code pre-hook script for prohibiting Markdown headings in commit message bodies
# このスクリプトはPreToolUseイベントでBashツールの実行前にコミットメッセージを検査し、
# 行頭（桁0）の '#' で始まる見出し行をブロックします。
#
# 理由: git は core.commentChar（既定 '#'）で始まる行をコメントとして除去します。
# `git commit -m` の時点では除去されませんが、その後 `git commit --amend` や
# `git rebase --reword` をエディタ経由で行った時点で本文が黙って欠落します。
# 意思決定の記録をコミット本文に蓄積する運用では、この欠落は記録の喪失そのものです。

# 標準入力からJSONを読み込む
json_input=$(cat)

# jqを使用してコマンドを抽出
command=$(echo "$json_input" | jq -r '.tool_input.command // empty')

# コマンドが空の場合は正常終了
if [ -z "$command" ]; then
    exit 0
fi

# git commit 以外は対象外
if ! printf '%s' "$command" | grep -qE '\bgit[[:space:]]+commit\b'; then
    exit 0
fi

# heredoc の本文を取り出す（no-git-add-all.sh の除去処理と逆の操作）
# commit スキルはコミットメッセージを heredoc で渡す規約のため、本文はここに現れる
delim=$(printf '%s' "$command" | sed -n "s/.*<<-*[[:space:]]*['\"\`]*\([A-Za-z_][A-Za-z_0-9]*\)['\"\`]*.*/\1/p" | head -1)

if [ -n "$delim" ]; then
    body=$(printf '%s\n' "$command" | awk -v d="$delim" '
        !inside && /<</ { inside=1; next }
        inside && $0 ~ "^[[:space:]]*"d"[[:space:]]*$" { inside=0; next }
        inside { print }
    ')
else
    # heredoc でない場合は -m の引数を素朴に対象とする（複数行文字列のケース）
    body="$command"
fi

# 行頭（桁0）の '#' を検出する
# git が除去するのは桁0の '#' のみ。インデントされた '#' は除去されないため対象外
offending=$(printf '%s\n' "$body" | grep -n '^#' | head -3)

if [ -n "$offending" ]; then
    jq -n --arg lines "$offending" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: ("コミットメッセージ本文に行頭 `#` の Markdown 見出しが含まれています。\n\n検出された行:\n" + $lines + "\n\n理由:\n- git は core.commentChar（既定 `#`）で始まる行をコメントとして除去します\n- `git commit -m` の時点では残りますが、後で `git commit --amend` や `git rebase --reword` をエディタ経由で行うと、その時点で該当行が黙って消えます\n- 意思決定をコミット本文に残す運用では、この欠落は記録の喪失になります\n\n対処:\n- 見出しは `<見出し>:` を単独行に置いてください（例: `背景:` `採用理由:`）\n- 見出し文字列は commit テンプレートの `decision_record.sections[].title` に揃えてください\n- どうしても行頭 `#` が必要な場合は、その行を1文字以上インデントしてください（桁0でなければ除去されません）")
        }
    }'
    exit 0
fi

# 問題なければ正常終了
exit 0
