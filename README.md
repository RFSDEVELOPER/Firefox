# Manutenção Windows + Firefox

Script PowerShell que automatiza a manutenção do Windows e do Firefox: desativa o *Active Probing* do Windows, atualiza o Firefox, limpa o cache sem perder configurações importantes, remove o pop-up de *captive portal* e aplica ajustes de desempenho.

> ⚠️ **Executar como Administrador.** O script altera o registro do Windows (`HKLM`) e arquivos de perfil do Firefox.

---

## O que o script faz

| # | Etapa | Detalhes |
|---|-------|----------|
| 1 | **Active Probing** | Faz backup da chave do registro e define `EnableActiveProbing = 0` em `HKLM\SYSTEM\CurrentControlSet\Services\NlaSvc\Parameters\Internet`. Reinicia o serviço `NlaSvc`. |
| 2 | **Hibernação** | Executa `powercfg /hibernate off` (opcional). |
| 3 | **Fechar o Firefox** | Tenta fechar normalmente; só força o encerramento se necessário. |
| 4 | **Atualização** | Atualiza o Firefox via `winget` (`Mozilla.Firefox`). |
| 5 | **Limpeza de cache** | Remove apenas `cache2` e `startupCache`. **Não** apaga cookies, configurações de sites nem exceções de certificado. |
| 6 | **Certificado** | Verifica se a exceção `cportalacad.unoeste.br:6082` está salva no `cert_override.txt` e faz cópia de segurança do arquivo. |
| 7 | **Preferências (`user.js`)** | Página inicial em vez de "abrir a última página", captive portal desativado e ajustes de desempenho. |
| 8 | **Políticas do Firefox** | Política de atualização, `CaptivePortal`, telemetria, estudos e páginas extras. |
| 9 | **Verificação final** | Exibe os valores aplicados. |

---

## Requisitos

- Windows 10 ou 11
- PowerShell 5.1 ou superior
- Firefox instalado (instalação para todos os usuários em `Program Files`, ou em `%LOCALAPPDATA%`)
- `winget` (opcional; sem ele, a etapa de atualização é ignorada)

---

## Como usar

1. Baixe `Manutencao_Windows_Firefox.ps1`.
2. Abra o PowerShell **como administrador**.
3. Execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\Manutencao_Windows_Firefox.ps1
```

4. Ao terminar, **reinicie o computador**.

> O arquivo usa codificação **UTF-8 com BOM** para que o PowerShell 5.1 exiba os acentos corretamente. Mantenha essa codificação ao editar.

---

## Configuração

As opções ficam no topo do script:

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `$ModoAtualizacaoFirefox` | `"Verificar"` | Política de atualização (veja abaixo). |
| `$DesativarHibernacao` | `$true` | Executa `powercfg /hibernate off`. |
| `$NaoAbrirUltimaPagina` | `$true` | Define `browser.startup.page = 1` (abre a página inicial). |
| `$EnderecoCertificado` | `"cportalacad.unoeste.br:6082"` | Endereço procurado nas exceções de certificado. |
| `$DesativarCaptivePortal` | `$true` | Remove o pop-up "Fazer login na rede". |
| `$OtimizarDesempenho` | `$true` | Aplica ajustes de abertura e carregamento mais rápidos. |

### Modos de atualização

| Modo | Procura atualizações | Instala sozinho | Política aplicada |
|------|:---:|:---:|-------------------|
| `"Bloquear"` | Não | Não | `DisableAppUpdate = 1` |
| `"Verificar"` | Sim | Não (você escolhe) | `AppAutoUpdate = 0` |
| `"Automatico"` | Sim | Sim | Nenhuma (remove as políticas) |

> A etapa do `winget` roda **antes** da política ser aplicada e não é afetada por ela.

---

## Ajustes de desempenho aplicados

- Sem páginas de boas-vindas, "novidades" após atualização e verificação de navegador padrão
- Sem conteúdo patrocinado na nova aba e na barra de endereço
- Telemetria e estudos desativados (políticas)
- Salvamento de sessão a cada 60 s (menos gravações em disco)
- 10 conexões persistentes por servidor e cache de DNS ampliado (2000 entradas, 1 h)
- Descarregamento de abas inativas em caso de pouca memória

As preferências ficam em um bloco delimitado no `user.js` de cada perfil:

```
// >>> MANUTENCAO_FIREFOX (gerenciado pelo script)
...
// <<< MANUTENCAO_FIREFOX
```

Executar o script novamente atualiza esse bloco, sem duplicar linhas.

---

## Arquivos gerados

| Arquivo | Conteúdo |
|---------|----------|
| `C:\NlaSvc_Internet_Backup.reg` | Backup da chave do registro do NlaSvc |
| `C:\Backup_Firefox_Certs\` | Cópia dos `cert_override.txt` de cada perfil |
| `C:\Manutencao_Firefox_AAAAMMDD_HHMMSS.log` | Log completo da execução |

---

## Como reverter

**Active Probing**

```powershell
reg import C:\NlaSvc_Internet_Backup.reg
```

**Hibernação**

```powershell
powercfg /hibernate on
```

**Políticas do Firefox**: execute o script com `$ModoAtualizacaoFirefox = "Automatico"` e `$DesativarCaptivePortal = $false`, ou remova a chave:

```powershell
Remove-Item "HKLM:\SOFTWARE\Policies\Mozilla\Firefox" -Recurse
```

**Preferências do `user.js`**: apague o bloco entre `MANUTENCAO_FIREFOX` em `%APPDATA%\Mozilla\Firefox\Profiles\<perfil>\user.js` (com o Firefox fechado).

---

## Observações

- A exceção de certificado **não é criada** pelo script, apenas verificada. Se não for encontrada, adicione em: *Configurações → Privacidade e segurança → Ver certificados → Servidores → Adicionar exceção*.
- Ao limpar o cache manualmente no Firefox, deixe **"Configurações de sites"** desmarcada, pois ela apaga as exceções de certificado.
- Em redes com proxy ou WPAD, avalie a configuração de proxy do Firefox, pois a detecção automática pode atrasar a primeira página.
- As alterações de registro e de política exigem reiniciar o computador para efeito completo.

---

## Aviso

Use por sua conta e risco. Teste primeiro em uma máquina não crítica. O script altera configurações do sistema e do navegador.

## Licença

Defina a licença do projeto (por exemplo, MIT).
