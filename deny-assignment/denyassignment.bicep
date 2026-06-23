targetScope = 'resourceGroup'

@description('Name of the existing route table (UDR) to protect with the deny assignment.')
param routeTableName string

@description('Display name shown for the deny assignment.')
param denyAssignmentDisplayName string = 'Deny modify and delete of protected route table (UDR)'

@description('Object IDs of principals to exclude from the deny assignment (for example a break-glass admin). Azure requires AT LEAST ONE excluded principal when the deny targets All Principals, so this must contain at least one object ID.')
param excludePrincipalIds array = []

@description('Effect of the deny assignment. "enforced" blocks the actions, "audit" only logs them.')
@allowed([
  'enforced'
  'audit'
])
param denyAssignmentEffect string = 'enforced'

// Existing route table created by routetable.bicep. The deny assignment is an
// extension resource scoped to this route table, so the blast radius is limited
// to this single resource and its child routes.
resource routeTable 'Microsoft.Network/routeTables@2023-11-01' existing = {
  name: routeTableName
}

// "All Principals" system-defined principal (zero GUID) targets every user,
// group, service principal and managed identity in the directory.
var allPrincipals = {
  id: '00000000-0000-0000-0000-000000000000'
  type: 'SystemDefined'
}

// Write/delete operations on the protected route table and its routes.
// NOTE: a user-assigned deny assignment CANNOT protect itself from deletion.
// Azure rejects 'Microsoft.Authorization/denyAssignments/write' AND
// 'Microsoft.Authorization/denyAssignments/delete' in the denied actions with
// 'InvalidActionOrNotAction'. Only a SYSTEM-protected deny assignment
// (isSystemProtected = true, created by Azure via deployment stacks / blueprints)
// is tamper-proof, and users cannot set that flag. So the deny only covers the
// route table actions; a targeted Owner can still delete the deny assignment.
var deniedActions = [
  'Microsoft.Network/routeTables/write'
  'Microsoft.Network/routeTables/delete'
  'Microsoft.Network/routeTables/routes/write'
  'Microsoft.Network/routeTables/routes/delete'
]

// Build the exclude-principals list. Azure rejects a user-assigned deny
// assignment that carries an EMPTY excludePrincipals array
// (UserAssignedDenyAssignmentPropertiesNotValid), so the property must be
// omitted entirely when there are no exclusions.
var excludePrincipals = [
  for id in excludePrincipalIds: {
    id: id
    type: 'User'
  }
]

// User-assigned deny assignment. Deny assignments override all role
// assignments (including Owner), so even highly privileged users cannot
// perform the denied write/delete actions on the route table or its routes.
resource denyAssignment 'Microsoft.Authorization/denyAssignments@2024-07-01-preview' = {
  name: guid(routeTable.id, 'deny-udr-modify')
  scope: routeTable
  properties: union(
    {
      denyAssignmentName: denyAssignmentDisplayName
      description: 'Blocks write and delete operations on the protected route table and its routes (UDR).'
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
