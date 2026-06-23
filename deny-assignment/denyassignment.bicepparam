using './denyassignment.bicep'

param routeTableName = 'cptdazdeny-rt'

// 'enforced' blocks the denied actions, 'audit' only logs them.
param denyAssignmentEffect = 'enforced'

// Self-protect the deny assignment so a targeted Owner cannot delete it to
// bypass the protection. Only enable this TOGETHER with excludePrincipalIds:
// with no exclusion, self-protection locks EVERYONE (including you) out of
// ever removing the deny assignment. The Step 7 scenario sets this to true
// because it excludes the current admin.
param protectDenyAssignment = false

// Object IDs of break-glass admins that should keep managing the route table.
// Azure requires AT LEAST ONE excluded principal when the deny targets All
// Principals, so set at least one object ID here before deploying.
param excludePrincipalIds = []
