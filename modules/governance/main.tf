# Gouvernance : les tags ne sont pas une convention, c'est une regle appliquee.
#
# La strategie refuse la creation de toute ressource du groupe de ressources qui
# ne porte pas les trois tags demandes par le cahier des charges. Un tag pose
# "plus tard" ne l'est jamais.
#
# Deux precautions apprises a la dure :
# - les ressources enfants (sous-reseaux, regles NSG, affectations de roles,
#   tables, files) ne supportent pas les tags : elles sont exclues par type,
#   sinon la politique bloquerait la creation de l'infrastructure elle-meme ;
# - l'attribution est creee apres le reste (depends_on cote appelant), pour ne
#   jamais refuser la construction initiale.

locals {
  untaggable_types = [
    "Microsoft.Storage/storageAccounts/tableServices/tables",
    "Microsoft.Storage/storageAccounts/queueServices/queues",
    "Microsoft.Network/virtualNetworks/subnets",
    "Microsoft.Network/networkSecurityGroups/securityRules",
    "Microsoft.Authorization/roleAssignments",
    "Microsoft.Authorization/policyAssignments",
    "Microsoft.Authorization/policyDefinitions",
    "Microsoft.Insights/diagnosticSettings",
  ]
}

resource "azurerm_policy_definition" "required_tags" {
  name         = "kaaru-required-tags"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Kaaru - tags obligatoires (owner, project, environment)"
  description  = "Refuse toute ressource sans les tags owner, project et environment."

  metadata = jsonencode({
    category = "Kaaru"
    version  = "1.0.0"
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          not = {
            field = "type"
            in    = local.untaggable_types
          }
        },
        {
          anyOf = [
            { field = "tags['owner']", exists = "false" },
            { field = "tags['project']", exists = "false" },
            { field = "tags['environment']", exists = "false" },
          ]
        },
      ]
    }
    then = { effect = "deny" }
  })
}

resource "azurerm_resource_group_policy_assignment" "required_tags" {
  name                 = "kaaru-required-tags"
  resource_group_id    = var.resource_group_id
  policy_definition_id = azurerm_policy_definition.required_tags.id
  display_name         = "Tags obligatoires sur chaque ressource"
  description          = "Empeche le deploiement d'une ressource non taguee."
  enforce              = true
}
