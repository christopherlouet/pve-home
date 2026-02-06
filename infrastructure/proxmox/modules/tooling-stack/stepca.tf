# =============================================================================
# Module Tooling Stack - Step-ca PKI
# =============================================================================
# Autorite de certification interne avec Step-ca.
# Genere le certificat racine CA et la configuration Step-ca.
# =============================================================================

# -----------------------------------------------------------------------------
# TLS Resources for Step-ca (Root CA)
# -----------------------------------------------------------------------------

resource "tls_private_key" "root_ca" {
  count       = var.step_ca_enabled ? 1 : 0
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "root_ca" {
  count           = var.step_ca_enabled ? 1 : 0
  private_key_pem = tls_private_key.root_ca[0].private_key_pem

  subject {
    common_name  = var.step_ca_root_cn
    organization = "Homelab"
  }

  validity_period_hours = 87600 # 10 years

  allowed_uses = [
    "cert_signing",
    "crl_signing",
    "digital_signature",
  ]

  is_ca_certificate = true
}

# -----------------------------------------------------------------------------
# Step-ca Configuration
# -----------------------------------------------------------------------------

locals {
  step_ca_config = var.step_ca_enabled ? {
    ca_name          = "Homelab CA"
    dns_names        = ["pki.${var.domain_suffix}", var.ip_address, "localhost", "127.0.0.1"]
    address          = "0.0.0.0:8443"
    provisioner_name = var.step_ca_provisioner_name
    provisioner_type = "ACME"
    cert_duration    = var.step_ca_cert_duration
    root_cn          = var.step_ca_root_cn
    root_key_type    = "EC"
    root_key_curve   = "P-384"
  } : null
}
