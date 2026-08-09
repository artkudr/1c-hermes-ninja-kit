# install-service.ps1 — мост prime-agent как служба через NSSM
# (сессия 0: консольные окна воркеров физически невидны пользователю).
$ErrorActionPreference = "Continue"
$log = "C:\hermes\tools\run\svc-install.log"
Start-Transcript -Path $log -Force | Out-Null
$nssm    = "C:\Users\artkudr\AppData\Local\Microsoft\WinGet\Packages\NSSM.NSSM_Microsoft.Winget.Source_8wekyb3d8bbwe\nssm-2.24-101-g897c7ad\win64\nssm.exe"
$pythonw = "C:\Users\artkudr\AppData\Local\hermes\hermes-agent\venv\Scripts\pythonw.exe"
$script  = "C:\hermes\tools\scripts\pi-bridge.py"

sc.exe delete pi-bridge 2>$null | Out-Null
& $nssm install pi-bridge $pythonw $script
"nssm install exit=$LASTEXITCODE"
& $nssm set pi-bridge AppDirectory "C:\hermes"
& $nssm set pi-bridge AppExit Default Restart
& $nssm set pi-bridge AppStdout "C:\hermes\tools\run\pi-svc.out.log"
& $nssm set pi-bridge AppStderr "C:\hermes\tools\run\pi-svc.err.log"
& $nssm start pi-bridge
"nssm start exit=$LASTEXITCODE"
Start-Sleep -Seconds 8
& $nssm status pi-bridge
Stop-Transcript | Out-Null