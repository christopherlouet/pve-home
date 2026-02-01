# =============================================================================
# Backend S3 Minio - Monitoring
# =============================================================================
# Decommenter apres deploiement du module Minio sur le PVE monitoring.
# Migration : terraform init -migrate-state
#
# Variables d'environnement requises :
#   export AWS_ACCESS_KEY_ID="minioadmin"
#   export AWS_SECRET_ACCESS_KEY="<votre-mot-de-passe-minio>"
# =============================================================================

# terraform {
#   backend "s3" {
#     bucket = "tfstate-monitoring"
#     key    = "terraform.tfstate"
#     region = "us-east-1"
#
#     # Configuration Minio (adapter l'IP)
#     endpoints = {
#       s3 = "http://192.168.1.52:9000"
#     }
#     skip_credentials_validation = true
#     skip_metadata_api_check     = true
#     skip_requesting_account_id  = true
#     use_path_style              = true
#   }
# }
