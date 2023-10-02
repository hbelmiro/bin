#!/bin/bash

# Run kinit using credentials from Bitwarden

# Requirements:
# * Install the Bitwarden CLI - brew install bitwarden-cli
# * Add a note named "KINIT_USERNAME" to Bitwarden containing the username you use to run kinit. Ex.: kinit my_user@my_domain.com
# * Add a note named "KERBEROS_CREDENTIALS_NAME" to Bitwarden containing the name of the credentials where you store the kerberos password inside bitwarden

handle_error() {
  local error_message="$1"
  echo "Error: $error_message"
  exit 1
}

SESSION_KEY=$(bw unlock --raw) || handle_error "Failed to obtain Bitwarden session key"

KINIT_USERNAME=$(bw get notes "KINIT_USERNAME" --session "${SESSION_KEY}") || handle_error "Failed to obtain Kerberos username"
KERBEROS_CREDENTIALS_NAME=$(bw get notes "KERBEROS_CREDENTIALS_NAME" --session "${SESSION_KEY}") || handle_error "Failed to obtain Kerberos credentials name"
PASSWORD=$(bw get password "${KERBEROS_CREDENTIALS_NAME}" --session "${SESSION_KEY}") || handle_error "Failed to obtain Kerberos password"
kinit "${KINIT_USERNAME}" <<<"${PASSWORD}" || handle_error "Kerberos authentication failed"

echo "Kerberos authentication successful for user: $KINIT_USERNAME"

bw lock --session "$SESSION_KEY"