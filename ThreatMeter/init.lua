local VERSION = "0.8.1"

local ThreatMeter = Apollo.GetPackage("DaiAddon-1.0").tPackage:NewAddon("ThreatMeter", true, {})
ThreatMeter.Version = VERSION

ThreatMeter.db = {
  nWarningSoundId       = 162,
  crNormalText          = "White",
  crPlayer              = "xkcdLavender",
  crPlayerPet           = "xkcdLightIndigo",
  crGroupMember         = "xkcdLightForestGreen",
  crNotPlayer           = "xkcdScarlet",
  nTPSWindow            = 10,
  fWarningThreshold     = 90,
  bShowWhenInGroup      = true,
  bShowWhenHavePet      = true,
  bShowWhenInRaid       = true,
  bShowWhenAlone        = false,
  bHideWhenNotInCombat  = true,
  bHideWhenInPvP        = true,
  bWarningUseSound      = true,
  bWarningUseMessage    = true,
  bWarningTankDisable   = true,
  bThreatTotalPrecision = false,
}