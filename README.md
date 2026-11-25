# kaaru-infra

Infrastructure Azure du projet **Kaaru** (QR codes dynamiques), en Terraform.

Le rapport complet est dans [`docs/rapport.md`](docs/rapport.md), l'architecture
détaillée dans [`docs/architecture.md`](docs/architecture.md).

## Ce que crée ce depot

| Module | Ressources |
| --- | --- |
| `network` | VNet `10.42.0.0/16`, `snet-apps` (délégué Container Apps), `snet-data` (points de terminaison privés), deux NSG |
| `storage` | Compte de stockage sans clé partagée, conteneurs `logos`/`exports`, tables `links`/`scanstats`, file `scan-events`, purge à 30 jours |
| `security` | Deux identités managées, RBAC séparé par service, Key Vault en RBAC |
| `compute` | ACR Basic, environnement Container Apps, Container App `api` (0→3), job `stats` toutes les 2 min |
| `observability` | Log Analytics 30 jours, Application Insights |
| `alerting` | 3 alertes métriques, budget à 3 seuils, tableau de bord |
| `governance` | Stratégie `deny` sur les tags obligatoires (owner, project, environment) |

## Prérequis

- `terraform >= 1.6`, `az` CLI authentifié (`az login`)
- Un abonnement Azure for Students
- Un nom de compte de stockage unique pour l'état distant

## Déploiement

```bash
git clone https://github.com/zeekFPS/kaaru-infra && cd kaaru-infra

# 1. Etat distant (une seule etape manuelle : l'etat doit exister avant le code)
./scripts/bootstrap-state.sh

# 2. Configuration
cd envs/prod
cp prod.tfvars.example prod.tfvars   # renseigner alert_email et unique_suffix

# 3. Provisionnement
terraform init -backend-config=backend.hcl
terraform apply -var-file=prod.tfvars

# 4. Image applicative
cd ../../../kaaru-api
az acr build --registry "$(terraform -chdir=../kaaru-infra/envs/prod output -raw acr_name)" \
             --image kaaru-api:1.0.0 .

# 5. Bascule sur la vraie image
cd ../kaaru-infra/envs/prod
# prod.tfvars : container_image = "<acr>.azurecr.io/kaaru-api:1.0.0"
terraform apply -var-file=prod.tfvars
```

`PUBLIC_BASE_URL` peut rester vide : l'API déduit son adresse publique de l'hôte
de la requête, ce qui évite un cycle Terraform (le FQDN du Container App n'existe
qu'après sa création).

## Vérifications hors ligne

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

C'est exactement ce que fait le pipeline `.github/workflows/ci.yml`, sans
credentials Azure.

## Destruction

```bash
terraform destroy -var-file=prod.tfvars
az group delete --name rg-kaaru-tfstate --yes   # apres destruction de l'etat
```

## Conventions

- Un module par domaine Azure, appelés depuis `envs/prod`.
- Tout est tagué `owner`, `project`, `environment`.
- Aucun secret dans le dépôt : pas de clé de stockage, pas de mot de passe de
  registre, pas de chaîne de connexion. `.gitignore` couvre `backend.hcl`,
  `*.tfstate` et `prod.tfvars`.
