{
  "_comment": "Harbor OIDC Configuration for Authentik - Add to Harbor via API or UI",
  "auth_mode": "oidc_auth",
  "oidc_name": "Authentik",
  "oidc_endpoint": "${authentik_url}/application/o/harbor/",
  "oidc_client_id": "harbor",
  "oidc_client_secret": "${harbor_client_secret}",
  "oidc_groups_claim": "groups",
  "oidc_admin_group": "Harbor Admins",
  "oidc_scope": "openid,profile,email,groups",
  "oidc_verify_cert": ${oidc_verify_cert},
  "oidc_auto_onboard": true,
  "oidc_user_claim": "preferred_username"
}
