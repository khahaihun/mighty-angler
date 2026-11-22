param(
    [string]$LuauExe = (Join-Path $PSScriptRoot 'luau.exe'),
    [ValidateSet('all', 'studio_data_isolation', 'session_acquisition', 'session_lifecycle', 'data_persistence', 'profile_schema', 'dev_reset', 'initial_state', 'session_lock_retry', 'global_leaderboard', 'profile_compatibility')]
    [string]$Suite = 'all'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
if (-not (Test-Path -LiteralPath $LuauExe)) {
    throw 'Can tools/luau.exe (Luau CLI). Xem tests/README.md; khong can bat Roblox API.'
}
if (-not (Test-Path -LiteralPath 'build')) {
    New-Item -ItemType Directory -Path 'build' | Out-Null
}

# Embed unchanged production source: Luau CLI has no Roblox Instance loader or file IO.
$modulePaths = @{
    Types = 'src/shared/Types.luau'
    Util = 'src/shared/Util.luau'
    GameConfig = 'src/shared/Config/GameConfig.luau'
    DataStoreLockHelper = 'src/server/Services/DataStoreLockHelper.luau'
    LiveOpsService = 'src/server/Services/LiveOpsService.luau'
    GlobalLeaderboard = 'src/server/Services/GlobalLeaderboard.luau'
    DataService = 'src/server/Services/DataService.luau'
    ProfileWriteHelper = 'src/server/Services/ProfileWriteHelper.luau'
    ProfileValidator = 'src/server/Services/ProfileValidator.luau'
    ProfilePersistenceService = 'src/server/Services/ProfilePersistenceService.luau'
    ProfileMigrator = 'src/server/Services/ProfileMigrator.luau'
    EnchantAndBountyService = 'src/server/Services/EnchantAndBountyService.luau'
    CurrencyService = 'src/server/Services/CurrencyService.luau'
    DevTestService = 'src/server/Services/DevTestService.luau'
    DevTestPanel = 'src/client/UI/Panels/DevTestPanel.luau'
    OddsCalculator = 'src/shared/OddsCalculator.luau'
    CatchControl = 'src/shared/CatchControl.luau'
    PurchaseOddsSummary = 'src/shared/PurchaseOddsSummary.luau'
    PurchaseOddsController = 'src/client/Controllers/PurchaseOddsController.luau'
    GamepassesConfig = 'src/shared/Config/GamepassesConfig.luau'
    PetsConfig = 'src/shared/Config/PetsConfig.luau'
    EventsConfig = 'src/shared/Config/EventsConfig.luau'
    HudPanel = 'src/client/UI/Panels/HudPanel.luau'
    ClientStateController = 'src/client/Controllers/ClientStateController.luau'
    ProfileAccessBanner = 'src/client/UI/Components/ProfileAccessBanner.luau'
    ShopAndItemsService = 'src/server/Services/ShopAndItemsService.luau'
    PotionAndBaitHelper = 'src/server/Services/PotionAndBaitHelper.luau'
    BaitConfig = 'src/shared/Config/BaitConfig.luau'
    BountiesConfig = 'src/shared/Config/BountiesConfig.luau'
    EnchantsConfig = 'src/shared/Config/EnchantsConfig.luau'
    GymGearConfig = 'src/shared/Config/GymGearConfig.luau'
    PotionsConfig = 'src/shared/Config/PotionsConfig.luau'
    RodsConfig = 'src/shared/Config/RodsConfig.luau'
    Islands = 'src/shared/Config/Islands/init.luau'
    Island1_SunnyShores = 'src/shared/Config/Islands/Island1_SunnyShores.luau'
    Island2_CoralDepths = 'src/shared/Config/Islands/Island2_CoralDepths.luau'
    Island3_MysticSwamp = 'src/shared/Config/Islands/Island3_MysticSwamp.luau'
    Island4_EmberIsle = 'src/shared/Config/Islands/Island4_EmberIsle.luau'
    Island5_CelestialDeep = 'src/shared/Config/Islands/Island5_CelestialDeep.luau'
}
$runner = [Text.StringBuilder]::new()
[void]$runner.AppendLine('local sources = {}')
foreach ($name in ($modulePaths.Keys | Sort-Object)) {
    $source = [IO.File]::ReadAllText((Join-Path $projectRoot $modulePaths[$name]))
    if ($source.Contains(']====]')) { throw 'Unsupported long-string delimiter in source' }
    [void]$runner.AppendLine(('sources["{0}"] = [====[{1}]====]' -f $name, $source))
}
[void]$runner.AppendLine(('local requestedSuite = "{0}"' -f $Suite))
[void]$runner.AppendLine(@'
local failures = 0
local function run(name, suite)
    if requestedSuite ~= "all" and requestedSuite ~= name then return end
    local ok, err = pcall(suite, sources)
    print(string.format("%s suite %s%s", if ok then "PASS" else "FAIL", name,
        if ok then "" else ": " .. tostring(err)))
    if not ok then failures += 1 end
end
run("studio_data_isolation", function(src) require("../tests/studio_data_isolation")(src) end)
run("session_acquisition", function(src) require("../tests/session_acquisition")(src) end)
run("session_lifecycle", function(src) require("../tests/session_lifecycle")(src) end)
run("session_lock_retry", function(src) require("../tests/session_lock_retry")(src) end)
run("global_leaderboard", function(src) require("../tests/global_leaderboard")(src) end)
run("profile_schema", function(src) require("../tests/profile_schema")(src) end)
run("profile_compatibility", function(src) require("../tests/profile_compatibility")(src) end)
run("dev_reset", function(src) require("../tests/dev_reset")(src) end)
run("initial_state", function(src) require("../tests/initial_state")(src) end)
run("data_persistence", function(src) require("../tests/data_persistence")(src) end)
assert(failures == 0, string.format("%d suite(s) failed; see PASS/FAIL above", failures))
'@)
$runnerPath = Join-Path $projectRoot 'build/test_studio_data_isolation.luau'
[IO.File]::WriteAllText($runnerPath, $runner.ToString(), [Text.UTF8Encoding]::new($false))
& $LuauExe $runnerPath
exit $LASTEXITCODE
