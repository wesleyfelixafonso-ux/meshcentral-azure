<#
.SYNOPSIS
  Instala o agente do MeshCentral e coloca a máquina no grupo certo.

.DESCRIPTION
  Feito para rodar como SYSTEM por um RMM (Atera, NinjaOne, Intune...) em massa nas máquinas. Idempotente: se o serviço "Mesh Agent" já existir e estiver rodando, não faz nada.

  O MeshId identifica o grupo de dispositivos e funciona como chave de cadastro: quem tem o valor
  consegue colocar uma máquina no grupo (mas NÃO consegue acessar nenhuma). Por isso ele não fica no
  repositório: copie no console (grupo > Adicionar Agente > link do Windows x86-64, parâmetro meshid)
  e cadastre como argumento do script no RMM, um script por grupo.

.PARAMETER Server
  Endereço do seu MeshCentral (ex.: https://remoto.suaempresa.com.br).

.PARAMETER MeshId
  Valor do parâmetro meshid do link de download do grupo (64 caracteres, sem o prefixo "mesh//").

.EXAMPLE
  # Argumentos do script no RMM:
  -Server "https://remoto.suaempresa.com.br" -MeshId "<meshid do grupo>"
#>
param(
  [Parameter(Mandatory = $true)][string]$MeshId,
  [Parameter(Mandatory = $true)][string]$Server
)

$ErrorActionPreference = 'Stop'
$Server = $Server.Trim().TrimEnd('/')

# Aceita o meshid puro, codificado (%24 = $, %40 = @, como vem no link) ou o link inteiro.
# Prefira o codificado no RMM: sem '$', o PowerShell não tenta expandir variável no meio do valor.
$MeshId = $MeshId.Trim().Trim('"', "'")
if ($MeshId -match 'meshid=([^&]+)') { $MeshId = $matches[1] }
$MeshId = [uri]::UnescapeDataString($MeshId)
if ($MeshId -notmatch '^[A-Za-z0-9@$]{64}$') {
  Write-Output "ERRO: MeshId inválido ($($MeshId.Length) caracteres). Use o valor do parâmetro meshid do link de download do grupo."
  exit 1
}
$log = Join-Path $env:ProgramData 'AcessoRemoto\meshcentral-instalacao.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
function Write-Log([string]$msg) {
  $linha = "{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $msg
  Add-Content -Path $log -Value $linha -Encoding UTF8
  Write-Output $linha
}

$svc = Get-Service -Name 'Mesh Agent' -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq 'Running') { Write-Log "Mesh Agent já instalado e rodando em $env:COMPUTERNAME. Nada a fazer."; exit 0 }
if ($svc) { Write-Log "Mesh Agent instalado mas $($svc.Status): reinstalando." }

$arch = if ([Environment]::Is64BitOperatingSystem) { if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' } } else { 'x86' }
$id = @{ x64 = 4; x86 = 3; arm64 = 43 }[$arch]
$url = "$Server/meshagents?id=$id&meshid=$([uri]::EscapeDataString($MeshId))&installflags=0"
# Pasta própria (fácil de excluir no antivírus): a Temp do Windows não deve ganhar exclusão.
$dir = Join-Path $env:ProgramData 'AcessoRemoto\Instaladores'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$exe = Join-Path $dir "MeshAgent-$([guid]::NewGuid().ToString('N')).exe"

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Write-Log "Baixando agente $arch de $Server (grupo $($MeshId.Substring(0,8))...)."
  Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing -TimeoutSec 120
  if ((Get-Item $exe).Length -lt 1MB) { throw "Download veio pequeno demais ($((Get-Item $exe).Length) bytes): confira o MeshId." }

  Write-Log 'Instalando (-fullinstall).'
  $p = Start-Process -FilePath $exe -ArgumentList '-fullinstall' -Wait -PassThru -WindowStyle Hidden
  if ($p.ExitCode -ne 0) { throw "Instalador saiu com código $($p.ExitCode)." }

  Start-Sleep -Seconds 10
  $svc = Get-Service -Name 'Mesh Agent' -ErrorAction SilentlyContinue
  if (-not $svc -or $svc.Status -ne 'Running') { throw 'Serviço Mesh Agent não ficou rodando após a instalação.' }
  Write-Log "OK: Mesh Agent rodando em $env:COMPUTERNAME."
  exit 0
}
catch {
  Write-Log "ERRO: $($_.Exception.Message)"
  exit 1
}
finally {
  Remove-Item -Path $exe -Force -ErrorAction SilentlyContinue
}
