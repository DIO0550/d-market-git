#!/usr/bin/env bash
# monitor-pr.sh <owner> <repo> <pr>
#
# env:
#   WATCH_REVIEWERS  カンマ区切りのログイン名トークン（例: "copilot,alice"）
#                    大文字小文字無視・部分一致（"copilot" は "Copilot" にも
#                    "copilot-pull-request-reviewer" にもマッチする）
#                    未指定時は "copilot"
#   WATCH_CI         CI監視の有効/無効（"true" / "false"）未指定時は "true"
#   POLL_INTERVAL    ポーリング間隔（秒）未指定時は 60
#   REVIEW_LOOP      true の場合 REVIEW_UNRESOLVED を終了条件にしない（"true" / "false"）未指定時は "false"
#   CI_LOOP          true の場合 CI_FAILED を終了条件にしない（"true" / "false"）未指定時は "false"
#
# 出力（行頭タグ）:
#   CI_PENDING       checks_in_progress=<name,...>
#   CI_PASSED
#   CI_FAILED        failed_checks=<name,...> details=<url,...>
#   REVIEW_PENDING   reason=<text>
#   REVIEW_UNRESOLVED count=<n> locations=<path:line,...>
#   REVIEW_DONE      submitted=<iso8601> all_resolved=true

set -eu
set -o pipefail

if [ $# -lt 3 ]; then
  echo "usage: $0 <owner> <repo> <pr>" >&2
  exit 2
fi

OWNER=$1
REPO=$2
PR=$3

WATCH_REVIEWERS=${WATCH_REVIEWERS:-copilot}
WATCH_CI=${WATCH_CI:-true}
POLL_INTERVAL=${POLL_INTERVAL:-60}
REVIEW_LOOP=${REVIEW_LOOP:-false}
CI_LOOP=${CI_LOOP:-false}

ci_terminal=false
review_terminal=false
ci_empty_count=0
CI_EMPTY_GRACE=3
last_ci_tag=""
last_review_tag=""

# CI監視が無効なら即完了
if [ "$WATCH_CI" = "false" ]; then
  printf 'CI_PASSED\n'
  ci_terminal=true
fi

# レビュアートークンをJSON配列に変換
reviewers_json=$(printf '%s' "$WATCH_REVIEWERS" \
  | awk 'BEGIN{RS=","; ORS="\n"} {gsub(/^[ \t]+|[ \t]+$/, ""); if (length) print}' \
  | jq -R . | jq -s .)

while true; do
  # --- CI チェック ---
  if [ "$WATCH_CI" = "true" ]; then
    ci_line=$(gh pr checks "$PR" -R "${OWNER}/${REPO}" \
      --json name,state,conclusion,detailsUrl 2>/dev/null \
      | jq -r --argjson empty_count "$ci_empty_count" --argjson grace "$CI_EMPTY_GRACE" '
        if length == 0 then
          if $empty_count >= ($grace - 1) then
            "CI_PASSED"
          else
            "CI_PENDING checks_in_progress=waiting_for_checks"
          end
        elif any(.[]; .state == "QUEUED" or .state == "IN_PROGRESS" or .state == "PENDING") then
          "CI_PENDING checks_in_progress=" +
          ([.[] | select(.state == "QUEUED" or .state == "IN_PROGRESS" or .state == "PENDING") | .name] | join(","))
        elif all(.[]; .conclusion == "SUCCESS" or .conclusion == "NEUTRAL" or .conclusion == "SKIPPED") then
          "CI_PASSED"
        else
          "CI_FAILED failed_checks=" +
          ([.[] | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" or .conclusion == "CANCELLED" or .conclusion == "ACTION_REQUIRED") | .name] | join(",")) +
          " details=" +
          ([.[] | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT" or .conclusion == "CANCELLED" or .conclusion == "ACTION_REQUIRED") | .detailsUrl // ""] | map(select(. != "")) | join(","))
        end
      ')

    # チェック0件のカウント
    check_count=$(gh pr checks "$PR" -R "${OWNER}/${REPO}" \
      --json name 2>/dev/null | jq 'length')
    if [ "$check_count" = "0" ]; then
      ci_empty_count=$((ci_empty_count + 1))
    else
      ci_empty_count=0
    fi

    # タグ部分を抽出（最初のスペースより前）
    ci_tag=${ci_line%% *}

    # 状態変化時のみ出力（de-duplication）
    if [ "$ci_tag" != "$last_ci_tag" ]; then
      printf '%s\n' "$ci_line"
      last_ci_tag=$ci_tag
    fi

    case "$ci_tag" in
      CI_PASSED)
        ci_terminal=true
        ;;
      CI_FAILED)
        if [ "$CI_LOOP" = "true" ]; then
          ci_terminal=false
        else
          ci_terminal=true
        fi
        ;;
      CI_PENDING)
        # terminal → pending 遷移時のみグレースカウンタをリセット（push後の新CI検知）
        if [ "$ci_terminal" = "true" ]; then
          ci_empty_count=0
        fi
        ci_terminal=false
        ;;
    esac
  fi

  # --- レビューチェック ---
  payload=$(gh api graphql \
    -f query='
      query($owner:String!, $repo:String!, $pr:Int!) {
        repository(owner:$owner, name:$repo) {
          pullRequest(number:$pr) {
            reviewRequests(last:20) {
              nodes {
                requestedReviewer {
                  ... on User { login }
                  ... on Bot { login }
                }
              }
            }
            reviews(last:20) {
              nodes { author { login } state submittedAt }
            }
            reviewThreads(last:100) {
              nodes {
                isResolved
                isOutdated
                comments(first:1) {
                  nodes { author { login } path line body }
                }
              }
            }
          }
        }
      }' \
    -f owner="$OWNER" -f repo="$REPO" -F pr="$PR")

  review_line=$(printf '%s' "$payload" | jq -r --argjson tokens "$reviewers_json" '
    def match_any($login):
      ($tokens // []) as $ts
      | any($ts[]; . as $t | ($login // "") | ascii_downcase | contains($t | ascii_downcase));

    .data.repository.pullRequest as $pr
    # レビューリクエストが残っているか（依頼中でまだ未提出）
    | ($pr.reviewRequests.nodes
        | map(select(match_any(.requestedReviewer.login)))
        | length > 0) as $has_pending_request
    | ($pr.reviews.nodes
        | map(select(match_any(.author.login)))
        | sort_by(.submittedAt)
        | last) as $cr
    | ($pr.reviewThreads.nodes
        | map(select(
            match_any(.comments.nodes[0].author.login)
            and (.isResolved == false)
            and (.isOutdated == false)
          ))) as $unresolved
    | if $has_pending_request then
        "REVIEW_PENDING reason=review-requested"
      elif $cr == null then
        "REVIEW_PENDING reason=no-review-yet"
      elif $cr.state == "PENDING" then
        "REVIEW_PENDING reason=review-in-progress"
      elif ($unresolved | length) > 0 then
        "REVIEW_UNRESOLVED count=\($unresolved | length) locations=" +
        ($unresolved | map("\(.comments.nodes[0].path):\(.comments.nodes[0].line // 0)") | join(","))
      else
        "REVIEW_DONE submitted=\($cr.submittedAt) all_resolved=true"
      end
  ')

  # タグ部分を抽出（最初のスペースより前）
  review_tag=${review_line%% *}

  # 状態変化時のみ出力（de-duplication）
  if [ "$review_tag" != "$last_review_tag" ]; then
    printf '%s\n' "$review_line"
    last_review_tag=$review_tag
  fi

  case "$review_tag" in
    REVIEW_DONE)
      review_terminal=true
      ;;
    REVIEW_UNRESOLVED)
      if [ "$REVIEW_LOOP" = "true" ]; then
        review_terminal=false
      else
        review_terminal=true
      fi
      ;;
    REVIEW_PENDING)
      review_terminal=false
      ;;
  esac

  # --- 両方完了なら終了 ---
  if [ "$ci_terminal" = "true" ] && [ "$review_terminal" = "true" ]; then
    exit 0
  fi

  sleep "$POLL_INTERVAL"
done
