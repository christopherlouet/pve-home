{
  "root": "/home/step/certs/root_ca.crt",
  "federatedRoots": null,
  "crt": "/home/step/certs/intermediate_ca.crt",
  "key": "/home/step/secrets/intermediate_ca_key",
  "address": "${address}",
  "insecureAddress": "",
  "dnsNames": ${jsonencode(dns_names)},
  "logger": {
    "format": "json"
  },
  "db": {
    "type": "badgerv2",
    "dataSource": "/home/step/db",
    "badgerFileLoadingMode": ""
  },
  "authority": {
    "provisioners": [
      {
        "type": "${provisioner_type}",
        "name": "${provisioner_name}",
        "forceCN": true,
        "claims": {
          "maxTLSCertDuration": "${cert_duration}",
          "defaultTLSCertDuration": "24h"
        }
      },
      {
        "type": "JWK",
        "name": "admin",
        "encryptedKey": "$${STEP_CA_ENCRYPTED_KEY}",
        "claims": {
          "maxTLSCertDuration": "8760h",
          "defaultTLSCertDuration": "24h"
        }
      }
    ],
    "template": {},
    "backdate": "1m0s"
  },
  "tls": {
    "cipherSuites": [
      "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
      "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
    ],
    "minVersion": 1.2,
    "maxVersion": 1.3,
    "renegotiation": false
  },
  "commonName": "${ca_name}"
}
