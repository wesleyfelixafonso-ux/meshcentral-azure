<#
.SYNOPSIS
  Instala o agente do MeshCentral e coloca a maquina no grupo certo.

.DESCRIPTION
  Feito para rodar como SYSTEM por um RMM (Atera, NinjaOne, Intune...) em massa nas maquinas. Idempotente: se o servico "Mesh Agent" ja existir e estiver rodando, nao faz nada.

  O MeshId identifica o grupo de dispositivos e funciona como chave de cadastro: quem tem o valor
  consegue colocar uma maquina no grupo (mas NAO consegue acessar nenhuma). Por isso ele nao fica no
  repositorio: copie no console (grupo > Adicionar Agente > link do Windows x86-64, parametro meshid)
  e cadastre como argumento do script no RMM, um script por grupo.

.PARAMETER Server
  Endereco do seu MeshCentral (ex.: https://remoto.suaempresa.com.br).

.PARAMETER MeshId
  Valor do parametro meshid do link de download do grupo (64 caracteres, sem o prefixo "mesh//").

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
# Prefira o codificado no RMM: sem '$', o PowerShell nao tenta expandir variavel no meio do valor.
$MeshId = $MeshId.Trim().Trim('"', "'")
if ($MeshId -match 'meshid=([^&]+)') { $MeshId = $matches[1] }
$MeshId = [uri]::UnescapeDataString($MeshId)
if ($MeshId -notmatch '^[A-Za-z0-9@$]{64}$') {
  Write-Output "ERRO: MeshId invalido ($($MeshId.Length) caracteres). Use o valor do parametro meshid do link de download do grupo."
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
if ($svc -and $svc.Status -eq 'Running') { Write-Log "Mesh Agent ja instalado e rodando em $env:COMPUTERNAME. Nada a fazer."; exit 0 }
if ($svc) { Write-Log "Mesh Agent instalado mas $($svc.Status): reinstalando." }

$arch = if ([Environment]::Is64BitOperatingSystem) { if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' } } else { 'x86' }
$id = @{ x64 = 4; x86 = 3; arm64 = 43 }[$arch]
$url = "$Server/meshagents?id=$id&meshid=$([uri]::EscapeDataString($MeshId))&installflags=0"
# Pasta propria (facil de excluir no antivirus): a Temp do Windows nao deve ganhar exclusao.
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
  if ($p.ExitCode -ne 0) { throw "Instalador saiu com codigo $($p.ExitCode)." }

  Start-Sleep -Seconds 10
  $svc = Get-Service -Name 'Mesh Agent' -ErrorAction SilentlyContinue
  if (-not $svc -or $svc.Status -ne 'Running') { throw 'Servico Mesh Agent nao ficou rodando apos a instalacao.' }
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
