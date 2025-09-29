<#!
.SYNOPSIS
  Elimina las reglas de firewall creadas por open-asterisk-ports.ps1.
#requires -RunAsAdministrator

<#!
.SYNOPSIS
  Elimina las reglas de firewall creadas para la integración Asterisk + Twilio.

.DESCRIPTION
  Busca las reglas agrupadas bajo "Asterisk Twilio" y las elimina de Windows Firewall.

.EXAMPLE
  PS C:\> ./close-asterisk-ports.ps1
#>
$rules = Get-NetFirewallRule -Group $groupName -ErrorAction SilentlyContinue

if ($null -eq $rules) {
    Write-Host "No se encontraron reglas pertenecientes al grupo '$groupName'." -ForegroundColor Yellow
    return
}

foreach ($rule in $rules) {
    Write-Host "Eliminando regla: $($rule.DisplayName)" -ForegroundColor Cyan
    Remove-NetFirewallRule -Name $rule.Name
}

Write-Host "Reglas de firewall eliminadas." -ForegroundColor Green
