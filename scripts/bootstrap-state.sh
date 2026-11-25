#!/usr/bin/env bash
# Cree le compte de stockage qui portera l'etat Terraform, puis affiche le
# fichier backend.hcl a creer.
#
# C'est la SEULE etape manuelle autorisee par le cahier des charges : l'etat
# doit exister avant le premier `terraform init`, il ne peut donc pas etre cree
# par le code qu'il sert a stocker.
#
#   ./scripts/bootstrap-state.sh
#
# Le verrouillage est assure par un lease de blob natif au backend azurerm :
# deux `terraform apply` simultanes ne peuvent pas ecrire l'etat en meme temps.

set -euo pipefail

LOCATION="${LOCATION:-francecentral}"
RG="${RG:-rg-kaaru-tfstate}"
CONTAINER="${CONTAINER:-tfstate}"

if ! az account show >/dev/null 2>&1; then
  echo "Pas de session Azure. Lance 'az login' d'abord." >&2
  exit 1
fi

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
SUBSCRIPTION_NAME="$(az account show --query name -o tsv)"
echo "Abonnement : ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"

az group create --name "$RG" --location "$LOCATION" \
  --tags owner="Paul-Victor Delerue" project=kaaru environment=prod >/dev/null
echo "Resource group pret : ${RG}"

# Nom de compte unique au monde : suffixe aleatoire court.
SA="${SA:-stkaarutf$(openssl rand -hex 3)}"

az storage account create \
  --name "$SA" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags owner="Paul-Victor Delerue" project=kaaru environment=prod >/dev/null
echo "Compte d'etat pret : ${SA}"

az storage container create --name "$CONTAINER" --account-name "$SA" --auth-mode login >/dev/null
echo "Conteneur pret : ${CONTAINER}"

cat > envs/prod/backend.hcl <<EOF
resource_group_name  = "${RG}"
storage_account_name = "${SA}"
container_name       = "${CONTAINER}"
key                  = "prod.terraform.tfstate"
use_azuread_auth     = true
EOF

echo
echo "backend.hcl ecrit dans envs/prod/ :"
cat envs/prod/backend.hcl
echo
echo "Etape suivante :"
echo "  cd envs/prod && terraform init -backend-config=backend.hcl"
