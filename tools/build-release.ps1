$ErrorActionPreference='Stop'
$luaSpec=Get-Content -LiteralPath (Join-Path $PSScriptRoot '../release.json') -Raw | ConvertFrom-Json
$luaVersion=[Version]::Parse($luaSpec.version).ToString(3)
$luaTag='v'+$luaVersion
$luaExisting=gh release view $luaTag --repo $env:GITHUB_REPOSITORY --json isDraft 2>$null
if($LASTEXITCODE -eq 0 -and -not ($luaExisting|ConvertFrom-Json).isDraft){Write-Output ('A versão '+$luaTag+' já está publicada; atualizando somente a página.');exit 0}
$luaStage=Join-Path $env:RUNNER_TEMP ('lua-build-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $luaStage | Out-Null
function Assert-LuaStage([string]$Path){$luaResolved=[IO.Path]::GetFullPath($Path);$luaAllowed=[IO.Path]::GetFullPath($luaStage).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar;if(-not $luaResolved.StartsWith($luaAllowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Destino fora da pasta temporária de compilação.'}}
$luaSeed=Join-Path $luaStage 'seed.zip'
Invoke-WebRequest -Uri $luaSpec.base_package -OutFile $luaSeed
if((Get-FileHash -LiteralPath $luaSeed -Algorithm SHA256).Hash.ToLowerInvariant() -ne $luaSpec.base_sha256){throw 'O pacote base não passou na verificação.'}
$luaBase=Join-Path $luaStage 'base';Expand-Archive -LiteralPath $luaSeed -DestinationPath $luaBase
$luaRoot=Get-ChildItem -LiteralPath $luaBase -Directory | Where-Object {Test-Path -LiteralPath (Join-Path $_.FullName 'LUA.exe')}
if(@($luaRoot).Count -ne 1){throw 'Pacote base inválido.'}
$luaApp=Join-Path $luaStage ('LUA-'+$luaVersion)
Assert-LuaStage $luaRoot.FullName;Assert-LuaStage $luaApp
Move-Item -LiteralPath $luaRoot.FullName -Destination $luaApp
$luaSources=Join-Path $luaStage 'sources';Expand-Archive -LiteralPath (Join-Path $PSScriptRoot '../lua-source.zip') -DestinationPath $luaSources
foreach($luaFolder in @('src','icons','previews')){$luaTarget=Join-Path $luaApp $luaFolder;Assert-LuaStage $luaTarget;if(Test-Path -LiteralPath $luaTarget){Remove-Item -LiteralPath $luaTarget -Recurse -Force}}
Copy-Item -Path (Join-Path $luaSources 'app/*') -Destination $luaApp -Recurse -Force
& (Join-Path $luaApp 'build.ps1')
if([Version]::Parse((Get-Item -LiteralPath (Join-Path $luaApp 'LUA.exe')).VersionInfo.FileVersion).ToString(3) -ne $luaVersion){throw 'A versão compilada difere de release.json.'}
$luaChecks=Join-Path $luaStage 'checks'
$luaProcess=Start-Process -FilePath (Join-Path $luaApp 'LUA.exe') -ArgumentList @('--verify-package','--data',('"'+$luaChecks+'"')) -WindowStyle Hidden -Wait -PassThru
if($luaProcess.ExitCode -ne 0 -or -not (Select-String -LiteralPath (Join-Path $luaChecks 'package-checks.txt') -SimpleMatch 'RESULTADO: PASSOU')){throw 'Verificação do pacote falhou.'}
Copy-Item -LiteralPath (Join-Path $luaChecks 'package-checks.txt') -Destination (Join-Path $luaApp 'VERIFICACAO-CI.txt')
$luaSensorHost=Join-Path $luaApp 'LuaSensorsHost.exe'
function Invoke-LuaSensorHost([string]$Argument){$luaErrorLog=Join-Path $luaStage 'sensor-errors.txt';$luaSensorProcess=Start-Process -FilePath $luaSensorHost -ArgumentList $Argument -WindowStyle Hidden -RedirectStandardError $luaErrorLog -Wait -PassThru;if($luaSensorProcess.ExitCode -ne 0){Get-Content -LiteralPath $luaErrorLog;throw ('Teste do serviço de sensores falhou: '+$Argument+' / '+$luaSensorProcess.ExitCode)}}
# Installation is tested only on this disposable administrator runner, never on users' PCs.
try {
    Invoke-LuaSensorHost '--install-service'
    Invoke-LuaSensorHost '--verify-service'
    $luaBridgeTest=Start-Process -FilePath (Join-Path $luaApp 'LUA.exe') -ArgumentList @('--verify-sensor-service','--data',('"'+$luaChecks+'"')) -WindowStyle Hidden -Wait -PassThru
    if($luaBridgeTest.ExitCode -ne 0){throw 'Reconectar o painel criou outro assistente ou perdeu telemetria.'}
    Stop-Service -Name LuaCpuSensors
    Start-Service -Name LuaCpuSensors
    Invoke-LuaSensorHost '--verify-service'
    [IO.File]::WriteAllText((Join-Path $luaApp 'VERIFICACAO-SERVICO-CI.txt'),'PASSOU: instalar serviço, ACL protegida, telemetria recente, parar e iniciar novamente. O runner não valida reinício físico nem temperatura em hardware do usuário.',[Text.UTF8Encoding]::new($false))
} finally {Invoke-LuaSensorHost '--remove-service'}
if(Get-Service -Name LuaCpuSensors -ErrorAction SilentlyContinue){throw 'O serviço de teste não foi removido.'}
$luaManifest=Get-ChildItem -LiteralPath $luaApp -Recurse -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object FullName | ForEach-Object {(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+$_.FullName.Substring($luaApp.Length+1).Replace('\','/')}
[IO.File]::WriteAllLines((Join-Path $luaApp 'SHA256SUMS.txt'),$luaManifest,[Text.UTF8Encoding]::new($false))
$luaPackageName='LUA-'+$luaVersion+'-Windows-x64.zip'
$luaPackage=Join-Path $luaStage $luaPackageName
Compress-Archive -LiteralPath $luaApp -DestinationPath $luaPackage -CompressionLevel Optimal
$luaHash=(Get-FileHash -LiteralPath $luaPackage -Algorithm SHA256).Hash.ToLowerInvariant()
$luaFeed=[ordered]@{Version=$luaVersion;Url=('https://github.com/'+$env:GITHUB_REPOSITORY+'/releases/download/'+$luaTag+'/'+$luaPackageName);Sha256=$luaHash;Bytes=(Get-Item -LiteralPath $luaPackage).Length;Notes=$luaSpec.notes}
$luaFeedPath=Join-Path $luaStage 'LUA-atualizacoes.json';[IO.File]::WriteAllText($luaFeedPath,($luaFeed|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
$luaNotes=Join-Path $luaStage 'release-notes.md';[IO.File]::WriteAllText($luaNotes,$luaSpec.notes,[Text.UTF8Encoding]::new($false))
gh release view $luaTag --repo $env:GITHUB_REPOSITORY 2>$null | Out-Null
if($LASTEXITCODE -ne 0){gh release create $luaTag --repo $env:GITHUB_REPOSITORY --target $env:GITHUB_SHA --title ('LUA '+$luaVersion+' para Windows') --notes-file $luaNotes --draft;if($LASTEXITCODE -ne 0){throw 'Falha ao criar a versão.'}}
gh release upload $luaTag $luaPackage $luaFeedPath --repo $env:GITHUB_REPOSITORY --clobber
if($LASTEXITCODE -ne 0){throw 'Falha ao enviar os arquivos da versão.'}
gh release edit $luaTag --repo $env:GITHUB_REPOSITORY --draft=false --latest --notes-file $luaNotes
if($LASTEXITCODE -ne 0){throw 'Falha ao publicar a versão.'}

