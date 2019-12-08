#!/bin/sh

# Decrypt the file
mkdir $HOME/secrets
# --batch to prevent interactive command --yes to assume "yes" for questions
gpg --quiet --batch --yes --decrypt --passphrase="$GPG_KEY_FOR_DB_WALLET_ENCRYPTION" --output Wallet_PANORAMATEST.zip Wallet_PANORAMATEST.zip.gpg
