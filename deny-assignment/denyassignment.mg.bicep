targetScope = 'managementGroup'

// Platform-team variant: the deny assignment is created at the MANAGEMENT GROUP
// scope instead of on the single route table. Because RBAC permissions inherit
// downward (MG -> subscription -> RG -> resource) but never upward, an
// application team that is only Owner on a *child subscription* cannot delete a
// deny assignment that lives on the *parent management group*. This closes the
// Owner-bypass from Step 6 through scope separation rather than self-protection.

@description('Display name shown for the deny assignment.')
param denyAssignmentDisplayName string = 'Platform guardrail - protect route tables (UDR) across the management group'

@description('Object IDs of principals to exclude from the deny assignment (the PLATFORM team break-glass admin). Azure requires AT LEAST ONE excluded principal when the deny targets All Principals, so this must contain at least one object ID. Do NOT put the application team here.')
param excludePrincipalIds array

@description('Effect of the deny assignment. "enforced" blocks the actions, "audit" only logs them.')
@allowed([
  'enforced'
  'audit'
])
param denyAssignmentEffect string = 'enforced'

// "All Principals" system-defined principal (zero GUID) targets every user,
// group, service principal and managed identity in the directory.
var allPrincipals = {
  id: '00000000-0000-0000-0000-000000000000'
  type: 'SystemDefined'
}

// Write/delete operations on route tables and their routes are denied across the
// whole management group. A targeted Owner on a child subscription is blocked
// from changing any UDR, AND cannot remove this deny assignment because it has
// no permissions at the parent MG scope where the assignment lives.
var deniedActions = [
  'Microsoft.Network/routeTables/write'
  'Microsoft.Network/routeTables/delete'
  'Microsoft.Network/routeTables/routes/write'
  'Microsoft.Network/routeTables/routes/delete'
]

// Build the exclude-principals list. Azure rejects a user-assigned deny
// assignment that carries an EMPTY excludePrincipals array, so the property is
// omitted entirely when there are no exclusions (see the deep-dive in the
// notebook). In practice excludePrincipalIds always holds the platform admin.
var excludePrincipals = [
  for id in excludePrincipalIds: {
    id: id
    type: 'User'
  }
]

// User-assigned deny assignment at the management group scope. Deny assignments
// override all role assignments (including Owner), so even a subscription Owner
// cannot perform the denied write/delete actions on any route table under the MG.
resource denyAssignment 'Microsoft.Authorization/denyAssignments@2024-07-01-preview' = {
  name: guid(managementGroup().id, 'deny-udr-mg')
  properties: union(
    {
      denyAssignmentName: denyAssignmentDisplayName
      description: 'Blocks write and delete on route tables and routes (UDR) for every principal under this management group.'
      denyAssignmentEffect: denyAssignmentEffect
      doNotApplyToChildScopes: false
      permissions: [
        {
          actions: deniedActions
        }
      ]
      principals: [
        allPrincipals
      ]
    },
    empty(excludePrincipalIds) ? {} : { excludePrincipals: excludePrincipals }
  )
}

output denyAssignmentId string = denyAssignment.id
output denyAssignmentResourceName string = denyAssignment.name
