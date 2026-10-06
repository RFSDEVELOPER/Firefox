\xEF\xBB\xBF# ==========================================================
# MANUTENÇÃO WINDOWS + FIREFOX  (v2)
# Executar como ADMINISTRADOR
# ==========================================================
# 1. Backup + EnableActiveProbing = 0 + reinicia NlaSvc
# 2. Desativa hibernação (powercfg -h off)
# 3. Fecha o Firefox
# 4. Atualiza pelo Winget
# 5. Limpa SOMENTE o cache (preserva cookies, configurações
#    de sites e exceções de certificado)
# 6. Verifica exceção de certificado (cportalacad.unoeste.br:6082)
# 7. Ajusta "ao iniciar" para NÃO abrir a última página
# 8. Política de atualização do Firefox
# 9. Verificação final
# ==========================================================

# ---------------- CONFIGURAÇÃO ----------------
# "Bloquear"   = bloqueia totalmente (DisableAppUpdate=1)
# "Verificar"  = verifica, mas você escolhe quando instalar
# "Automatico" = atualizações automáticas (padrão do Firefox)
$ModoAtualizacaoFirefox = "Verificar"

$DesativarHibernacao   = $true
$NaoAbrirUltimaPagina  = $true      # startup.page = 1 (página inicial)
$EnderecoCertificado   = "cportalacad.unoeste.br:6082"
# ----------------------------------------------

$ErrorActionPreference = "Continue"
$logPath = "$env:SystemDrive\Manutencao_Firefox_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logPath | Out-Null

Write-Host "`n=== MANUTENÇÃO WINDOWS + FIREFOX ===`n" -ForegroundColor Cyan

# ---------- Verificar administrador ----------
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "ERRO: execute como ADMINISTRADOR." -ForegroundColor Red
    Stop-Transcript | Out-Null
    Pause
    exit 1
}

# ==========================================================
# [1/9] ACTIVE PROBING
# ==========================================================
Write-Host "[1/9] Configurando Active Probing..." -ForegroundColor Yellow

$regPath    = "HKLM:\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
$regExport  = "HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet"
$backupPath = "$env:SystemDrive\NlaSvc_Internet_Backup.reg"

# Backup ANTES de alterar (só se a chave já existir)
if (Test-Path $regPath) {
    reg.exe export $regExport $backupPath /y | Out-Null
    Write-Host "Backup salvo em: $backupPath" -ForegroundColor Green
} else {
    New-Item -Path $regPath -Force | Out-Null
    Write-Host "Chave não existia; criada (sem backup prévio)." -ForegroundColor Yellow
}

Set-ItemProperty -Path $regPath -Name "EnableActiveProbing" -Value 0 -Type DWord
Write-Host "EnableActiveProbing = 0" -ForegroundColor Green

try {
    Restart-Service -Name NlaSvc -Force -ErrorAction Stop
    Write-Host "Serviço NlaSvc reiniciado." -ForegroundColor Green
} catch {
    Write-Host "Não foi possível reiniciar o NlaSvc (será aplicado após reiniciar o PC)." -ForegroundColor Red
}

# ==========================================================
# [2/9] HIBERNAÇÃO
# ==========================================================
Write-Host "`n[2/9] Hibernação..." -ForegroundColor Yellow
if ($DesativarHibernacao) {
    powercfg.exe /hibernate off
    Write-Host "Hibernação desativada." -ForegroundColor Green
} else {
    Write-Host "Ignorado (configuração desativada)." -ForegroundColor Gray
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
else          { Write-Host "Firefox não encontrado." -ForegroundColor Red }

$procs = Get-Process firefox -ErrorAction SilentlyContinue
if ($procs) {
    # Primeiro tenta fechar normalmente (preserva dados da sessão)
    $procs | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 8
    if (Get-Process firefox -ErrorAction SilentlyContinue) {
        Stop-Process -Name firefox -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        Write-Host "Firefox encerrado à força." -ForegroundColor Yellow
    } else {
        Write-Host "Firefox fechado normalmente." -ForegroundColor Green
    }
} else {
    Write-Host "Firefox não está em execução." -ForegroundColor Green
}

# ==========================================================
# [4/9] ATUALIZAR PELO WINGET
# ==========================================================
Write-Host "`n[4/9] Atualizando Firefox (winget)..." -ForegroundColor Yellow

if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    winget upgrade --id Mozilla.Firefox -e --silent `
        --accept-package-agreements --accept-source-agreements
    Write-Host "Winget finalizado (código $LASTEXITCODE)." -ForegroundColor Gray
} else {
    Write-Host "Winget não encontrado. Atualize manualmente: Menu > Ajuda > Sobre o Firefox." -ForegroundColor Yellow
}

# ==========================================================
# [5/9] LIMPAR CACHE (somente cache2)
# ==========================================================
Write-Host "`n[5/9] Limpando cache..." -ForegroundColor Yellow
Write-Host "(Cookies, configurações de sites e certificados NÃO são tocados)" -ForegroundColor Gray

$localProfiles = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $localProfiles) {
    Get-ChildItem $localProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $cache = Join-Path $_.FullName "cache2"
        if (Test-Path $cache) {
            Remove-Item $cache -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cache limpo: $($_.Name)" -ForegroundColor Gray
        }
    }
    Write-Host "Cache tratado." -ForegroundColor Green
} else {
    Write-Host "Pasta de perfis não encontrada." -ForegroundColor Yellow
}

# ==========================================================
# [6/9] VERIFICAR EXCEÇÃO DE CERTIFICADO
# ==========================================================
Write-Host "`n[6/9] Verificando exceção de certificado..." -ForegroundColor Yellow

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
    Write-Host "ATENÇÃO: exceção para $EnderecoCertificado NÃO encontrada." -ForegroundColor Red
    Write-Host "Firefox > Configurações > Privacidade > Certificados > Ver certificados > Servidores" -ForegroundColor Yellow
    Write-Host "Acesse o endereço (cportalacad, não cportal) e adicione a exceção." -ForegroundColor Yellow
}

# ==========================================================
# [7/9] "AO INICIAR": NÃO ABRIR A ÚLTIMA PÁGINA
# ==========================================================
Write-Host "`n[7/9] Configuração de inicialização..." -ForegroundColor Yellow

if ($NaoAbrirUltimaPagina -and (Test-Path $roamProfiles)) {
    Get-ChildItem $roamProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $userJs = Join-Path $_.FullName "user.js"
        $linha  = 'user_pref("browser.startup.page", 1);'
        $atual  = if (Test-Path $userJs) { Get-Content $userJs -ErrorAction SilentlyContinue } else { @() }
        $atual  = @($atual | Where-Object { $_ -notmatch 'browser\.startup\.page' })
        Set-Content -Path $userJs -Value ($atual + $linha) -Encoding ASCII
        Write-Host "startup.page = 1 em $($_.Name)" -ForegroundColor Gray
    }
    Write-Host "Firefox abrirá a página inicial (não a última sessão)." -ForegroundColor Green
} else {
    Write-Host "Ignorado." -ForegroundColor Gray
}

# ==========================================================
# [8/9] POLÍTICA DE ATUALIZAÇÃO
# ==========================================================
Write-Host "`n[8/9] Política de atualização: $ModoAtualizacaoFirefox" -ForegroundColor Yellow

$pol = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"

switch ($ModoAtualizacaoFirefox) {
    "Bloquear" {
        New-Item -Path $pol -Force | Out-Null
        New-ItemProperty -Path $pol -Name "DisableAppUpdate" -PropertyType DWord -Value 1 -Force | Out-Null
        Remove-ItemProperty -Path $pol -Name "AppAutoUpdate" -ErrorAction SilentlyContinue
        Write-Host "Atualizações BLOQUEADAS totalmente." -ForegroundColor Yellow
    }
    "Verificar" {
        # Equivale a "Verificar se há atualizações, mas escolher quando instalar"
        New-Item -Path $pol -Force | Out-Null
        New-ItemProperty -Path $pol -Name "AppAutoUpdate" -PropertyType DWord -Value 0 -Force | Out-Null
        Remove-ItemProperty -Path $pol -Name "DisableAppUpdate" -ErrorAction SilentlyContinue
        Write-Host "Verifica atualizações, mas você escolhe quando instalar." -ForegroundColor Green
    }
    "Automatico" {
        if (Test-Path $pol) {
            Remove-ItemProperty -Path $pol -Name "DisableAppUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $pol -Name "AppAutoUpdate"    -ErrorAction SilentlyContinue
        }
        Write-Host "Atualizações automáticas habilitadas." -ForegroundColor Green
    }
    default {
        Write-Host "Modo inválido: use Bloquear, Verificar ou Automatico." -ForegroundColor Red
    }
}

# ==========================================================
# [9/9] VERIFICAÇÃO FINAL
# ==========================================================
Write-Host "`n[9/9] Verificação final" -ForegroundColor Yellow
Write-Host "---------------------------------------------"

$ap = Get-ItemPropertyValue -Path $regPath -Name "EnableActiveProbing" -ErrorAction SilentlyContinue
Write-Host "EnableActiveProbing   = $ap"

$dis = Get-ItemPropertyValue -Path $pol -Name "DisableAppUpdate" -ErrorAction SilentlyContinue
$aut = Get-ItemPropertyValue -Path $pol -Name "AppAutoUpdate"    -ErrorAction SilentlyContinue
Write-Host "DisableAppUpdate      = $(if ($null -eq $dis) {'(não definido)'} else {$dis})"
Write-Host "AppAutoUpdate         = $(if ($null -eq $aut) {'(não definido)'} else {$aut})"
Write-Host "Certificado $EnderecoCertificado : $(if ($certOk) {'OK'} else {'NÃO ENCONTRADO'})"

Write-Host "`n=== PROCEDIMENTO CONCLUÍDO ===" -ForegroundColor Cyan
Write-Host "Backup do registro : $backupPath"
Write-Host "Log                : $logPath"
Write-Host "Recomenda-se reiniciar o computador." -ForegroundColor Yellow

Stop-Transcript | Out-Null
Pause
