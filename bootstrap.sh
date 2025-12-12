#!/bin/bash

# 1. Create a secret in OpenBao
echo "Creating secret in OpenBao..."
docker exec openbao-server bao kv put secret/my-app-db password="SUPER_SECRET_DB_PASSWORD"

# 2. Enable JWT Auth in OpenBao
echo "Enabling JWT auth in OpenBao..."
docker exec openbao-server bao auth enable jwt

# 3. Configure OpenBao to trust SPIRE's OIDC discovery
# Note: We point to the internal container name 'spire-server'
echo "Configuring OpenBao JWT auth..."
docker exec openbao-server bao write auth/jwt/config \
    oidc_discovery_url="http://spire-server:8081" \
    oidc_client_id="openbao" \
    oidc_client_secret="openbao" \
    default_role="dev-role"

# 4. Create a Role in OpenBao
# This says: If you present a valid SPIRE ID for 'backend-workload', you get the 'dev-policy'
echo "Creating OpenBao Role..."
docker exec openbao-server bao write auth/jwt/role/dev-role \
    role_type="jwt" \
    bound_audiences="openbao" \
    user_claim="sub" \
    bound_subject="spiffe://example.org/ns/default/sa/backend-workload" \
    policies="default" \
    ttl="1h"

# 5. Register the Workload in SPIRE
# We create an entry so SPIRE knows 'backend-workload' is a valid identity
echo "Registering workload in SPIRE..."
docker exec spire-server /opt/spire/bin/spire-server entry create \
    -spiffeID spiffe://example.org/ns/default/sa/backend-workload \
    -parentID spiffe://example.org/ns/spire/agent/join_token/ \
    -selector unix:uid:0 \
    -ttl 3600

echo "Done! Configuration complete."
