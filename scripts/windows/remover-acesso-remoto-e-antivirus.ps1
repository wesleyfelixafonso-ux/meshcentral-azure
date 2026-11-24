<#
.SYNOPSIS
  Remove outros programas de acesso remoto (AnyDesk, TeamViewer, RustDesk, VNC...) e antivírus que
  não sejam o antivírus oficial da empresa (padrão: SentinelOne). Ex.: Avast, AVG, McAfee, ESET, Norton.

.DESCRIPTION
  Feito para rodar como SYSTEM por um RMM (Atera, NinjaOne, Intune...).

  POR PADRÃO SÓ SIMULA: lista o que removeria e sai. Para remover de verdade, passe -Executar.
  Sugestão: rodar primeiro em todas as máquinas sem -Executar (vira inventário no log/saída do RMM).

  Travas de segurança:
  - Acesso remoto só é removido se o serviço "Mesh Agent" estiver rodando (para não perder o acesso).
  - Antivírus só é removido se o antivírus oficial (-ServicosAntivirusOficial) estiver rodando
    (para a máquina nunca ficar sem proteção).
  - Nunca remove: o RMM e o antivírus oficial (-Protegidos), Mesh Agent/MeshCentral, Microsoft
    Defender e Splashtop (acesso remoto integrado de alguns RMMs; só com -IncluirSplashtop).

  Desinstalação silenciosa é "melhor esforço": MSI vai por msiexec /x, Inno Setup por /VERYSILENT,
  NSIS por /S. Antivírus com proteção contra adulteração (McAfee, Avast/AVG, Norton, ESET com senha)
  costumam recusar; o item sai como MANUAL com a ferramenta oficial de remoção do fabricante.

  Log: %ProgramData%\AcessoRemoto\meshcentral-instalacao.log
  Código de saída: 0 = nada pendente; 2 = trava impediu parte da remoção; 3 = sobrou item MANUAL
  ou que falhou; 1 = erro inesperado.

.PARAMETER Executar
  Remove de verdade. Sem ele, só simula.

.PARAMETER IncluirSplashtop
  Também remove o Splashtop (desliga o acesso remoto integrado do RMM nesta máquina).

.PARAMETER ServicosAntivirusOficial
  Serviços do antivírus que deve ficar. Antivírus de terceiros só são removidos se um deles estiver rodando.

.PARAMETER Protegidos
  Regex de nomes que nunca são removidos (RMM e antivírus oficial).

.EXAMPLE
  # Inventário (simulação):
  .\remover-acesso-remoto-e-antivirus.ps1
  # Remoção:
  .\remover-acesso-remoto-e-antivirus.ps1 -Executar
#>
param(
  [switch]$Executar,
  [switch]$IncluirSplashtop,
  [string[]]$ServicosAntivirusOficial = @('SentinelAgent', 'SentinelStaticEngine'),
  [string]$Protegidos = 'SentinelOne|Sentinel Agent|Atera'
)

$ErrorActionPreference = 'Stop'
$log = Join-Path $env:ProgramData 'AcessoRemoto\meshcentral-instalacao.log'
New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null
function Write-Log([string]$msg) {
  $linha = "{0:yyyy-MM-dd HH:mm:ss} [limpeza] {1}" -f (Get-Date), $msg
  Add-Content -Path $log -Value $linha -Encoding UTF8
  Write-Output $linha
}

# ── O que procurar (DisplayName, sem diferenciar maiúsculas) ─────────────────
$acessoRemoto = @(
  'AnyDesk', 'TeamViewer', 'RustDesk', 'UltraViewer', 'Chrome Remote Desktop',
  'RealVNC', 'VNC Server', 'VNC Viewer', 'TightVNC', 'UltraVNC', 'TigerVNC',
  'LogMeIn', 'GoTo Resolve', 'GoToAssist', 'ScreenConnect', 'ConnectWise Control',
  'Supremo', 'Ammyy', 'RemotePC', 'Zoho Assist', 'DameWare', 'NoMachine', 'Radmin',
  'AeroAdmin', 'HopToDesk', 'Parsec'
)
if ($IncluirSplashtop) { $acessoRemoto += 'Splashtop' }

$antivirus = @(
  'Avast', '\bAVG\b', 'McAfee', 'ESET', 'Norton', 'Kaspersky', 'Bitdefender', 'Avira',
  'Trend Micro', 'Sophos', 'Malwarebytes', 'Panda Dome', 'Panda Free Antivirus', 'Panda Security',
  'Webroot', 'Comodo', 'TotalAV', '360 Total Security'
)

# Nunca tocar (vale mesmo que case com as listas acima)
$protegidos = "$Protegidos|Mesh Agent|MeshCentral|Microsoft Defender|Windows Defender" +
              $(if ($IncluirSplashtop) { '' } else { '|Splashtop' })

# Dica de remoção manual quando o silencioso falha
$manual = [ordered]@{
  'McAfee'     = 'McAfee Consumer Product Removal (MCPR): https://www.mcafee.com/support/s/article/000001616'
  'Avast'      = 'avastclear.exe (rodar em modo seguro): https://www.avast.com/uninstall-utility'
  '\bAVG\b'    = 'AVG Clear (rodar em modo seguro): https://www.avg.com/en-us/uninstallation-tool'
  'Norton'     = 'Norton Remove and Reinstall: https://support.norton.com/sp/en/us/home/current/solutions/kb20080710133834EN'
  'ESET'       = 'ESET Uninstaller (modo seguro) ou senha de proteção da política: https://support.eset.com/en/kb2289'
  'Kaspersky'  = 'kavremover: https://support.kaspersky.com/common/uninstall/1464'
  'Bitdefender'= 'Bitdefender Uninstall Tool: https://www.bitdefender.com/consumer/support/answer/2791/'
}

# ── Inventário ────────────────────────────────────────────────────────────────
$chaves = @(
  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$instalados = foreach ($k in $chaves) {
  Get-ItemProperty -Path $k -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName }
}

function Find-Categoria($nome) {
  if ($nome -match $protegidos) { return $null }
  foreach ($p in $acessoRemoto) { if ($nome -match $p) { return 'acesso-remoto' } }
  foreach ($p in $antivirus)    { if ($nome -match $p) { return 'antivirus' } }
  return $null
}

$alvos = $instalados | ForEach-Object {
  $cat = Find-Categoria $_.DisplayName
  if ($cat) { [pscustomobject]@{ Nome = $_.DisplayName; Versao = $_.DisplayVersion; Categoria = $cat
      Uninstall = $_.UninstallString; Quiet = $_.QuietUninstallString; Chave = $_.PSChildName } }
} | Sort-Object Categoria, Nome -Unique

$modo = if ($Executar) { 'EXECUÇÃO' } else { 'SIMULAÇÃO (use -Executar para remover)' }
Write-Log "$env:COMPUTERNAME - $modo - $(@($alvos).Count) item(ns) encontrado(s)."
if (-not $alvos) { Write-Log 'Nada a remover.'; exit 0 }
$alvos | ForEach-Object { Write-Log ("  [{0}] {1} {2}" -f $_.Categoria, $_.Nome, $_.Versao) }

# ── Travas ────────────────────────────────────────────────────────────────────
function Test-Running($nome) { $s = Get-Service -Name $nome -ErrorAction SilentlyContinue; return ($s -and $s.Status -eq 'Running') }
$meshOk = Test-Running 'Mesh Agent'
$s1Ok   = [bool]($ServicosAntivirusOficial | Where-Object { Test-Running $_ })
$bloqueado = $false
if (-not $meshOk -and ($alvos | Where-Object Categoria -eq 'acesso-remoto')) {
  Write-Log 'TRAVA: Mesh Agent não está rodando. Acesso remoto NÃO será removido (instale o agente do MeshCentral antes).'
  $alvos = $alvos | Where-Object Categoria -ne 'acesso-remoto'; $bloqueado = $true
}
if (-not $s1Ok -and ($alvos | Where-Object Categoria -eq 'antivirus')) {
  Write-Log 'TRAVA: antivírus oficial não está rodando. Antivírus NÃO será removido (a máquina ficaria sem proteção).'
  $alvos = $alvos | Where-Object Categoria -ne 'antivirus'; $bloqueado = $true
}
if (-not $Executar) { Write-Log 'Simulação concluída. Nada foi removido.'; exit $(if ($bloqueado) { 2 } else { 0 }) }

# ── Remoção ───────────────────────────────────────────────────────────────────
function Split-Command([string]$cmd) {
  $cmd = $cmd.Trim()
  if ($cmd -match '^"([^"]+)"\s*(.*)$') { return @($matches[1], $matches[2]) }
  if ($cmd -match '^(\S+\.exe)\s*(.*)$') { return @($matches[1], $matches[2]) }
  return @($cmd, '')
}

$pendentes = @()
foreach ($a in $alvos) {
  try {
    # fecha o programa antes (acesso remoto costuma ficar aberto na bandeja)
    $proc = ($a.Nome -split '\s')[0]
    Get-Process -Name "$proc*" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    $cmd = $null; $args_ = $null
    if ($a.Nome -match 'AnyDesk' -and $a.Uninstall) {
      $exe = (Split-Command $a.Uninstall)[0]; $cmd = $exe; $args_ = '--remove'
    }
    elseif ($a.Uninstall -match 'msiexec' -and $a.Uninstall -match '(\{[0-9A-Fa-f\-]{36}\})') {
      $cmd = "$env:SystemRoot\System32\msiexec.exe"; $args_ = "/x $($matches[1]) /qn /norestart"
    }
    elseif ($a.Quiet) {
      $parts = Split-Command $a.Quiet; $cmd = $parts[0]; $args_ = $parts[1]
    }
    elseif ($a.Uninstall) {
      $parts = Split-Command $a.Uninstall; $cmd = $parts[0]
      if ($cmd -match 'unins\d{3}\.exe$') { $args_ = "$($parts[1]) /VERYSILENT /SUPPRESSMSGBOXES /NORESTART".Trim() }
      else { $args_ = "$($parts[1]) /S".Trim() }   # NSIS e afins
    }
    if (-not $cmd -or -not (Test-Path $cmd)) { throw 'sem desinstalador conhecido' }

    Write-Log "Removendo [$($a.Categoria)] $($a.Nome): $cmd $args_"
    $p = Start-Process -FilePath $cmd -ArgumentList $args_ -Wait -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 5

    $ainda = foreach ($k in $chaves) { Get-ItemProperty -Path $k -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq $a.Chave } }
    if ($ainda) { throw "continua instalado (código $($p.ExitCode))" }
    Write-Log "  OK: $($a.Nome) removido (código $($p.ExitCode))."
  }
  catch {
    $dica = ($manual.Keys | Where-Object { $a.Nome -match $_ } | ForEach-Object { $manual[$_] } | Select-Object -First 1)
    Write-Log "  MANUAL: $($a.Nome) - $($_.Exception.Message)$(if ($dica) { ". Use: $dica" })"
    $pendentes += $a.Nome
  }
}

if ($pendentes) { Write-Log "Pendentes em ${env:COMPUTERNAME}: $($pendentes -join ', '). Pode haver reinício pendente."; exit 3 }
Write-Log "Concluído em $env:COMPUTERNAME. Pode haver reinício pendente."
exit $(if ($bloqueado) { 2 } else { 0 })
