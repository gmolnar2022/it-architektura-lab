#requires -Modules Az.Compute, Az.Network, Az.Resources
$ErrorActionPreference = 'Stop'

# A már bejelentkezett Azure PowerShell-munkamenetet használjuk.
# Ha szükséges: Connect-AzAccount
if (-not (Get-AzContext)) { throw 'Nincs aktív Azure-kapcsolat. Futtasd: Connect-AzAccount' }

# Resolve a resource name and resource group from an Azure ARM ID.
function Get-ArmResourceParts {
    param([Parameter(Mandatory=$true)][string]$ResourceId)
    $segments = $ResourceId.Trim('/') -split '/'
    $rgIndex = -1
    for ($j = 0; $j -lt $segments.Length; $j++) {
        if ($segments[$j] -ieq 'resourceGroups') { $rgIndex = $j; break }
    }
    if ($rgIndex -lt 0 -or ($rgIndex + 1) -ge $segments.Length) {
        throw "Invalid ARM resource ID: $ResourceId"
    }
    [pscustomobject]@{
        ResourceGroupName = $segments[$rgIndex + 1]
        Name = $segments[-1]
    }
}

$groups = @(Get-AzResourceGroup | Sort-Object ResourceGroupName)
if ($groups.Count -eq 0) { throw 'Nincs elérhető erőforráscsoport.' }
Write-Host "`nVálassz erőforráscsoportot:" -ForegroundColor Cyan
for ($i=0; $i -lt $groups.Count; $i++) { Write-Host ("{0}. {1}" -f ($i+1), $groups[$i].ResourceGroupName) }
$choice = Read-Host 'Erőforráscsoport sorszáma'
[int]$idx = 0
if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $groups.Count) { throw 'Érvénytelen választás.' }
$rg = $groups[$idx-1].ResourceGroupName

$vms = @(Get-AzVM -ResourceGroupName $rg | Sort-Object Name)
if ($vms.Count -eq 0) { throw "Nincs virtuális gép a(z) $rg erőforráscsoportban." }
Write-Host "`nVálassz virtuális gépet:" -ForegroundColor Cyan
for ($i=0; $i -lt $vms.Count; $i++) { Write-Host ("{0}. {1}" -f ($i+1), $vms[$i].Name) }
$choice = Read-Host 'Virtuális gép sorszáma'
$idx = 0
if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $vms.Count) { throw 'Érvénytelen választás.' }
$vm = $vms[$idx-1]
$vmName = $vm.Name

Write-Host "`n=== 1. VM adatai ===" -ForegroundColor Cyan
$vmStatus = Get-AzVM -ResourceGroupName $rg -Name $vmName -Status
[pscustomobject]@{
    ResourceGroup = $rg
    VMName        = $vm.Name
    Region        = $vm.Location
    VMSize        = $vm.HardwareProfile.VmSize
    PowerState    = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' } | Select-Object -First 1 -ExpandProperty DisplayStatus)
} | Format-List | Out-String | Write-Host

Write-Host '=== 2. A kiválasztott VM publikus IP-címe ===' -ForegroundColor Cyan
$nicIds = @($vm.NetworkProfile.NetworkInterfaces | ForEach-Object { $_.Id })
$ipRows = @()
foreach ($nicId in $nicIds) {
    $nicRef = Get-ArmResourceParts -ResourceId $nicId
    $nic = Get-AzNetworkInterface -ResourceGroupName $nicRef.ResourceGroupName -Name $nicRef.Name
    foreach ($cfg in $nic.IpConfigurations) {
        if ($cfg.PublicIpAddress -and $cfg.PublicIpAddress.Id) {
            $pipRef = Get-ArmResourceParts -ResourceId $cfg.PublicIpAddress.Id
            $pip = Get-AzPublicIpAddress -ResourceGroupName $pipRef.ResourceGroupName -Name $pipRef.Name
            $ipRows += [pscustomobject]@{ NIC = $nic.Name; PublicIPName = $pip.Name; IpAddress = $pip.IpAddress }
        }
    }
}
if ($ipRows.Count) { $ipRows | Format-Table -AutoSize | Out-String | Write-Host }
else { Write-Host 'Ehhez a VM-hez nem található közvetlenül hozzárendelt publikus IP.' }

Write-Host '=== 3. A VM hálózati NSG-inak bejövő szabályai ===' -ForegroundColor Cyan
$nsgIds = @()
foreach ($nicId in $nicIds) {
    $nicRef = Get-ArmResourceParts -ResourceId $nicId
    $nic = Get-AzNetworkInterface -ResourceGroupName $nicRef.ResourceGroupName -Name $nicRef.Name
    if ($nic.NetworkSecurityGroup -and $nic.NetworkSecurityGroup.Id) { $nsgIds += $nic.NetworkSecurityGroup.Id }
    foreach ($cfg in $nic.IpConfigurations) {
        if ($cfg.Subnet -and $cfg.Subnet.Id) {
            $parts = $cfg.Subnet.Id -split '/'
            $vnetIndex = [Array]::IndexOf($parts, 'virtualNetworks')
            if ($vnetIndex -ge 0 -and ($vnetIndex+1) -lt $parts.Length) {
                $vnetId = ($parts[0..($vnetIndex+1)] -join '/')
                $vnetRef = Get-ArmResourceParts -ResourceId $vnetId
                $vnet = Get-AzVirtualNetwork -ResourceGroupName $vnetRef.ResourceGroupName -Name $vnetRef.Name
                $subnetName = $parts[-1]
                $subnet = $vnet.Subnets | Where-Object Name -eq $subnetName | Select-Object -First 1
                if ($subnet -and $subnet.NetworkSecurityGroup) { $nsgIds += $subnet.NetworkSecurityGroup.Id }
            }
        }
    }
}
$nsgIds = @($nsgIds | Sort-Object -Unique)
if (-not $nsgIds.Count) { Write-Host 'Nincs a VM NIC-jéhez vagy alhálózatához társított NSG.' }
foreach ($nsgId in $nsgIds) {
    $nsgRef = Get-ArmResourceParts -ResourceId $nsgId
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $nsgRef.ResourceGroupName -Name $nsgRef.Name
    Write-Host ("NSG: {0}" -f $nsg.Name)
    $rules = @($nsg.SecurityRules | Where-Object { $_.Direction -eq 'Inbound' } | Sort-Object Priority)
    if ($rules.Count) {
        $rules | Select-Object Name, Priority, Access, Protocol, SourceAddressPrefix, SourceAddressPrefixes, DestinationPortRange, DestinationPortRanges | Format-Table -Wrap | Out-String | Write-Host
    } else { Write-Host 'Nincs egyéni bejövő szabály; alapértelmezett NSG-szabályok ettől még érvényesek.' }
}
Write-Host 'Megjegyzés: ez nem számolja ki a tényleges effektív NSG-szabályokat; az SSH-t az 5. feladatban teszteled.'
