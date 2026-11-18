param([string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
[IO.Directory]::CreateDirectory((Join-Path $root 'build')) | Out-Null
$source = [IO.File]::ReadAllText((Join-Path $root 'src/client/Controllers/CameraFocusController.luau'))
$runner = @'
local camera = { FieldOfView = 70 }
local workspace = { CurrentCamera = camera, GetPropertyChangedSignal = function() return { Connect = function() end } end }
local tweenService = { Create = function(_, target, _, props)
    return { Cancel = function() end, Play = function() target.FieldOfView = props.FieldOfView end }
end }
local game = { GetService = function(_, key) return if key == "Workspace" then workspace else tweenService end }
local TweenInfo = { new = function() end }
local Enum = { EasingStyle = { Quad = 0 }, EasingDirection = { Out = 0 } }
local function loadModule()
'@
$runner += "`n" + $source + "`nend`n" + @'
local focus = loadModule()
focus.SetMinigame(true); assert(camera.FieldOfView == 64)
focus.SetTalking(true); assert(camera.FieldOfView == 62)
focus.SetMinigame(false); assert(camera.FieldOfView == 62)
focus.SetTalking(false); assert(camera.FieldOfView == 70)
focus.SetTalking(true); focus.SetMinigame(true); assert(camera.FieldOfView == 62)
focus.SetTalking(false); assert(camera.FieldOfView == 64)
focus.SetMinigame(false); assert(camera.FieldOfView == 70)
print("PASS camera focus: both overlap and closing orders, 62/64/70")
'@
$path = Join-Path $root 'build/test_camera_focus.luau'
[IO.File]::WriteAllText($path, $runner, [Text.UTF8Encoding]::new($false))
& $LuauExe $path
exit $LASTEXITCODE
