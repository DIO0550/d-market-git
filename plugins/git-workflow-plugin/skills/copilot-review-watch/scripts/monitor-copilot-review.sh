#!/usr/bin/env bash
# monitor-copilot-review.sh <owner> <repo> <pr>
#
# env:
#   WATCH_REVIEWERS  カンマ区切りのログイン名トークン（例: "copilot,alice"）
#                    大文字小文字無視・部分一致（"copilot" は "Copilot" にも
#                    "copilot-pull-request-reviewer" にもマッチする）
#                    未指定時は "copilot"
#   POLL_INTERVAL    ポーリング間隔（秒）未指定時は 30
#
# 出力（行頭タグ）:
#   COPILOT_PENDING    reason=<text>
#   COPILOT_UNRESOLVED count=<n> locations=<path:line,...>
#   COPILOT_DONE       submitted=<iso8601> all_resolved=true

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
POLL_INTERVAL=${POLL_INTERVAL:-30}

reviewers_json=$(printf '%s' "$WATCH_REVIEWERS" \
  | awk 'BEGIN{RS=","; ORS="\n"} {gsub(/^[ \t]+|[ \t]+$/, ""); if (length) print}' \
  | jq -R . | jq -s .)

while true; do
  payload=$(gh api graphql \
    -f query='
      query($owner:String!, $repo:String!, $pr:Int!) {
        repository(owner:$owner, name:$repo) {
          pullRequest(number:$pr) {
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

  line=$(printf '%s' "$payload" | jq -r --argjson tokens "$reviewers_json" '
    def match_any($login):
      ($tokens // []) as $ts
      | any($ts[]; . as $t | ($login // "") | ascii_downcase | contains($t | ascii_downcase));

    .data.repository.pullRequest as $pr
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
    | if $cr == null then
        "COPILOT_PENDING reason=no-review-yet"
      elif ($unresolved | length) > 0 then
        "COPILOT_UNRESOLVED count=\($unresolved | length) locations=" +
        ($unresolved | map("\(.comments.nodes[0].path):\(.comments.nodes[0].line // 0)") | join(","))
      else
        "COPILOT_DONE submitted=\($cr.submittedAt) all_resolved=true"
      end
  ')

  printf '%s\n' "$line"

  case "$line" in
    COPILOT_DONE*|COPILOT_UNRESOLVED*)
      exit 0
      ;;
  esac

  sleep "$POLL_INTERVAL"
done
