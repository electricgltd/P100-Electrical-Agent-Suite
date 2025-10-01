#!/usr/bin/env bash
set -e

echo "🔍 Verifying GitHub Secrets and Power Platform Authentication..."

# Required secrets
REQUIRED_SECRETS=("PP_TENANT_ID" "PP_CLIENT_ID" "PP_CLIENT_SECRET" "PP_ENV_DEV_URL")

echo "✅ Checking environment variables..."
for secret in "${REQUIRED_SECRETS[@]}"; do
  if [ -z "${!secret}" ]; then
    echo "🛑 Missing secret: $secret"
    exit 1
  else
    echo "✅ Found: $secret"
  fi
done

echo "✅ Installing Power Platform CLI..."
npm install -g pac

echo "✅ Authenticating with Power Platform..."
pac auth create --tenant "$PP_TENANT_ID" \
                --applicationId "$PP_CLIENT_ID" \
                --clientSecret "$PP_CLIENT_SECRET" \
                --environment "$PP_ENV_DEV_URL"

echo "✅ Listing current auth profiles..."
pac auth list

echo "✅ Fetching environment details..."
pac org who

echo "🎉 Verification complete! Secrets and authentication are working."
