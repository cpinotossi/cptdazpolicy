# Extract Azure Policy deployIfNotExists actions on Private Endpoints from activity.log.json
# Now also includes the underlying resource activity log entries (non-Policy) for each private endpoint
# Output: CSV + on-screen summary (Policy + Resource events)

param(
    [string]$LogPath = "activity.log.json",
    [string]$OutCsv = "logs\private_endpoint_policy_events.csv",
    [string]$OutRawJson = "logs\private_endpoint_policy_events_raw.json",
    [switch]$IncludeResourceEvents,
    [switch]$Correlate,
    [int]$CorrelationWindowMinutes = 30
)

if (-not $PSBoundParameters.ContainsKey('IncludeResourceEvents')) { $IncludeResourceEvents = $true }
if (-not $PSBoundParameters.ContainsKey('Correlate')) { $Correlate = $true }

Write-Host "Reading activity log JSON..." -ForegroundColor Green
if (-not (Test-Path $LogPath)) { throw "Log file not found: $LogPath" }

$json = Get-Content -Path $LogPath -Raw | ConvertFrom-Json
Write-Host "Total records: $($json.Count)" -ForegroundColor Yellow

# ---- Target operation/action expansion (added privateDnsZoneGroups) ----
# Central definition of actions/resourceTypes we treat as Private Endpoint related.
$__TargetActions = @(
    'Microsoft.Network/privateEndpoints/write',
    'Microsoft.Network/privateEndpoints/privateDnsZoneGroups/write'
)
$__TargetResourceTypes = @(
    'Microsoft.Network/privateEndpoints',
    'Microsoft.Network/privateEndpoints/privateDnsZoneGroups'
)
function Test-IsPrivateEndpointRelated {
    param($Evt)
    if (-not $Evt) { return $false }
    $action = $Evt.authorization.action
    $rtype  = $Evt.resourceType.value
    $rid    = $Evt.resourceId
    if ($action -and ($__TargetActions -contains $action)) { return $true }
    if ($rtype -and ($__TargetResourceTypes -contains $rtype)) { return $true }
    if ($rid -and $rid -like '*/Microsoft.Network/privateEndpoints/*') { return $true }
    return $false
}
# ---- End target operation/action expansion ----

# Pre-index BeginRequest events by operationId for efficient duration lookup
$beginMap = @{}
foreach ($ev in $json) {
    if ($ev.operationId -and $ev.eventName -and $ev.eventName.value -eq 'BeginRequest') {
        if (-not $beginMap.ContainsKey($ev.operationId)) { $beginMap[$ev.operationId] = $ev.eventTimestamp }
    }
}

# Base filter: policy + private endpoint related (now includes privateDnsZoneGroups)
$baseFiltered = $json |
    Where-Object {
        $_.category.value -eq 'Policy' -and (Test-IsPrivateEndpointRelated $_)
    }

Write-Host "Included target actions: $([string]::Join(', ', $__TargetActions))" -ForegroundColor Yellow
Write-Host "Included target resourceTypes: $([string]::Join(', ', $__TargetResourceTypes))" -ForegroundColor Yellow

if (-not $baseFiltered) { Write-Warning 'No matching policy private endpoint events found.'; return }

# Collect distinct private endpoint resourceIds referenced in Policy End events (priority) else all policy events
$policyResourceIds = ($baseFiltered | Where-Object { $_.resourceId }) | Select-Object -ExpandProperty resourceId -Unique

# NEW: also include child resource ids referenced in updatedResources of policy events (e.g., privateDnsZoneGroups)
$childIds = @()
foreach ($pe in $baseFiltered) {
    $urText = $pe.properties.updatedResources
    if ([string]::IsNullOrWhiteSpace($urText)) { continue }
    try { $parsed = $urText | ConvertFrom-Json -ErrorAction Stop } catch { $parsed = $null }
    if (-not $parsed) { continue }
    if ($parsed -is [array]) { $childIds += ($parsed | ForEach-Object { $_.id }) }
    elseif ($parsed.id) { $childIds += $parsed.id }
}
if ($childIds.Count -gt 0) {
    $beforeCount = $policyResourceIds.Count
    $policyResourceIds = ($policyResourceIds + $childIds | Where-Object { $_ }) | Sort-Object -Unique
    $added = $policyResourceIds.Count - $beforeCount
    Write-Host "Added $added child resourceId(s) from updatedResources (total now: $($policyResourceIds.Count))" -ForegroundColor Yellow
}

# Ensure we also include corresponding BeginRequest rows for each operationId (even if they did not satisfy base filter)
$operationIds = $baseFiltered | Where-Object { $_.operationId } | Select-Object -ExpandProperty operationId -Unique
$beginEvents = $json | Where-Object { $_.eventName.value -eq 'BeginRequest' -and $operationIds -contains $_.operationId }

# Combine policy events (End + Begin inside category Policy)
$combinedPolicyRaw = @{}
foreach ($e in ($baseFiltered + $beginEvents)) { if (-not $combinedPolicyRaw.ContainsKey($e.eventDataId)) { $combinedPolicyRaw[$e.eventDataId] = $e } }
$policyEvents = $combinedPolicyRaw.Values

# Optionally gather underlying resource events (non-Policy) for those private endpoints
$resourceEvents = @()
if ($IncludeResourceEvents) {
    $resourceEvents = $json | Where-Object {
        $_.category.value -ne 'Policy' -and $_.resourceId -in $policyResourceIds -and (Test-IsPrivateEndpointRelated $_)
    }
}

# ---- Export raw matching activity log entries to JSON ----
try {
    $rawMap = @{}
    foreach ($e in ($policyEvents + $resourceEvents)) {
        $key = if ($e.eventDataId) { $e.eventDataId } else { [guid]::NewGuid().ToString() }
        if (-not $rawMap.ContainsKey($key)) { $rawMap[$key] = $e }
    }
    $rawOrdered = $rawMap.Values | Sort-Object eventTimestamp
    $rawOrdered | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutRawJson -Encoding utf8
    Write-Host "Exported raw matching activity log entries to $OutRawJson" -ForegroundColor Green
}
catch { Write-Warning "Failed to write raw JSON output: $($_.Exception.Message)" }

# Helper to safely parse nested JSON strings (policies / updatedResources)
function Convert-NestedJsonOrNull {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    try { return $Text | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
}

function Build-Row {
    param(
        [Parameter(Mandatory=$true)]$e,
        [Parameter(Mandatory=$true)][string]$EventSource
    )
    $policies = Convert-NestedJsonOrNull -Text $e.properties.policies
    $updated  = Convert-NestedJsonOrNull -Text $e.properties.updatedResources
    $p = $null; if ($policies) { if ($policies -is [array]) { $p = $policies[0] } else { $p = $policies } }
    $eventTime = $null; $beginTime = $null; try { $eventTime = [datetime]$e.eventTimestamp } catch {}
    $beginTimeStr = $beginMap[$e.operationId]; if ($beginTimeStr) { try { $beginTime = [datetime]$beginTimeStr } catch {} }
    # EventPhase removed from output; correlation will rely on EventName (BeginRequest/EndRequest)
    # DurationSeconds removed per request
    # UpdatedResourcesCount removed per request (but still parse updatedResources for potential child IDs earlier in pipeline)
    [PSCustomObject]@{
        EventSource=$EventSource
        EventTimestamp=$e.eventTimestamp
        EventName=$e.eventName.value
        Status=$e.status.value
        ResourceGroup=$e.resourceGroup
        ResourceId=$e.resourceId
        OperationId=$e.operationId
        OperationName=$e.operationName.value
        OperationNameLocalized=$e.operationName.localizedValue
        DeploymentId=$e.properties.deploymentId
        PolicyDefinitionId=$p.policyDefinitionId
        PolicyDefinitionName=$p.policyDefinitionName
        PolicyAssignmentId=$p.policyAssignmentId
        PolicyAssignmentName=$p.policyAssignmentName
        PolicyEffect=$p.policyDefinitionEffect
        UpdatedResources=$(
            if ($updated) {
                if ($updated -is [array]) { ($updated | ForEach-Object { $_.id }) -join ';' }
                elseif ($updated.id) { $updated.id } else { '' }
            } else { '' }
        )
    }
}

$results = @()
foreach ($e in $policyEvents)    { $results += (Build-Row -e $e -EventSource 'Policy') }
foreach ($e in $resourceEvents)  { $results += (Build-Row -e $e -EventSource 'Resource') }

# Deduplicate on (EventSource, eventDataId) by hashing eventDataId (policy events have unique eventDataId; resource events may overlap) 
$seenIds = @{}
$final = @()
foreach ($row in ($results | Sort-Object {[DateTime]$_.EventTimestamp})) {
    $orig = ($row.OperationId + '|' + $row.EventSource + '|' + $row.EventTimestamp)
    if (-not $seenIds.ContainsKey($orig)) { $seenIds[$orig] = $true; $final += $row }
}

# ---- Correlation Logic (Policy -> Resource) ----
if ($Correlate) {
    Write-Host "Building Policy->Resource correlation (window ${CorrelationWindowMinutes}m)..." -ForegroundColor Green
    $resourceIdx=@{}; $resourceEventsOnly = $final | Where-Object { $_.EventSource -eq 'Resource' }; foreach ($r in $resourceEventsOnly) { if (-not $r.ResourceId) { continue }; if (-not $resourceIdx.ContainsKey($r.ResourceId)) { $resourceIdx[$r.ResourceId]=@() }; $resourceIdx[$r.ResourceId]+=$r }
    $__resourceIdxKeys=@($resourceIdx.Keys); foreach ($key in $__resourceIdxKeys) { $resourceIdx[$key] = $resourceIdx[$key] | Sort-Object {[DateTime]$_.EventTimestamp} }
    $policyEventsOnly = $final | Where-Object { $_.EventSource -eq 'Policy' }; foreach ($p in $policyEventsOnly) { $pDt=$null; try { $pDt=[datetime]$p.EventTimestamp } catch {}; if (-not $pDt) { continue }; $list=$resourceIdx[$p.ResourceId]; $best=$null; $matchType='None'; if ($list) { $candidates = $list | Where-Object { ([datetime]$_.EventTimestamp) -le $pDt -and ([datetime]$_.EventTimestamp) -ge $pDt.AddMinutes(-$CorrelationWindowMinutes) }; if ($candidates) { $endCand = $candidates | Where-Object { $_.EventName -eq 'EndRequest' } | Sort-Object {[DateTime]$_.EventTimestamp} -Descending | Select-Object -First 1; if ($endCand) { $best=$endCand; $matchType='End' } else { $beginCand = $candidates | Where-Object { $_.EventName -eq 'BeginRequest' } | Sort-Object {[DateTime]$_.EventTimestamp} -Descending | Select-Object -First 1; if ($beginCand) { $best=$beginCand; $matchType='Begin' } } } }; $lagSec=$null; if ($best) { $lagSec=[Math]::Round(($pDt - [datetime]$best.EventTimestamp).TotalSeconds,2) }; $p | Add-Member -NotePropertyName CorrelatedResourceOperationId -NotePropertyValue ($best.OperationId) -Force; $p | Add-Member -NotePropertyName CorrelatedResourceEventTimestamp -NotePropertyValue ($best.EventTimestamp) -Force; $p | Add-Member -NotePropertyName CorrelationLagSeconds -NotePropertyValue $lagSec -Force; $p | Add-Member -NotePropertyName CorrelationMatchType -NotePropertyValue $matchType -Force }
}
# <--- ensure block closes properly

# Helper: robust CSV export with retries to handle file lock (e.g., opened in Excel)
function Invoke-ExportCsvSafe {
    param(
        [Parameter(Mandatory=$true)]$Data,
        [Parameter(Mandatory=$true)][string]$Path,
        [int]$MaxAttempts = 5,
        [int]$DelayMs = 750
    )
    for ($i=1; $i -le $MaxAttempts; $i++) {
        try {
            $Data | Export-Csv -Path $Path -NoTypeInformation -Force
            return $true
        }
        catch {
            if ($i -eq $MaxAttempts) { Write-Warning "Failed to export CSV to $Path after $i attempts: $($_.Exception.Message)"; return $false }
            Start-Sleep -Milliseconds $DelayMs
        }
    }
}

# Removed global consolidated table output per request

# Reintroduce display column selection (including localized operation name) for per-RG tables
$displayCols = @('EventTimestamp','EventSource','Status','PolicyAssignmentName','OperationName','OperationNameLocalized','UpdatedResources')
if ($Correlate) { $displayCols += 'CorrelationMatchType'; $displayCols += 'CorrelationLagSeconds' }

# ---- Per-ResourceGroup detailed output ----
Write-Host "`nPer-ResourceGroup event breakdown:" -ForegroundColor Green
$rgGroups = $final | Group-Object ResourceGroup | Sort-Object Name
foreach ($rg in $rgGroups) {
    $rgName = if ([string]::IsNullOrWhiteSpace($rg.Name)) { '<None>' } else { $rg.Name }
    Write-Host ("`n=== ResourceGroup: {0} (Events: {1}) ===" -f $rgName, $rg.Count) -ForegroundColor Cyan
    $rg.Group | Sort-Object EventTimestamp | Select-Object $displayCols | Format-Table -AutoSize
    $srcSummary = ($rg.Group | Group-Object EventSource | ForEach-Object { "{0}:{1}" -f $_.Name,$_.Count }) -join '  '
    Write-Host ("  EventSource Summary:  {0}" -f $srcSummary) -ForegroundColor Yellow
}
# ---- End Per-ResourceGroup output ----

# Export (ensure correlation columns included)
$export = $final
if ($Correlate) {
    # Ensure columns exist for all rows
    foreach ($r in $export) {
        if (-not ($r.PSObject.Properties.Name -contains 'CorrelationMatchType')) { $r | Add-Member CorrelationMatchType '' }
        if (-not ($r.PSObject.Properties.Name -contains 'CorrelationLagSeconds')) { $r | Add-Member CorrelationLagSeconds $null }
        if (-not ($r.PSObject.Properties.Name -contains 'CorrelatedResourceOperationId')) { $r | Add-Member CorrelatedResourceOperationId '' }
        if (-not ($r.PSObject.Properties.Name -contains 'CorrelatedResourceEventTimestamp')) { $r | Add-Member CorrelatedResourceEventTimestamp '' }
    }
}
Invoke-ExportCsvSafe -Data $export -Path $OutCsv | Out-Null
Write-Host "Exported to $OutCsv" -ForegroundColor Green

Write-Host "\nSummary by EventSource:" -ForegroundColor Green
$final | Group-Object EventSource | ForEach-Object { Write-Host ("  {0,-8} {1}" -f $_.Name, $_.Count) -ForegroundColor Yellow }

Write-Host "Done." -ForegroundColor Green
