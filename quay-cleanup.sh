#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] REPO [REPO...]

Delete image tags from container registries using skopeo.

Options:
  --all         Delete all tags from the specified repos
  --tags LIST   Comma-separated list of tags to delete
  --dry-run     Show what would be deleted without deleting
  -h, --help    Show this help

Examples:
  $(basename "$0") --all quay.io/hbelmiro/dsp-api-server
  $(basename "$0") --tags 123,456 quay.io/hbelmiro/dsp-api-server quay.io/hbelmiro/dsp-driver
  $(basename "$0") --all --dry-run quay.io/hbelmiro/dsp-api-server
EOF
  exit "${1:-0}"
}

delete_all=false
dry_run=false
tags=()
repos=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)      delete_all=true; shift ;;
    --tags)     IFS=',' read -ra tags <<< "$2"; shift 2 ;;
    --dry-run)  dry_run=true; shift ;;
    -h|--help)  usage 0 ;;
    -*)         echo "Unknown option: $1" >&2; usage 1 ;;
    *)          repos+=("$1"); shift ;;
  esac
done

if [[ ${#repos[@]} -eq 0 ]]; then
  echo "Error: at least one REPO is required" >&2
  usage 1
fi

if [[ "$delete_all" == false && ${#tags[@]} -eq 0 ]]; then
  echo "Error: specify --all or --tags" >&2
  usage 1
fi

if ! command -v skopeo &>/dev/null; then
  echo "Error: skopeo is required but not found in PATH" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not found in PATH" >&2
  exit 1
fi

failed=0

for repo in "${repos[@]}"; do
  echo "=== ${repo} ==="

  if [[ "$delete_all" == true ]]; then
    tags=()
    while IFS= read -r t; do
      tags+=("$t")
    done < <(skopeo list-tags "docker://${repo}" 2>/dev/null | jq -r '.Tags[]' 2>/dev/null)
    if [[ ${#tags[@]} -eq 0 ]]; then
      echo "  No tags found"
      continue
    fi
  fi

  for tag in "${tags[@]}"; do
    [[ -z "$tag" ]] && continue
    if [[ "$dry_run" == true ]]; then
      echo "  [dry-run] would delete :${tag}"
    else
      if skopeo delete "docker://${repo}:${tag}" 2>/dev/null; then
        echo "  Deleted :${tag}"
      else
        echo "  FAILED  :${tag}" >&2
        ((failed++))
      fi
    fi
  done
done

if [[ $failed -gt 0 ]]; then
  echo "${failed} deletion(s) failed" >&2
  exit 1
fi
