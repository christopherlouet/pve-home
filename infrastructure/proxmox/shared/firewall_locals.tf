# =============================================================================
# Shared Firewall Rule Presets
# =============================================================================
# Regles firewall communes reutilisees via symlinks dans les environnements.
# Utilisees avec des blocs "dynamic rule" dans les ressources firewall.
#
# SECURITY NOTE: Regles sans filtrage IP source - accepte pour reseau homelab
# isole. En production, ajouter "source" pour restreindre l'acces.
# =============================================================================

locals {
  # Regles de base communes a toutes les VMs (SSH, HTTP, HTTPS, Node Exporter, Ping)
  firewall_rules_base = [
    { proto = "tcp", dport = "22", comment = "SSH" },
    { proto = "tcp", dport = "80", comment = "HTTP" },
    { proto = "tcp", dport = "443", comment = "HTTPS" },
    { proto = "tcp", dport = "9100", comment = "Node Exporter" },
    { proto = "icmp", dport = null, comment = "Ping" },
  ]

  # Regles exporters pour VMs de production
  firewall_rules_prod_exporters = [
    { proto = "tcp", dport = "9080", comment = "cAdvisor" },
    { proto = "tcp", dport = "9113", comment = "Nginx Exporter" },
    { proto = "tcp", dport = "9115", comment = "Blackbox Exporter" },
    { proto = "tcp", dport = "9187", comment = "PostgreSQL Exporter" },
    { proto = "tcp", dport = "9256", comment = "Process Exporter" },
  ]
}
