# shellcheck shell=bash
# Shared helpers for pbx3-directory registrar scripts (Phase 3).

set -euo pipefail

REGISTRAR_CATALOG_KEY="${REGISTRAR_CATALOG_KEY:-catalog/instance-index.json}"

registrar_require_cmd() {
  local cmd
  for cmd in aws jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "registrar: required command not found: $cmd" >&2
      exit 1
    fi
  done
}

registrar_bucket() {
  if [[ -z "${PBX3_ORG_BUCKET:-}" ]]; then
    echo "registrar: set PBX3_ORG_BUCKET (e.g. export PBX3_ORG_BUCKET=08jzwn-pbx3)" >&2
    exit 1
  fi
  printf '%s' "$PBX3_ORG_BUCKET"
}

registrar_now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

registrar_s3_cp() {
  local src=$1 dest=$2
  shift 2
  if [[ "${REGISTRAR_DRY_RUN:-0}" == "1" ]]; then
    echo "DRY-RUN: aws s3 cp $src s3://$(registrar_bucket)/$dest $*" >&2
    return 0
  fi
  local -a cmd=(aws s3 cp)
  [[ -n "${AWS_PROFILE:-}" ]] && cmd+=(--profile "$AWS_PROFILE")
  cmd+=("$src" "s3://$(registrar_bucket)/$dest" "$@")
  "${cmd[@]}"
}

registrar_s3_download() {
  local key=$1 dest=$2
  if [[ "${REGISTRAR_DRY_RUN:-0}" == "1" ]]; then
    echo "DRY-RUN: aws s3 cp s3://$(registrar_bucket)/$key $dest" >&2
    return 1
  fi
  local -a cmd=(aws s3 cp)
  [[ -n "${AWS_PROFILE:-}" ]] && cmd+=(--profile "$AWS_PROFILE")
  cmd+=("s3://$(registrar_bucket)/$key" "$dest")
  "${cmd[@]}" 2>/dev/null
}

registrar_fetch_catalog() {
  local dest=$1
  if registrar_s3_download "$REGISTRAR_CATALOG_KEY" "$dest"; then
    return 0
  fi
  jq -n --arg now "$(registrar_now_iso)" \
    '{version: 1, updated_at: $now, instances: []}' >"$dest"
}

registrar_publish_catalog() {
  local file=$1
  registrar_s3_cp "$file" "$REGISTRAR_CATALOG_KEY" --content-type application/json
}

registrar_upsert_catalog_instance() {
  local catalog_file=$1 record_file=$2
  local now
  now=$(registrar_now_iso)
  jq --slurpfile rec "$record_file" --arg now "$now" '
    .version = 1 |
    .updated_at = $now |
    if any(.instances[]?; .id == $rec[0].id) then
      .instances = [.instances[] | if .id == $rec[0].id then $rec[0] else . end]
    else
      .instances += [$rec[0]]
    end
  ' "$catalog_file" >"${catalog_file}.new"
  mv "${catalog_file}.new" "$catalog_file"
}

registrar_merge_instance_meta() {
  local record_file=$1 existing_meta=$2 out=$3
  local now created
  now=$(registrar_now_iso)
  created=$now
  if [[ -f "$existing_meta" ]]; then
    created=$(jq -r '.created_at // empty' "$existing_meta")
    [[ -z "$created" || "$created" == "null" ]] && created=$now
  fi
  jq --slurpfile rec "$record_file" --arg now "$now" --arg created "$created" '
    ($rec[0]) as $r |
    {
      id: $r.id,
      fqdn: $r.fqdn,
      api_base_url: $r.api_base_url,
      label: $r.label,
      status: $r.status,
      environment: ($r.environment // null),
      region: ($r.region // null),
      notes: ($r.notes // null),
      package_version: ($r.package_version // null),
      created_at: $created,
      updated_at: $now
    }
  ' "$record_file" >"${out}.tmp"
  if [[ -f "$existing_meta" ]]; then
    jq -s '
      .[0] as $new | .[1] as $old |
      $new
      + (if $old.backup_latest_stamp then {backup_latest_stamp: $old.backup_latest_stamp} else {} end)
      + (if $old.tenant_shortuids then {tenant_shortuids: $old.tenant_shortuids} else {} end)
    ' "${out}.tmp" "$existing_meta" | jq 'with_entries(select(.value != null))' >"$out"
  else
    jq 'with_entries(select(.value != null))' "${out}.tmp" >"$out"
  fi
  rm -f "${out}.tmp"
}
