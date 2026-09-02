# 앱 config 용 Vault secret 을 terraform 으로 "메타만" 추적하는 패턴.
#
# 값(secret_content)은 운영자가 CLI 로 관리하고 terraform 은 존재·이름만 본다 —
# plan 이 값 변경을 드리프트로 오인하지 않고, 값이 state 파일에 남지도 않는다.
resource "oci_vault_secret" "app_config" {
  for_each = toset(["example-app", "another-app"])

  compartment_id = var.compartment_id
  vault_id       = var.vault_id
  key_id         = var.master_key_id
  secret_name    = "${each.key}-config"
  description    = "${each.key} runtime config — ESO to ${each.key}-env. Managed by CLI; terraform tracks metadata only."

  secret_content {
    content_type = "BASE64"
    content      = base64encode("{}") # placeholder — 실값은 CLI 로
  }

  lifecycle {
    # defined_tags: 클라우드가 자동 부착하는 태그(CreatedBy 등)의 plan 노이즈 차단
    ignore_changes = [secret_content, defined_tags]
  }
}
