#!/bin/sh
set -eu

# create-github-labels.sh
# spec-to-issues-plugin で使用する GitHub ラベルを一括作成/更新します。
# 依存: gh (GitHub CLI)
# 使い方:
#   bash plugins/spec-to-issues-plugin/scripts/create-github-labels.sh
# オプション:
#   DRY_RUN=1      変更を加えずに実行内容のみ表示
#   FORCE_UPDATE=1 既存ラベルに対して色/説明を上書き更新
#   REPO=...       対象リポジトリ（省略時はカレントの gh コンテキストから推定）

REPO=${REPO:-}
DRY_RUN=${DRY_RUN:-0}
FORCE_UPDATE=${FORCE_UPDATE:-0}

log() { printf '%s\n' "$*"; }
err() { printf 'Error: %s\n' "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "$1 が見つかりません。インストールしてください。"; exit 1; }
}

usage() {
  cat <<EOF
Usage:
  bash plugins/spec-to-issues-plugin/scripts/create-github-labels.sh

Env options:
  REPO=owner/repo   対象リポジトリ（未指定時は gh から推定）
  DRY_RUN=1         ドライラン（実行内容のみ表示）
  FORCE_UPDATE=1    既存ラベルにも color/description を上書き
EOF
}

# 前提チェック
require_cmd gh

# REPO が未指定なら gh から推定
if [ -z "${REPO}" ]; then
  if gh repo view >/dev/null 2>&1; then
    REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
  else
    err "REPO=owner/repo を指定するか、git/gh で対象リポジトリにいる必要があります。"
    usage
    exit 1
  fi
fi

log "Target repo: ${REPO}"

# 既存ラベルの取得（名前のみ）
EXISTING_NAMES=$(gh label list --repo "${REPO}" --limit 300 --json name --jq '.[].name' 2>/dev/null || true)

exists() {
  echo "${EXISTING_NAMES}" | grep -Fx "$1" >/dev/null 2>&1
}

apply_label() {
  NAME=$1
  COLOR=$2
  DESC=$3

  if exists "${NAME}"; then
    if [ "${FORCE_UPDATE}" = "1" ]; then
      if [ "${DRY_RUN}" = "1" ]; then
        log "[DRY] update ${NAME} color=${COLOR} desc='${DESC}'"
      else
        gh label edit "${NAME}" \
          --repo "${REPO}" \
          --color "${COLOR}" \
          --description "${DESC}" >/dev/null
        log "updated: ${NAME}"
      fi
    else
      log "skip (exists): ${NAME}"
    fi
  else
    if [ "${DRY_RUN}" = "1" ]; then
      log "[DRY] create ${NAME} color=${COLOR} desc='${DESC}'"
    else
      if gh label create "${NAME}" --repo "${REPO}" --color "${COLOR}" --description "${DESC}" --force >/dev/null 2>&1; then
        :
      else
        gh label create "${NAME}" --repo "${REPO}" --color "${COLOR}" --description "${DESC}" >/dev/null
      fi
      log "created: ${NAME}"
    fi
  fi
}

# ラベル定義（name,color,description）
# color は # を付けない 6 桁 HEX
cat <<'EOF_LABELS' | while IFS=, read -r NAME COLOR DESC; do
# 種別
type:epic,6B21A8,エピック/親Issue
type:feature,2563EB,新機能/機能追加
type:migration,D97706,マイグレーション/移行
type:chore,6B7280,雑務/設定
type:test,059669,テスト関連
type:docs,8B5CF6,ドキュメント関連

# 領域
area:frontend,EC4899,フロントエンド領域
area:server,F97316,バックエンド/サーバ領域
area:shared,14B8A6,共有/横断領域

# 優先度
priority:P1,DC2626,最優先（ブロッカー）
priority:P2,F59E0B,高優先度
priority:P3,6B7280,通常優先度

# 規模
size:S,86EFAC,小（1日以内）
size:M,FDE047,中（1-3日）
size:L,FCA5A5,大（3日以上）
EOF_LABELS
  # 空行/コメントをスキップ
  [ -z "${NAME}" ] && continue
  case "${NAME}" in
    \#*) continue;;
  esac
  apply_label "${NAME}" "${COLOR}" "${DESC}"
done

log "Done: labels processed for ${REPO}"
