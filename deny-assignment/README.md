# Deny assignment vs. Azure Policy `denyAction`

This folder protects an Azure Route Table (UDR) with an **Azure deny assignment**. The sibling folder [`../denyudrdelete`](../denyudrdelete) solves a similar goal with an **Azure Policy** `denyAction` effect. This document compares the two approaches.

## Goal of both folders

Prevent changes to a force-tunneling user defined route (`0.0.0.0/0` → virtual appliance) so that traffic cannot be silently re-routed or the route table removed.

## Approaches at a glance

| Aspect | `deny-assignment` (this folder) | `denyudrdelete` |
| --- | --- | --- |
| Mechanism | RBAC **deny assignment** (`Microsoft.Authorization/denyAssignments`) | **Azure Policy** custom definition with `denyAction` effect |
| Authorization layer | Resource Manager RBAC | Azure Policy engine |
| Defined in Bicep | Yes — `denyassignment.bicep` (`2024-07-01-preview`) | No — policy is JSON + `az policy` CLI; Bicep only builds infrastructure |
| What is blocked | `write` **and** `delete` on the route table and its routes | `delete` only (`denyAction` supports delete and a limited set of actions) |
| Overrides `Owner` | Yes — deny assignments beat every role assignment | Yes — policy `denyAction` blocks regardless of role |
| Target principals | All Principals, with optional `excludePrincipals` | All callers in scope (no principal exclusion concept) |
| Break-glass exclusion | Yes — `excludePrincipalIds` parameter | No native per-principal exclusion |
| Self-protection from bypass | No — a user-assigned deny assignment cannot deny its own `denyAssignments/delete`; only system-protected ones (deployment stacks/blueprints) are tamper-proof | Owner can unassign/delete the policy assignment unless separately protected |
| Audit-only mode | Yes — `denyAssignmentEffect = 'audit'` | Effectively no for `denyAction` (it blocks; auditing needs a different effect/policy) |
| Scope | The route table resource (extension resource) | Resource group via policy assignment |
| Error returned | Authorization error naming the deny assignment | `RequestDisallowedByPolicy` naming the policy assignment |
| Evaluation timing | RBAC cache up to ~30 min | Near-immediate after assignment |
| Setup objects | One deny assignment | Policy definition **plus** policy assignment |

## How each one works

### `deny-assignment` (this folder)

1. [`routetable.bicep`](routetable.bicep) deploys the route table and its force-tunneling route.
2. [`denyassignment.bicep`](denyassignment.bicep) deploys a `Microsoft.Authorization/denyAssignments` resource scoped to that route table. It denies these actions for the **All Principals** system-defined principal:
   - `Microsoft.Network/routeTables/write`
   - `Microsoft.Network/routeTables/delete`
   - `Microsoft.Network/routeTables/routes/write`
   - `Microsoft.Network/routeTables/routes/delete`
3. [`deny-assignment-demo.ipynb`](deny-assignment-demo.ipynb) walks through the effect with and without the deny assignment, plus a break-glass exclusion and an audit-only variant.

The deny lives in the RBAC layer, so it blocks **both modification and deletion**, and you can exclude specific principals.

### `denyudrdelete`

1. `main.bicep` / `infra.bicep` / `vm.bicep` deploy a fuller environment (two virtual networks with peering, the route table, an Azure Firewall, and a virtual machine).
2. Two custom Azure Policy definitions are created and assigned through the Azure CLI:
   - `policy.deny.udr.delete.json` (`DenyUDRDelete`) — denies `delete` on `Microsoft.Network/routeTables/routes` where `addressPrefix == 0.0.0.0/0` (the force-tunneling route only).
   - `policy.deny.rt.delete.json` (`DenyRTDelete`) — denies `delete` on the whole `Microsoft.Network/routeTables` resource.
3. The protection is verified by attempting `az network route-table route delete` and `az network route-table delete`, both of which return `RequestDisallowedByPolicy`.

Because `denyAction` targets delete operations, this approach stops **deletion** but does not stop a caller from **modifying** the route in place.

## Practical differences that matter

- **Modify vs. delete**: the deny assignment blocks both `write` and `delete`, so it also prevents *changing* the next hop of an existing route. The `denyAction` policy in `denyudrdelete` only blocks `delete`, so the route could still be edited.
- **Per-principal control**: only the deny assignment supports excluding a break-glass admin via `excludePrincipals`. Policy `denyAction` applies to everyone in scope.
- **All in Bicep vs. split**: the deny assignment is fully declarative in Bicep. The policy approach builds infrastructure in Bicep but creates and assigns the policy through separate `az policy` commands.
- **Propagation delay**: RBAC (and therefore deny assignments) can take up to 30 minutes to fully propagate because of authorization caching. Policy assignments generally take effect faster for `denyAction`.
- **Operational footprint**: the policy approach needs both a definition and an assignment (and cleanup of both). The deny assignment is a single resource.

## When to use which

- Use a **deny assignment** when you must block **modification and deletion**, need to **exclude a break-glass identity**, or want everything declared in **Bicep**.
- Use an **Azure Policy `denyAction`** when you want **policy-based governance** that integrates with compliance reporting, when blocking **deletion** is sufficient, or when you apply the control **broadly** (subscription or management group) rather than to a single resource.

## Can an Owner bypass the deny assignment?

Short answer: **yes — and for a user-assigned deny assignment you cannot fully prevent it.**

A user-assigned deny assignment is **not** system protected (`isSystemProtected = false` — only deny assignments that Azure itself creates, such as those behind deployment stacks or blueprints, are system protected). An `Owner` holds the wildcard action `*`, which includes `Microsoft.Authorization/denyAssignments/delete`. So a targeted Owner can simply **delete the deny assignment** and then change the route — the protection is gone.

### What `isSystemProtected` actually means

`isSystemProtected` is a **read-only flag on every deny assignment** that Azure sets for you — you cannot set it yourself. It answers one question: *"Did Azure create and own this deny assignment, or did a user?"*

- `isSystemProtected = true` → **Azure owns it.** Nobody can edit or delete it, not even an `Owner` or a Global Admin. Azure removes it automatically when the owning construct goes away.
- `isSystemProtected = false` → **a user created it.** It behaves like a normal resource: anyone with `Microsoft.Authorization/denyAssignments/delete` (every `Owner` has it through `*`) can delete it.

Think of it like the difference between a **factory seal** and a **padlock you bought yourself**:

| | `isSystemProtected = true` | `isSystemProtected = false` |
| --- | --- | --- |
| Who created it | Azure (deployment stack, blueprint, managed app) | You, via Bicep / `New-AzDenyAssignment` |
| Who can remove it | Only Azure (by deleting the owning construct) | Anyone with `denyAssignments/delete`, e.g. any `Owner` |
| Can you set the flag | No — Azure sets it | No — it is always `false` for your own |

**Concrete example.** Imagine two deny assignments on the same route table:

1. **Deployment-stack deny** — you deploy the route table through an Azure *deployment stack* with `denySettings.mode = denyDelete`. Azure creates a deny assignment behind the scenes with `isSystemProtected = true`. Even an Owner running `az stack ... ` cannot delete *that* deny assignment directly; it only disappears when the stack is deleted with the right flags. It is "factory-sealed".

2. **Your Bicep deny** ([`denyassignment.bicep`](denyassignment.bicep)) — you author the deny assignment yourself. Azure stores it with `isSystemProtected = false`. An Owner targeted by it can run:

   ```bash
   az rest --method delete \
     --url "https://management.azure.com${DENY_ID}?api-version=2024-07-01-preview"
   ```

   …and it succeeds, because deleting a *user-created* deny assignment is just another action that `Owner`'s `*` permits. The route is now unprotected. This is exactly the bypass that **Step 6** of the notebook demonstrates — and that, for user-assigned deny assignments, **cannot be closed**.

Because you **cannot** make your own deny assignment `isSystemProtected = true`, and you **cannot** deny its own management actions either (next section), a user-assigned deny assignment can never fully defend itself. For tamper-proof protection you must use a *system-protected* deny assignment.

### Why you cannot "self-protect" a user-assigned deny assignment

The intuitive idea is to add the deny assignment's **own management action** to its denied actions:

- `Microsoft.Authorization/denyAssignments/delete`

**Azure rejects this** at deploy time for user-assigned deny assignments:

```
InvalidActionOrNotAction: 'Microsoft.Authorization/denyAssignments/delete' is not
permitted in user assigned deny assignments. Denying delete access to deny
assignments is not allowed.
```

The same restriction applies to `Microsoft.Authorization/denyAssignments/write`. So there is **no** way to make a user-assigned deny assignment block its own deletion. The only tamper-proof option is a **system-protected** deny assignment (`isSystemProtected = true`), which only Azure can create.

### Do you need a custom role? No.

The bypass is only possible for a principal that holds `Microsoft.Authorization/denyAssignments/delete`. Among the built-in roles **only three** have it - **Owner**, **User Access Administrator**, and **Role Based Access Control Administrator** (they carry `Microsoft.Authorization/*`). Every other built-in role cannot delete a deny assignment; for example **Contributor** and **Network Contributor** list `Microsoft.Authorization/*/Delete` and `/Write` in their `NotActions`.

| Principal's role | Modify/delete the route table? | Delete the deny assignment? |
| --- | --- | --- |
| Contributor / Network Contributor | No - blocked by the deny assignment | **No** - lacks `denyAssignments/delete` |
| Owner / User Access Admin / RBAC Admin | No - blocked by the deny assignment | **Yes** - can remove it, then change the route |

So for the common case the deny assignment is fully effective **with no custom role** - it expresses a *deny* on write/delete that RBAC roles cannot, and those roles already cannot touch deny assignments.

### How to close the residual Owner bypass

- **Least privilege (no custom role needed)** - do not grant **Owner / User Access Administrator / Role Based Access Control Administrator** to the people you are restricting. Give them **Contributor** or a narrower resource role; then they cannot delete the deny assignment and there is no bypass.
- **Deployment stack** with `denySettings.mode = denyDelete` - Azure creates a *system-protected* deny assignment behind the scenes that even an Owner cannot remove directly.
- Keep the **break-glass exclusion** (`excludePrincipalIds`) so a trusted admin can still manage the route table while everyone else is blocked.

> Note: user-assigned deny assignments via `2024-07-01-preview` / `New-AzDenyAssignment` are a **preview** capability. The `audit` effect is likewise preview and may still enforce in some tenants. Validate the behaviour in your target tenant before relying on it.

## Files

| File | Purpose |
| --- | --- |
| [routetable.bicep](routetable.bicep) | Route table with the force-tunneling UDR |
| [routetable.bicepparam](routetable.bicepparam) | Parameters for the route table |
| [denyassignment.bicep](denyassignment.bicep) | Deny assignment that protects the route table |
| [denyassignment.bicepparam](denyassignment.bicepparam) | Parameters for the deny assignment |
| [deny-assignment-demo.ipynb](deny-assignment-demo.ipynb) | Step-by-step walkthrough (bash + Azure CLI) |
| [NOTES.md](NOTES.md) | Original requirement and file index |
