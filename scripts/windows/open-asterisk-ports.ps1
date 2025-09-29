#requires -RunAsAdministrator

<#!
.SYNOPSIS
  Abre las reglas de firewall requeridas para la integración Asterisk + Twilio.

.DESCRIPTION
  Crea reglas de entrada en Windows Firewall para los puertos SIP (TCP/UDP 5060, TCP 5061)
  y para el rango RTP (UDP 10000-10100). Si las reglas ya existen, se actualizan.

.EXAMPLE
  PS C:\> ./open-asterisk-ports.ps1
#>

$rules = @(
  @{ Name = "Asterisk SIP UDP 5060";  Protocol = "UDP"; Ports = "5060" },
  @{ Name = "Asterisk SIP TCP 5060";  Protocol = "TCP"; Ports = "5060" },
  @{ Name = "Asterisk SIP TLS 5061";  Protocol = "TCP"; Ports = "5061" },
  @{ Name = "Asterisk RTP UDP 10000-10100"; Protocol = "UDP"; Ports = "10000-10100" }
)

foreach ($rule in $rules) {
  $existing = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue

  if ($null -ne $existing) {
    Write-Host "Eliminando regla previa para recrearla: $($rule.Name)" -ForegroundColor Yellow
    Remove-NetFirewallRule -Name $existing.Name
  }

  Write-Host "Creando regla: $($rule.Name)" -ForegroundColor Cyan
  New-NetFirewallRule `
    -DisplayName $rule.Name `
    -Direction Inbound `
    -Action Allow `
    -Profile Any `
    -Enabled True `
    -Protocol $rule.Protocol `
    -LocalPort $rule.Ports `
    -RemotePort Any `
    -Group "Asterisk Twilio"
}

Write-Host "Reglas de firewall aplicadas." -ForegroundColor Green
