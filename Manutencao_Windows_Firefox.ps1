# ==========================================================
# MANUTENÃ‡ÃƒO WINDOWS + FIREFOX  (v2)
# Executar como ADMINISTRADOR
# ==========================================================
# 1. Backup + EnableActiveProbing = 0 + reinicia NlaSvc
# 2. Desativa hibernaÃ§Ã£o (powercfg -h off)
# 3. Fecha o Firefox
# 4. Atualiza pelo Winget
# 5. Limpa SOMENTE o cache (preserva cookies, configuraÃ§Ãµes
#    de sites e exceÃ§Ãµes de certificado)
# 6. Verifica exceÃ§Ã£o de certificado (cportalacad.unoeste.br:6082)
# 7. Ajusta "ao iniciar" para NÃƒO abrir a Ãºltima pÃ¡gina
# 8. PolÃ­tica de atualizaÃ§Ã£o do Firefox
# 9. VerificaÃ§Ã£o final
# ==========================================================

# ---------------- CONFIGURAÃ‡ÃƒO ----------------
# "Bloquear"   = bloqueia totalmente (DisableAppUpdate=1)
# "Verificar"  = verifica, mas vocÃª escolhe quando instalar
# "Automatico" = atualizaÃ§Ãµes automÃ¡ticas (padrÃ£o do Firefox)
$ModoAtualizacaoFirefox = "Verificar"

$DesativarHibernacao   = $true
$NaoAbrirUltimaPagina  = $true      # startup.page = 1 (pÃ¡gina inicial)
$EnderecoCertificado   = "cportalacad.unoeste.br:6082"
$DesativarCaptivePortal = $true     # remove o pop-up "Fazer login na rede"
$OtimizarDesempenho     = $true     # abertura e carregamento mais rÃ¡pidos
# ----------------------------------------------

$ErrorActionPreference = "Continue"
$logPath = "$env:SystemDrive\Manutencao_Firefox_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logPath | Out-Null

Write-Host "`n=== MANUTENÃ‡ÃƒO WINDOWS + FIREFOX ===`n" -ForegroundColor Cyan

# ---------- Verificar administrador ----------
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERRO: execute como ADMINISTRADOR." -ForegroundColor Red
    Stop-Transcript | Out-Null
    Pause
    return
}

# ==========================================================
# [1/9] ACTIVE PROBING
# ==========================================================
Write-Host "[1/9] Configurando Active Probing..." -ForegroundColor Yellow

$regPath    = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
$regExport  = "HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
$backupPath = "$env:SystemDrive\NlaSvc_Internet_Backup.reg"

# Backup ANTES de alterar (sÃ³ se a chave jÃ¡ existir)
if (Test-Path $regPath) {
    reg.exe export $regExport $backupPath /y | Out-Null
    Write-Host "Backup salvo em: $backupPath" -ForegroundColor Green
} else {
    New-Item -Path $regPath -Force | Out-Null
    Write-Host "Chave nÃ£o existia; criada (sem backup prÃ©vio)." -ForegroundColor Yellow
}

Set-ItemProperty -Path $regPath -Name "EnableActiveProbing" -Value 0 -Type DWord
Write-Host "EnableActiveProbing = 0" -ForegroundColor Green

try {
    Restart-Service -Name NlaSvc -Force -ErrorAction Stop
    Write-Host "ServiÃ§o NlaSvc reiniciado." -ForegroundColor Green
} catch {
    Write-Host "NlaSvc nÃ£o reiniciou: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "O valor jÃ¡ foi gravado; vale apÃ³s reiniciar o PC." -ForegroundColor Yellow
}

# ==========================================================
# [2/9] HIBERNAÃ‡ÃƒO
# ==========================================================
Write-Host "`n[2/9] HibernaÃ§Ã£o..." -ForegroundColor Yellow
if ($DesativarHibernacao) {
    powercfg.exe /hibernate off
    Write-Host "HibernaÃ§Ã£o desativada." -ForegroundColor Green
} else {
    Write-Host "Ignorado (configuraÃ§Ã£o desativada)." -ForegroundColor Gray
}

# ==========================================================
# [3/9] LOCALIZAR E FECHAR FIREFOX
# ==========================================================
Write-Host "`n[3/9] Localizando e fechando o Firefox..." -ForegroundColor Yellow

$firefox = @(
    "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
    "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe",
    "$env:LOCALAPPDATA\Mozilla Firefox\firefox.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($firefox) { Write-Host "Firefox encontrado: $firefox" -ForegroundColor Green }
else          { Write-Host "Firefox nÃ£o encontrado." -ForegroundColor Red }

$procs = Get-Process firefox -ErrorAction SilentlyContinue
if ($procs) {
    # Primeiro tenta fechar normalmente (preserva dados da sessÃ£o)
    $procs | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 8
    if (Get-Process firefox -ErrorAction SilentlyContinue) {
        Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "Firefox encerrado Ã  forÃ§a." -ForegroundColor Yellow
    } else {
        Write-Host "Firefox fechado normalmente." -ForegroundColor Green
    }
} else {
    Write-Host "Firefox nÃ£o estÃ¡ em execuÃ§Ã£o." -ForegroundColor Green
}

# ==========================================================
# [4/9] ATUALIZAR PELO WINGET
# ==========================================================
Write-Host "`n[4/9] Atualizando Firefox (winget)..." -ForegroundColor Yellow

if (-not $firefox) {
    Write-Host "Firefox nÃ£o estÃ¡ instalado neste computador; etapa ignorada." -ForegroundColor Yellow
} elseif (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    winget upgrade --id Mozilla.Firefox -e --source winget --silent `
        --accept-package-agreements --accept-source-agreements
    switch ($LASTEXITCODE) {
        0            { Write-Host "Firefox atualizado." -ForegroundColor Green }
        -1978335189  { Write-Host "Firefox jÃ¡ estÃ¡ na versÃ£o mais recente." -ForegroundColor Green }
        -1978335212  { Write-Host "O winget nÃ£o reconhece esta instalaÃ§Ã£o (instalada por outro meio). Atualize em Ajuda > Sobre o Firefox." -ForegroundColor Yellow }
        default      { Write-Host "Winget finalizado (cÃ³digo $LASTEXITCODE)." -ForegroundColor Gray }
    }
} else {
    Write-Host "Winget nÃ£o encontrado. Atualize manualmente: Menu > Ajuda > Sobre o Firefox." -ForegroundColor Yellow
}

# ==========================================================
# [5/9] LIMPAR CACHE (somente cache2)
# ==========================================================
Write-Host "`n[5/9] Limpando cache..." -ForegroundColor Yellow
Write-Host "(Cookies, configuraÃ§Ãµes de sites e certificados NÃƒO sÃ£o tocados)" -ForegroundColor Gray

$localProfiles = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $localProfiles) {
    Get-ChildItem $localProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $cache = Join-Path $_.FullName "cache2"
        if (Test-Path $cache) {
            Remove-Item $cache -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cache limpo: $($_.Name)" -ForegroundColor Gray
        }
        $sc = Join-Path $_.FullName "startupCache"
        if (Test-Path $sc) { Remove-Item $sc -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Write-Host "Cache tratado." -ForegroundColor Green
} else {
    Write-Host "Pasta de perfis nÃ£o encontrada." -ForegroundColor Yellow
}

# ==========================================================
# [6/9] VERIFICAR EXCEÃ‡ÃƒO DE CERTIFICADO
# ==========================================================
Write-Host "`n[6/9] Verificando exceÃ§Ã£o de certificado..." -ForegroundColor Yellow

$roamProfiles = "$env:APPDATA\Mozilla\Firefox\Profiles"
$certOk = $false
if (Test-Path $roamProfiles) {
    $certBackupDir = "$env:SystemDrive\Backup_Firefox_Certs"
    New-Item -ItemType Directory -Path $certBackupDir -Force | Out-Null

    Get-ChildItem $roamProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $certFile = Join-Path $_.FullName "cert_override.txt"
        if (Test-Path $certFile) {
            Copy-Item $certFile (Join-Path $certBackupDir "$($_.Name)_cert_override.txt") -Force
            if (Select-String -Path $certFile -Pattern $EnderecoCertificado -SimpleMatch -Quiet) {
                $certOk = $true
                Write-Host "OK: $EnderecoCertificado encontrado em $($_.Name)" -ForegroundColor Green
            }
        }
    }
}
if (-not $certOk) {
    Write-Host "ATENÃ‡ÃƒO: exceÃ§Ã£o para $EnderecoCertificado NÃƒO encontrada." -ForegroundColor Red
    Write-Host "Firefox > ConfiguraÃ§Ãµes > Privacidade > Certificados > Ver certificados > Servidores" -ForegroundColor Yellow
    Write-Host "Acesse o endereÃ§o (cportalacad, nÃ£o cportal) e adicione a exceÃ§Ã£o." -ForegroundColor Yellow
}

# ==========================================================
# [7/9] PREFERÃŠNCIAS (user.js): inicializaÃ§Ã£o, captive portal, desempenho
# ==========================================================
Write-Host "`n[7/9] Aplicando preferÃªncias nos perfis..." -ForegroundColor Yellow

$prefs = [ordered]@{}

if ($NaoAbrirUltimaPagina) {
    $prefs['browser.startup.page'] = '1'
}

if ($DesativarCaptivePortal) {
    $prefs['network.captive-portal-service.enabled'] = 'false'
    $prefs['network.connectivity-service.enabled']   = 'false'
}

if ($OtimizarDesempenho) {
    # Abertura mais rÃ¡pida: sem pÃ¡ginas de boas-vindas/novidades e sem conteÃºdo patrocinado
    $prefs['browser.startup.homepage_override.mstone']                        = '"ignore"'
    $prefs['startup.homepage_welcome_url']                                    = '""'
    $prefs['startup.homepage_welcome_url.additional']                         = '""'
    $prefs['browser.aboutwelcome.enabled']                                    = 'false'
    $prefs['browser.shell.checkDefaultBrowser']                               = 'false'
    $prefs['browser.discovery.enabled']                                       = 'false'
    $prefs['extensions.htmlaboutaddons.recommendations.enabled']              = 'false'
    $prefs['browser.newtabpage.activity-stream.feeds.section.topstories']     = 'false'
    $prefs['browser.newtabpage.activity-stream.feeds.snippets']               = 'false'
    $prefs['browser.newtabpage.activity-stream.showSponsored']                = 'false'
    $prefs['browser.newtabpage.activity-stream.showSponsoredTopSites']        = 'false'
    $prefs['browser.urlbar.suggest.quicksuggest.sponsored']                   = 'false'
    $prefs['browser.urlbar.suggest.quicksuggest.nonsponsored']                = 'false'
    # Menos gravaÃ§Ãµes em disco
    $prefs['browser.sessionstore.interval']                                   = '60000'
    # Carregamento mais rÃ¡pido: mais conexÃµes paralelas e cache de DNS maior
    $prefs['network.http.max-persistent-connections-per-server']              = '10'
    $prefs['network.dnsCacheEntries']                                         = '2000'
    $prefs['network.dnsCacheExpiration']                                      = '3600'
    # Libera memÃ³ria de abas inativas quando o PC estÃ¡ com pouca RAM
    $prefs['browser.tabs.unloadOnLowMemory']                                  = 'true'
}

$marcaIni = "// >>> MANUTENCAO_FIREFOX (gerenciado pelo script)"
$marcaFim = "// <<< MANUTENCAO_FIREFOX"

if ($prefs.Count -gt 0 -and (Test-Path $roamProfiles)) {
    Get-ChildItem $roamProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $userJs = Join-Path $_.FullName "user.js"
        $linhas = if (Test-Path $userJs) { @(Get-Content $userJs -ErrorAction SilentlyContinue) } else { @() }

        # Remove bloco anterior do script e a linha antiga da v1
        $limpo = @(); $dentro = $false
        foreach ($l in $linhas) {
            if ($l -eq $marcaIni) { $dentro = $true; continue }
            if ($l -eq $marcaFim) { $dentro = $false; continue }
            if (-not $dentro -and $l -notmatch 'browser\.startup\.page') { $limpo += $l }
        }

        $bloco = @($marcaIni)
        foreach ($k in $prefs.Keys) { $bloco += "user_pref(`"$k`", $($prefs[$k]));" }
        $bloco += $marcaFim

        Set-Content -Path $userJs -Value ($limpo + $bloco) -Encoding ASCII
        Write-Host "$($prefs.Count) preferÃªncias aplicadas em $($_.Name)" -ForegroundColor Gray
    }
    Write-Host "PreferÃªncias aplicadas (efeito na prÃ³xima abertura do Firefox)." -ForegroundColor Green
} else {
    Write-Host "Nada a aplicar." -ForegroundColor Gray
}

# ==========================================================
# [8/9] POLÃTICA DE ATUALIZAÃ‡ÃƒO
# ==========================================================
Write-Host "`n[8/9] PolÃ­tica de atualizaÃ§Ã£o: $ModoAtualizacaoFirefox" -ForegroundColor Yellow

$pol = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
New-Item -Path $pol -Force | Out-Null

# Pop-up de captive portal: polÃ­tica oficial (vale para todos os perfis)
if ($DesativarCaptivePortal) {
    New-ItemProperty -Path $pol -Name "CaptivePortal" -PropertyType DWord -Value 0 -Force | Out-Null
    Write-Host "PolÃ­tica CaptivePortal = 0 (pop-up desativado)." -ForegroundColor Green
} else {
    Remove-ItemProperty -Path $pol -Name "CaptivePortal" -ErrorAction SilentlyContinue
}

# PolÃ­ticas que aceleram a abertura (sem telemetria, estudos e pÃ¡ginas extras)
if ($OtimizarDesempenho) {
    foreach ($n in "DisableTelemetry","DisableFirefoxStudies","DontCheckDefaultBrowser") {
        New-ItemProperty -Path $pol -Name $n -PropertyType DWord -Value 1 -Force | Out-Null
    }
    foreach ($n in "OverrideFirstRunPage","OverridePostUpdatePage") {
        New-ItemProperty -Path $pol -Name $n -PropertyType String -Value "" -Force | Out-Null
    }
    Write-Host "PolÃ­ticas de desempenho aplicadas." -ForegroundColor Green
}


switch ($ModoAtualizacaoFirefox) {
    "Bloquear" {
        New-Item -Path $pol -Force | Out-Null
        New-ItemProperty -Path $pol -Name "DisableAppUpdate" -PropertyType DWord -Value 1 -Force | Out-Null
        Remove-ItemProperty -Path $pol -Name "AppAutoUpdate" -ErrorAction SilentlyContinue
        Write-Host "AtualizaÃ§Ãµes BLOQUEADAS totalmente." -ForegroundColor Yellow
    }
    "Verificar" {
        # Equivale a "Verificar se hÃ¡ atualizaÃ§Ãµes, mas escolher quando instalar"
        New-Item -Path $pol -Force | Out-Null
        New-ItemProperty -Path $pol -Name "AppAutoUpdate" -PropertyType DWord -Value 0 -Force | Out-Null
        Remove-ItemProperty -Path $pol -Name "DisableAppUpdate" -ErrorAction SilentlyContinue
        Write-Host "Verifica atualizaÃ§Ãµes, mas vocÃª escolhe quando instalar." -ForegroundColor Green
    }
    "Automatico" {
        if (Test-Path $pol) {
            Remove-ItemProperty -Path $pol -Name "DisableAppUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $pol -Name "AppAutoUpdate"    -ErrorAction SilentlyContinue
        }
        Write-Host "AtualizaÃ§Ãµes automÃ¡ticas habilitadas." -ForegroundColor Green
    }
    default {
        Write-Host "Modo invÃ¡lido: use Bloquear, Verificar ou Automatico." -ForegroundColor Red
    }
}

# ==========================================================
# [9/9] VERIFICAÃ‡ÃƒO FINAL
# ==========================================================
Write-Host "`n[9/9] VerificaÃ§Ã£o final" -ForegroundColor Yellow
Write-Host "---------------------------------------------"

$ap = (Get-ItemProperty -Path $regPath -Name "EnableActiveProbing" -ErrorAction SilentlyContinue).EnableActiveProbing
Write-Host "EnableActiveProbing   = $ap"

$dis = (Get-ItemProperty -Path $pol -Name "DisableAppUpdate" -ErrorAction SilentlyContinue).DisableAppUpdate
$aut = (Get-ItemProperty -Path $pol -Name "AppAutoUpdate" -ErrorAction SilentlyContinue).AppAutoUpdate
Write-Host "DisableAppUpdate      = $(if ($null -eq $dis) {'(nÃ£o definido)'} else {$dis})"
Write-Host "AppAutoUpdate         = $(if ($null -eq $aut) {'(nÃ£o definido)'} else {$aut})"
$cp = (Get-ItemProperty -Path $pol -Name "CaptivePortal" -ErrorAction SilentlyContinue).CaptivePortal
Write-Host "CaptivePortal         = $(if ($null -eq $cp) {'(nÃ£o definido)'} else {$cp})"
Write-Host "Certificado $EnderecoCertificado : $(if ($certOk) {'OK'} else {'NÃƒO ENCONTRADO'})"

Write-Host "`n=== PROCEDIMENTO CONCLUÃDO ===" -ForegroundColor Cyan
Write-Host "Backup do registro : $backupPath"
Write-Host "Log                : $logPath"
Write-Host "Recomenda-se reiniciar o computador." -ForegroundColor Yellow

Stop-Transcript | Out-Null
Pause
