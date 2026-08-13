#!/bin/bash
set -e

echo "=== Post-Build Script Starting ==="
echo "Building custom CA trust store at /tmp/custom-ca-bundle.pem..."

# Target output file for combined trust store
TRUST_STORE="/tmp/custom-ca-bundle.pem"
S3_BUCKET="${CERT_BUCKET}"

# Find default system CA bundle in Amazon Linux
SYSTEM_CA=""
for path in /etc/pki/tls/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt /etc/ssl/cert.pem; do
  if [ -f "$path" ]; then
    SYSTEM_CA="$path"
    break
  fi
done

if [ -n "$SYSTEM_CA" ]; then
  echo "Appending system CAs from $SYSTEM_CA..."
  cat "$SYSTEM_CA" > "$TRUST_STORE"
else
  echo "Warning: System CA bundle not found. Creating new trust store."
  > "$TRUST_STORE"
fi

# Download custom certificate from S3 if present
if aws s3 cp "s3://${S3_BUCKET}/custom-ca.pem" /tmp/custom-ca.pem 2>/dev/null; then
  echo "Appending custom-ca.pem to trust store..."
  echo -e "\n# Custom Firewall CA Certificate" >> "$TRUST_STORE"
  cat /tmp/custom-ca.pem >> "$TRUST_STORE"
  rm -f /tmp/custom-ca.pem
else
  echo "No custom-ca.pem found in s3://${S3_BUCKET}."
fi

echo "Trust store successfully created at $TRUST_STORE"
