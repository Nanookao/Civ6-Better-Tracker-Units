print("Loading WorldTracker.lua from Better World Tracker Units version 1.0");


-- Infixo: check extensions, modes and mods ;)
local m_isHeroes:boolean     = GameCapabilities.HasCapability("CAPABILITY_HEROES"); -- Heroes & Legends Mode
local m_isApocalypse:boolean = GameCapabilities.HasCapability("CAPABILITY_MEGADISASTERS"); -- Apocalypse Mode
local m_isBES:boolean        = Modding.IsModActive("07D5DFAB-44CE-8F63-8344-93E427E9376E"); -- Better Espionage Screen for new spy icons
local m_isCQUI:boolean       = Modding.IsModActive("1d44b5e7-753e-405b-af24-5ee634ec8a01"); -- for new apostle icons
--[[
print("Apocalypse: ", (m_isApocalypse and "YES" or "no"));
print("Heroes    : ", (m_isHeroes and "YES" or "no"));
print("BES       : ", (m_isBES and "YES" or "no"));
--]]
print("CQUI      : ", (m_isCQUI and "YES" or "no"));


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local LL = Locale.Lookup;

-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_isUnitListMilitary		:boolean = false;
local m_showTrader				:boolean = false;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
function UpdateUnitListPanel(hideUnitList:boolean)

	-- If not an actual player (observer, tuner, etc...) then we're done here...
	local ePlayer		:number = Game.GetLocalPlayer();
	if (ePlayer == PlayerTypes.NONE or ePlayer == PlayerTypes.OBSERVER) then
		return;
	end
	local pPlayerConfig : table = PlayerConfigurations[ePlayer];

	if not HasCapability("CAPABILITY_UNIT_LIST") or (ePlayer ~= PlayerTypes.NONE and not pPlayerConfig:IsAlive()) then
		hideUnitList = true;
		Controls.CivicsCheck:SetHide(true);
		m_unitListInstance.UnitListMainPanel:SetHide(true);
		return;
	end

	if(hideUnitList ~= nil) then m_hideUnitList = hideUnitList; end
	
	m_unitEntryIM:ResetInstances();

	m_unitListInstance.UnitListMainPanel:SetHide(m_hideUnitList); 
	Controls.UnitCheck:SetCheck(not m_hideUnitList);

	local pPlayer : table = Players[ePlayer];
	local pPlayerUnits : table = pPlayer:GetUnits();
	local numUnits : number = pPlayerUnits:GetCount();

	if(pPlayerUnits:GetCount() > 0)then
		m_unitListInstance.NoUnitsLabel:SetHide(true);
		m_unitListInstance.UnitsSearchBox:LocalizeAndSetToolTip("LOC_WORLDTRACKER_UNITS_SEARCH_TT");

		local militaryUnits : table = {};
		local civilianUnits : table = {};

		for i, pUnit in pPlayerUnits:Members() do
			if((m_unitSearchString ~= "" and string.find(Locale.ToUpper(pUnit:GetName()), m_unitSearchString) ~= nil) or m_unitSearchString == "")then
				local pUnitInfo : table = GameInfo.Units[pUnit:GetUnitType()];
				-- Infixo: just split into 2 categories
				-- Infixo: a better way to group the units is to use FormationClass
				if pUnitInfo.FormationClass ~= "FORMATION_CLASS_CIVILIAN" then
					table.insert(militaryUnits, pUnit);
				elseif m_showTrader or not pUnitInfo.MakeTradeRoute then
					table.insert(civilianUnits, pUnit);
				end
			end
		end

		-- Alphabetize groups
		local sortFunc = function(a, b) 
			-- Infixo: sort by an actual name (asc) and experience (desc)
			local aName:string = Locale.Lookup(a:GetName());
			local bName:string = Locale.Lookup(b:GetName());
			if aName == bName then
				return a:GetExperience():GetExperiencePoints() > b:GetExperience():GetExperiencePoints();
			end
			return aName < bName;
		end

		-- Add units by sorted groups
		if m_isUnitListMilitary then
			table.sort(militaryUnits, sortFunc);
			for _, pUnit in ipairs(militaryUnits) do AddUnitToUnitList( pUnit ); end
		else -- civilian
			table.sort(civilianUnits, sortFunc);
			for _, pUnit in ipairs(civilianUnits) do AddUnitToUnitList( pUnit ); end
		end
	else
		m_unitListInstance.TraderCheck:SetHide(true);
		m_unitListInstance.NoUnitsLabel:SetHide(false);
		m_unitListInstance.UnitsSearchBox:SetDisabled(true);
		m_unitListInstance.UnitsSearchBox:LocalizeAndSetToolTip("LOC_WORLDTRACKER_NO_UNITS");
	end

	RealizeEmptyMessage();
	RealizeStack();
end

-- ===========================================================================
function StartUnitListSizeUpdate()
	m_isUnitListSizeDirty = true;

        --[[ Infixo?
        --Allow the unit stack to take up it's full size so the auto sizing parent can do it's thing
	m_unitListInstance.UnitStackContainer:SetHide(false);
	m_unitListInstance.UnitStack:ChangeParent(m_unitListInstance.UnitStackContainer); 
        --]]
        ContextPtr:RequestRefresh();
end

-- ===========================================================================
-- WorldTrackerVerticalContainer:
--   = ResearchInstance
--   = CivicInstance
--   = .OtherContainer - emergencies, multiple * 144 per one
--   = UnitListInstance
--   = .ChatPanelContainer
--   = .TutorialGoals





-- ===========================================================================
-- INFIXO: BOLBAS' CODE, USED WITH PERMISSION
-- Refactoring (new icons, simplifications) by Infixo

local BQUI_PreviousUnitEntrySum = nil;    -- bolbas (Middle Click on Unit List entries added - shows total number of units of that type)
local BQUI_UnitDifferentReligions:number = 0;    -- bolbas (Religion icons added)

local BQUI_ApostlePromotionIcons:table = {
	PROMOTION_CHAPLAIN =			{Icon = "ICON_UNIT_MEDIC",			Size = 16,	OffsetY = -1},
	PROMOTION_DEBATER =				{Icon = "ICON_STRENGTH",			Size = 14,	OffsetY = -1},
	PROMOTION_HEATHEN_CONVERSION =	{Icon = "ICON_NOTIFICATION_NEW_BARBARIAN_CAMP",	Size = 18,	OffsetY = -1},
	PROMOTION_INDULGENCE_VENDOR =	{Icon = "ICON_MAP_PIN_CIRCLE",		Size = 12,	OffsetY = -1},
	PROMOTION_PROSELYTIZER =		{Icon = "ICON_UNIT_INQUISITOR",		Size = 17,	OffsetY = 0},
	PROMOTION_TRANSLATOR =			{Icon = "ICON_QUEUE",				Size = 18,	OffsetY = -1},
	PROMOTION_MARTYR =				{Icon = "ICON_GREATWORKOBJECT_RELIC",	Size = 12,	OffsetY = 0},
	PROMOTION_ORATOR =				{Icon = "ICON_STATS_SPREADCHARGES",	Size = 16,	OffsetY = 0},
	PROMOTION_PILGRIM =				{Icon = "ICON_STATS_TERRAIN",		Size = 16,	OffsetY = 0},
};

-- Infixo: icons update to be in sync with CQUI
local CQUI_ApostlePromotionIcons:table = {
	PROMOTION_CHAPLAIN 			 = {Icon = "Religion",		  Size = 20, OffsetY = 0},-- medic
	PROMOTION_DEBATER 			 = {Icon = "Ability",		  Size = 20, OffsetY = 0},-- +20 combat
	PROMOTION_HEATHEN_CONVERSION = {Icon = "Barbarian",		  Size = 20, OffsetY = 0},-- barbs
	PROMOTION_INDULGENCE_VENDOR  = {Icon = "Gold",		 	  Size = 18, OffsetY = 0},-- gold
	PROMOTION_PROSELYTIZER 		 = {Icon = "Damaged",		  Size = 20, OffsetY = 0},-- 75% reduce
	PROMOTION_TRANSLATOR 		 = {Icon = "Bombard",		  Size = 20, OffsetY = 0},-- 3x pressure
	PROMOTION_MARTYR 			 = {Icon = "GreatWork_Relic", Size = 18, OffsetY = 0},-- relic
	--PROMOTION_ORATOR 			 = {Icon = "ICON_STATS_SPREADCHARGES", Size = 16, OffsetY = 0}, -- adds charges
	--PROMOTION_PILGRIM 		 = {Icon = "ICON_STATS_TERRAIN",	   Size = 16, OffsetY = 0}, -- adds charges
};

local BQUI_RockBandPromotionIcons:table = {
	PROMOTION_ALBUM_COVER_ART =	{Icon = "ICON_STAT_WONDERS",		Size = 16,	OffsetY = -1},
	PROMOTION_ARENA_ROCK =		{Icon = "ICON_AMENITIES",			Size = 17,	OffsetY = 0},
	PROMOTION_GLAM_ROCK =		{Icon = "ICON_UNIT_GREAT_WRITER",	Size = 16,	OffsetY = 0},
	PROMOTION_GOES_TO =			{Icon = "PressureRight",			Size = 16,	OffsetY = 0},
	PROMOTION_INDIE =			{Icon = "ICON_STAT_CULTURAL_FLAG",	Size = 15,	OffsetY = 0},
	PROMOTION_MUSIC_FESTIVAL =	{Icon = "ICON_STATS_TERRAIN",		Size = 16,	OffsetY = 0},
	PROMOTION_POP =				{Icon = "ICON_MAP_PIN_CIRCLE",		Size = 12,	OffsetY = -1},
	PROMOTION_REGGAE_ROCK =		{Icon = "ICON_AMENITIES",			Size = 17,	OffsetY = 0},    -- Infixo: fixed
	PROMOTION_RELIGIOUS_ROCK =	{Icon = "ICON_RELIGION",			Size = 18,	OffsetY = 0},
	PROMOTION_ROADIES =			{Icon = "ICON_MOVES",				Size = 14,	OffsetY = 0},
	PROMOTION_SPACE_ROCK =		{Icon = "ICON_UNIT_GREAT_SCIENTIST",Size = 15,	OffsetY = 0},
	PROMOTION_SURF_ROCK =		{Icon = "ICON_UNIT_GREAT_ADMIRAL",	Size = 15,	OffsetY = 0},
};

-- Infixo: updated icons to better reflect description (e.g. district icons used)
local CQUI_RockBandPromotionIcons:table = {
	PROMOTION_ALBUM_COVER_ART =	{Icon = "ICON_STAT_WONDERS",    Size = 16, OffsetY = 0},
	PROMOTION_ARENA_ROCK =		{Icon = "ICON_AMENITIES",		Size = 16, OffsetY = 0},
	PROMOTION_GLAM_ROCK =		{Icon = "ICON_DISTRICT_THEATER",Size = 16, OffsetY = 0},
	PROMOTION_GOES_TO =			{Icon = "PressureRight",		Size = 18, OffsetY = 0},
	PROMOTION_INDIE =			{Icon = "PressureDown",			Size = 22, OffsetY = 0},
	PROMOTION_MUSIC_FESTIVAL =	{Icon = "ICON_STATS_TERRAIN",	Size = 16, OffsetY = 0},
	PROMOTION_POP =				{Icon = "Gold",					Size = 20, OffsetY = 0},
	PROMOTION_REGGAE_ROCK =		{Icon = "ICON_DISTRICT_WATER_ENTERTAINMENT_COMPLEX", Size = 16, OffsetY = 0}, -- Infixo: fixed
	PROMOTION_RELIGIOUS_ROCK =	{Icon = "ICON_RELIGION",		Size = 20, OffsetY = 0},
	PROMOTION_ROADIES =			{Icon = "ICON_MOVES",			Size = 14, OffsetY = 0},
	PROMOTION_SPACE_ROCK =		{Icon = "ICON_DISTRICT_CAMPUS", Size = 16, OffsetY = 0},
	PROMOTION_SURF_ROCK =		{Icon = "ICON_DISTRICT_HARBOR", Size = 16, OffsetY = 0},
};

local BQUI_SpyPromotionIcons:table = {
	PROMOTION_SPY_ACE_DRIVER =		{Icon = "ICON_NOTIFICATION_SPY_CHOOSE_ESCAPE_ROUTE",	Size = 18,	OffsetY = 0},
	PROMOTION_SPY_CAT_BURGLAR =		{Icon = "ICON_NOTIFICATION_SPY_HEIST_GREAT_WORK",		Size = 16,	OffsetY = -1},
	PROMOTION_SPY_CON_ARTIST =		{Icon = "ICON_NOTIFICATION_SPY_SIPHONED_FUNDS",			Size = 18,	OffsetY = -1},
	PROMOTION_SPY_DEMOLITIONS =		{Icon = "ICON_NOTIFICATION_SPY_SABOTAGED_PRODUCTION",	Size = 16,	OffsetY = -1},
	PROMOTION_SPY_DISGUISE =		{Icon = "ICON_UNITCOMMAND_AIRLIFT",						Size = 17,	OffsetY = -1},
	PROMOTION_SPY_GUERILLA_LEADER =	{Icon = "ICON_NOTIFICATION_SPY_RECRUIT_PARTISANS",		Size = 16,	OffsetY = -1},
	PROMOTION_SPY_LINGUIST =		{Icon = "Turn",											Size = 18,	OffsetY = -1},
	PROMOTION_SPY_QUARTERMASTER =	{Icon = "ICON_UNITOPERATION_FOUND_CITY",				Size = 16,	OffsetY = -1},
	PROMOTION_SPY_ROCKET_SCIENTIST ={Icon = "ICON_NOTIFICATION_SPY_DISRUPTED_ROCKETRY",		Size = 18,	OffsetY = 0},
	PROMOTION_SPY_SEDUCTION =		{Icon = "ICON_UNITOPERATION_SPY_COUNTERSPY_ACTION",		Size = 16,	OffsetY = -1},
	PROMOTION_SPY_TECHNOLOGIST =	{Icon = "ICON_NOTIFICATION_SPY_STOLE_TECH_BOOST",		Size = 16,	OffsetY = -1},
	PROMOTION_SPY_COVERT_ACTION =	{Icon = "ICON_STAT_CULTURAL_FLAG",						Size = 15,	OffsetY = 0},
	PROMOTION_SPY_LICENSE_TO_KILL =	{Icon = "ICON_NOTIFICATION_GOVERNOR_PROMOTION_AVAILABLE", Size = 16, OffsetY = -1},
	PROMOTION_SPY_SMEAR_CAMPAIGN =	{Icon = "ICON_NOTIFICATION_GIVE_INFLUENCE_TOKEN",		Size = 16,	OffsetY = -1},
	PROMOTION_SPY_POLYGRAPH =		{Icon = "ICON_UNITOPERATION_SPY_TRAVEL_NEW_CITY",		Size = 16,	OffsetY = -2},
	PROMOTION_SPY_SATCHEL_CHARGES =	{Icon = "ICON_NOTIFICATION_SPY_BREACH_DAM",				Size = 16,	OffsetY = -1},
	PROMOTION_SPY_SURVEILLANCE =	{Icon = "ICON_STAT_DISTRICTS",							Size = 16,	OffsetY = -1},
};

local BQUI_SoothsayerPromotionIcons:table = {
	PROMOTION_SOOTHSAYER_MESSENGER =   {Icon = "ICON_MOVES",				  Size = 14, OffsetY = 0},
	PROMOTION_SOOTHSAYER_INQUISITOR =  {Icon = "ICON_NOTIFICATION_SPY_GROUP", Size = 14, OffsetY = -1},
	PROMOTION_SOOTHSAYER_ZEALOT =	   {Icon = "ICON_MAP_PIN_CHARGES",		  Size = 14, OffsetY = -1},
	PROMOTION_SOOTHSAYER_INCANTATION = {Icon = "ICON_STRENGTH",				  Size = 14, OffsetY = -1},
	PROMOTION_SOOTHSAYER_PLAGUE_BEARER = {Icon = "ICON_UNITOPERATION_SPY_TRAVEL_NEW_CITY", Size = 16, OffsetY = -2},
};

local BQUI_GreatPersonEras:table = {
	ERA_CLASSICAL =   {Icon_1 = "ICON_GREATWORKOBJECT_ARTIFACT_ERA_CLASSICAL",   Size_1 = 13, OffsetY_1 = -1, Icon_2 = "ICON_GREATWORKOBJECT_ARTIFACT_ERA_MEDIEVAL",    Size_2 = 14, OffsetY_2 = -1},
	ERA_MEDIEVAL =    {Icon_1 = "ICON_GREATWORKOBJECT_ARTIFACT_ERA_MEDIEVAL",    Size_1 = 14, OffsetY_1 = -1, Icon_2 = "ICON_GREATWORKOBJECT_ARTIFACT_ERA_RENAISSANCE", Size_2 = 14, OffsetY_2 = -1},
	ERA_RENAISSANCE = {Icon_1 = "ICON_GREATWORKOBJECT_ARTIFACT_ERA_RENAISSANCE", Size_1 = 14, OffsetY_1 = -1, Icon_2 = "ICON_GREATWORKOBJECT_ARTIFACT_ERA_INDUSTRIAL",  Size_2 = 14, OffsetY_2 = -1},
	ERA_INDUSTRIAL =  {Icon_1 = "ICON_GREATWORKOBJECT_ARTIFACT_ERA_INDUSTRIAL",  Size_1 = 14, OffsetY_1 = -1, Icon_2 = "ICON_IMPROVEMENT_OIL_WELL",                     Size_2 = 18, OffsetY_2 = 0},
	ERA_MODERN =      {Icon_1 = "ICON_IMPROVEMENT_OIL_WELL",                     Size_1 = 18, OffsetY_1 = 0,  Icon_2 = "ICON_PROJECT_BUILD_NUCLEAR_DEVICE",             Size_2 = 18, OffsetY_2 = 0},
	ERA_ATOMIC =      {Icon_1 = "ICON_PROJECT_BUILD_NUCLEAR_DEVICE",             Size_1 = 18, OffsetY_1 = 0,  Icon_2 = "ICON_PROJECT_BUILD_THERMONUCLEAR_DEVICE",       Size_2 = 18, OffsetY_2 = 0},
	ERA_INFORMATION = {Icon_1 = "ICON_PROJECT_BUILD_THERMONUCLEAR_DEVICE",       Size_1 = 18, OffsetY_1 = 0},
};

local BQUI_PromotionTreeCheck:table = {
	["11"] = true,
	["21"] = true,
	["31"] = true,
	["13"] = true,
	["23"] = true,
	["33"] = true,
	["42"] = true,
};

-- Infixo: will read dynamically abilities granting XP boost
-- EffectType = EFFECT_ADJUST_UNIT_EXPERIENCE_MODIFIER
m_xpAbilities = {};
function InitializeUnitAbilities()
	local results = DB.Query([[
		select UnitAbilityType, Value
		from UnitAbilityModifiers as uam, ModifierArguments as ma
		where uam.ModifierId = ma.ModifierId and ma.Name = 'Amount' and
		uam.ModifierId in (
			select ModifierId
			from Modifiers as m
			where m.ModifierType in (
				select dm.ModifierType
				from DynamicModifiers as dm
				where dm.EffectType = 'EFFECT_ADJUST_UNIT_EXPERIENCE_MODIFIER'))
	]]);
	if results then
		for _,row in ipairs(results) do
			m_xpAbilities[row.UnitAbilityType] = tonumber(row.Value);
		end
	end
end

-- bolbas (Religion icons added)
function BQUI_SetReligionIconUnitList(pUnit, unitEntry_ReligionIcon)
	local BQUI_religionID = pUnit:GetReligionType();
	if BQUI_religionID > 0 then
		unitEntry_ReligionIcon:SetShow(true);
		local religion:table = GameInfo.Religions[BQUI_religionID];
		local ReligionType = religion.ReligionType;
		unitEntry_ReligionIcon:SetSizeVal(22,22);
		unitEntry_ReligionIcon:SetIcon("ICON_" .. ReligionType);
		unitEntry_ReligionIcon:SetSizeVal(18,18);
		if BQUI_UnitDifferentReligions ~= -1 then
			if BQUI_UnitDifferentReligions == 0 then
				BQUI_UnitDifferentReligions = BQUI_religionID;
			elseif BQUI_UnitDifferentReligions ~= BQUI_religionID then
				BQUI_UnitDifferentReligions = -1;
			end
		end
	else
		unitEntry_ReligionIcon:SetShow(false);
		BQUI_UnitDifferentReligions = -1;
	end
end

-- bolbas (Middle Click on Unit List entries added - shows total number of units of that type)
function BQUI_CalculateUnits(BQUI_UnitType, unitEntrySum)
	if unitEntrySum:IsHidden() then
		local UnitNumber = 0;
		local pPlayer:table = Players[Game.GetLocalPlayer()];
		local pPlayerUnits:table = pPlayer:GetUnits();
		for i, pUnit in pPlayerUnits:Members() do
			local pUnitType = GameInfo.Units[pUnit:GetUnitType()].UnitType;
			if pUnitType == BQUI_UnitType then
				UnitNumber = UnitNumber + 1;
			end
		end

		unitEntrySum:SetText(UnitNumber);
		unitEntrySum:SetShow(true);

		if BQUI_PreviousUnitEntrySum == nil then
			BQUI_PreviousUnitEntrySum = unitEntrySum;
		else
			BQUI_PreviousUnitEntrySum:SetShow(false);
			BQUI_PreviousUnitEntrySum = unitEntrySum;
		end
	else
		unitEntrySum:SetShow(false);
		BQUI_PreviousUnitEntrySum = nil;
	end
end

function AddUnitToUnitList(pUnit:table)
	local BQUI_localPlayerID:number = Game.GetLocalPlayer();
	local unitEntry:table = m_unitEntryIM:GetInstance();

	-- check formation and prepare suffix
	local suffix:string = " ";
	if     pUnit:GetMilitaryFormation() == MilitaryFormationTypes.CORPS_FORMATION then suffix = "[ICON_Corps]";
	elseif pUnit:GetMilitaryFormation() == MilitaryFormationTypes.ARMY_FORMATION  then suffix = "[ICON_Army]"; end
	
	-- Infixo: Heroes Mode
	if m_isHeroes then
		local eHeroClass = Game.GetHeroesManager():GetUnitHeroClass( pUnit:GetUnitType() );
		if eHeroClass > -1 then
			suffix = "[ICON_Capital]";
		end
	end
	
	-- name and tooltip
	local tt:table = {};
	local name:string = pUnit:GetName();
	local tooltip:string = Locale.Lookup(name);
	if suffix ~= " " then tooltip = tooltip.." "..suffix; end
	local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
	local unitTypeName:string = unitInfo.Name;
	if name ~= unitTypeName then
		tooltip = tooltip.." "..Locale.Lookup("LOC_UNIT_UNIT_TYPE_NAME_SUFFIX", unitTypeName); -- <Text> ({1_UnitTypeName})</Text>
		table.insert(tt, tooltip);
	end
	unitEntry.UnitName:SetText(Locale.ToUpper(Locale.Lookup(name))); -- actual name
	unitEntry.UnitNameSuffix:SetText(suffix); -- corps/army icon
	
	-- attach unit ID to the control for future use
	local BQUI_UnitID = pUnit:GetID();
	unitEntry.Button:SetVoid1(BQUI_UnitID);

	local BQUI_UnitType = unitInfo.UnitType;
	local BQUI_unitExperience = pUnit:GetExperience();
	local BQUI_PromotionList :table = BQUI_unitExperience:GetPromotions();
	local BQUI_ExperiencePoints = BQUI_unitExperience:GetExperiencePoints();
	local BQUI_MaxExperience = BQUI_unitExperience:GetExperienceForNextLevel();
	local BQUI_SpreadCharges = pUnit:GetSpreadCharges();
	local BQUI_ReligiousHealCharges = pUnit:GetReligiousHealCharges();
	local BQUI_CombatStrength = pUnit:GetCombat();
	local BQUI_RangedCombatStrength = pUnit:GetRangedCombat();

	-- promotions are off by default
	unitEntry.PromotionAvailableIcon:SetShow(false);
	unitEntry.PromotionsShield:SetShow(false); -- graphical representation
	unitEntry.RealPromotion1:SetShow(false);
	unitEntry.RealPromotion2:SetShow(false);
	unitEntry.RealPromotion3:SetShow(false);
	unitEntry.AbilityXPIcon:SetShow(false);
	unitEntry.AbilityGPIcon:SetShow(false);
	unitEntry.AbilityCmdIcon:SetShow(false);
	unitEntry.TierPromotion11:SetShow(false);
	unitEntry.TierPromotion21:SetShow(false);
	unitEntry.TierPromotion31:SetShow(false);
	unitEntry.TierPromotion13:SetShow(false);
	unitEntry.TierPromotion23:SetShow(false);
	unitEntry.TierPromotion33:SetShow(false);
	unitEntry.TierPromotion42:SetShow(false);
	
	local function SetPromotionIconByName(unitEntry:table, idx:number, iconName:string, size:number, offsetY:number)
		unitEntry["RealPromotion"..idx]:SetShow(true);
		unitEntry["PromotionIcon"..idx]:SetIcon(iconName);
		unitEntry["PromotionIcon"..idx]:SetSizeVal(size, size);
		unitEntry["PromotionIcon"..idx]:SetOffsetY(offsetY);
	end
	
	local function SetPromotionIconByIcon(unitEntry:table, idx:number, iconInfo:table)
		SetPromotionIconByName(unitEntry, idx, iconInfo.Icon, iconInfo.Size, iconInfo.OffsetY);
	end

	-- *** PROMOTIONS ***
	if #BQUI_PromotionList > 0 then

		-- Military Units - graphical tree
		if BQUI_CombatStrength > 0 or BQUI_RangedCombatStrength > 0 then
			unitEntry.PromotionsShield:SetShow(true);
			unitEntry.CountLabel:SetText(#BQUI_PromotionList);
			-- Infixo: simplified code, just iterate promos and highlight the proper dot
			-- There could be more dots added to support custom promotion schemes
			for _,promo in ipairs(BQUI_PromotionList) do
				local promoInfo:table = GameInfo.UnitPromotions[promo];
				local col:number, row:number = promoInfo.Column, promoInfo.Level;
				if BQUI_UnitType == "UNIT_GIANT_DEATH_ROBOT" then break; end -- don't show any dots, just level
				if BQUI_UnitType == "UNIT_LAHORE_NIHANG" and row == 3 then row = 4; end -- move 1 level down, Nihang has only 3 levels
				if col == 2 then col = 1; end -- middle column is moved to left
				if col  > 3 then col = 3; end -- anything after 3rd column is moved to 3rd column
				if row  > 3 then col = 2; end -- bottom dot is only one
				unitEntry["TierPromotion"..row..col]:SetShow(true);
			end
		end
		
		--- *** RELIGIOUS UNITS ***
		if pUnit:GetReligiousStrength() > 0 then
			for i,promo in ipairs(BQUI_PromotionList) do
				local promoInfo:table = GameInfo.UnitPromotions[promo];
				local iconInfo:table = BQUI_ApostlePromotionIcons[ promoInfo.UnitPromotionType ];
				if m_isCQUI then iconInfo = CQUI_ApostlePromotionIcons[ promoInfo.UnitPromotionType ]; end
				if iconInfo ~= nil and i <= 3 then SetPromotionIconByIcon(unitEntry, i, iconInfo); end
				table.insert(tt, "[ICON_Promotion] "..Locale.Lookup(promoInfo.Name)); -- add to the tooltip
			end
		end
		
		-- *** SPY ***
		if BQUI_UnitType == "UNIT_SPY" then
			for i,promo in ipairs(BQUI_PromotionList) do
				local promoInfo:table = GameInfo.UnitPromotions[promo];
				if m_isBES then
					if i <= 3 then SetPromotionIconByName(unitEntry, i, promoInfo.UnitPromotionType, 16, 0); end
				else
					local iconInfo:table = BQUI_SpyPromotionIcons[ promoInfo.UnitPromotionType ];
					if iconInfo ~= nil and i <= 3 then SetPromotionIconByIcon(unitEntry, i, iconInfo); end
				end
				table.insert(tt, "[ICON_Promotion] "..Locale.Lookup(promoInfo.Name)); -- add to the tooltip
			end
		end
		
		-- *** ROCK BAND ***
		if BQUI_UnitType == "UNIT_ROCK_BAND" then
			for i,promo in ipairs(BQUI_PromotionList) do
				local promoInfo:table = GameInfo.UnitPromotions[promo];
				local iconInfo:table = BQUI_RockBandPromotionIcons[ promoInfo.UnitPromotionType ];
				if m_isCQUI then iconInfo = CQUI_RockBandPromotionIcons[ promoInfo.UnitPromotionType ]; end
				if iconInfo ~= nil and i <= 3 then SetPromotionIconByIcon(unitEntry, i, iconInfo); end
				table.insert(tt, "[ICON_Promotion] "..Locale.Lookup(promoInfo.Name)); -- add to the tooltip
			end
		end
		
		-- *** SOOTHSAYER ***
		if pUnit:GetDisasterCharges() > 0 then
			for i,promo in ipairs(BQUI_PromotionList) do
				local promoInfo:table = GameInfo.UnitPromotions[promo];
				local iconInfo:table = BQUI_SoothsayerPromotionIcons[ promoInfo.UnitPromotionType ];
				if iconInfo ~= nil and i <= 3 then SetPromotionIconByIcon(unitEntry, i, iconInfo); end
				table.insert(tt, "[ICON_Promotion] "..Locale.Lookup(promoInfo.Name)); -- add to the tooltip
			end

		end
	end -- PROMOTIONS

	-- *** PROMO AVAILABLE ***
	if BQUI_ExperiencePoints == BQUI_MaxExperience then
		unitEntry.PromotionAvailableIcon:SetShow(true);
	end
	
	-- *** BUILDER ***
	if pUnit:GetBuildCharges() > 0 and BQUI_CombatStrength == 0 and BQUI_RangedCombatStrength == 0 then
		unitEntry.PromotionsShield:SetShow(true);
		unitEntry.CountLabel:SetText(pUnit:GetBuildCharges());
	end
	
	-- *** RELIGIOUS CHARGES ***
	if BQUI_SpreadCharges > 0 then
		unitEntry.PromotionsShield:SetShow(true);
		unitEntry.CountLabel:SetText(BQUI_SpreadCharges);
	end
	
	-- *** HEALING CHARGES ***
	if BQUI_ReligiousHealCharges > 0 then
		unitEntry.PromotionsShield:SetShow(true);
		unitEntry.CountLabel:SetText(BQUI_ReligiousHealCharges);
	end
	
	-- *** DISASTER CHARGES ***
	if pUnit:GetDisasterCharges() > 0 then
		unitEntry.PromotionsShield:SetShow(true);
		unitEntry.CountLabel:SetText(pUnit:GetDisasterCharges());
	end
	
	-- *** ARCHAEOLOGIST ***
	if BQUI_UnitType == "UNIT_ARCHAEOLOGIST" then
		local pCity = Players[Game.GetLocalPlayer()]:GetCities():FindID( pUnit:GetArchaeologyHomeCity() );
		local pCityBldgs:table = pCity:GetBuildings();
		local ArchaeologicalMuseumIndex = GameInfo.Buildings["BUILDING_MUSEUM_ARTIFACT"].Index
		local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(ArchaeologicalMuseumIndex);
		local ArchaeologistCharges = 0;
		for index:number = 0, numSlots - 1 do
			local greatWorkIndex:number = pCityBldgs:GetGreatWorkInSlot(ArchaeologicalMuseumIndex, index);
			if (greatWorkIndex == -1) then
				ArchaeologistCharges = ArchaeologistCharges + 1;
			end
		end
		unitEntry.PromotionsShield:SetShow(true);
		unitEntry.CountLabel:SetText(ArchaeologistCharges);
	end
		
	-- *** GREAT GENERAL / ADMIRAL ***
	if BQUI_UnitType == "UNIT_GREAT_ADMIRAL" or BQUI_UnitType == "UNIT_GREAT_GENERAL" then
		local individual:number = pUnit:GetGreatPerson():GetIndividual();
		if individual > -1 then
			local individualEraType:string = GameInfo.GreatPersonIndividuals[individual].EraType;
			local eraInfo:table = GameInfo.Eras[individualEraType];
			unitEntry.PromotionsShield:SetShow(true);
			unitEntry.CountLabel:SetText(eraInfo.ChronologyIndex);
			table.insert(tt, string.format("%s [ICON_GoingTo] %s", LL(eraInfo.Name), LL(GameInfo.Eras[eraInfo.Index+1].Name)));
		end
	end

	-- bolbas (Icons for levied units added)
	if BQUI_CombatStrength > 0 then
		local iOwner = pUnit:GetOwner();
		local iOriginalOwner = pUnit:GetOriginalOwner();
		if (iOwner ~= iOriginalOwner) then
			local pOriginalOwner = Players[iOriginalOwner];
			if (pOriginalOwner ~= nil and pOriginalOwner:GetInfluence() ~= nil) then
				local iLevyTurnCounter = pOriginalOwner:GetInfluence():GetLevyTurnCounter();
				if (iLevyTurnCounter >= 0 and iOwner == pOriginalOwner:GetInfluence():GetSuzerain()) then
					unitEntry.LeviedUnitIcon:SetShow(true);
				end
			end
		end
	end

	-- *** Religion icons ***
	if BQUI_SpreadCharges > 0 or BQUI_ReligiousHealCharges > 0 then
		BQUI_SetReligionIconUnitList(pUnit, unitEntry.ReligionIcon);
	else
		unitEntry.ReligionIcon:SetShow(false);
	end

	-- *** Upgrade icon ***
	if pUnit:GetUpgradeCost() > 0 then
		unitEntry.UpgradeIcon:SetShow(true);
		unitEntry.UpgradeIcon:SetColorByName("UnitPanelTextCS");
		local bCanStart = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.UPGRADE, true);
		if bCanStart then
			local bCanStartNow = UnitManager.CanStartCommand( pUnit, UnitCommandTypes.UPGRADE, false, true);
			if not bCanStartNow then
				unitEntry.UpgradeIcon:SetColorByName("UnitPanelTextDisabledCS");
			end
		else
			unitEntry.UpgradeIcon:SetColorByName("UnitPanelTextDisabledCS");
		end
	else
		unitEntry.UpgradeIcon:SetShow(false);
	end

	-- *** Unit Abilities ***
	if BQUI_CombatStrength > 0 or BQUI_RangedCombatStrength > 0 then
		local xpBoost:number = 0;
		--local BQUI_AbilitiesStrength:number = 0;
		local isBoostedGeneral:boolean = false;
		local isBoostedComandante:boolean = false;
		for _,ability in ipairs (pUnit:GetAbility():GetAbilities()) do
			local abilityType = GameInfo.UnitAbilities[ability].UnitAbilityType;
			if m_xpAbilities[abilityType] ~= nil then xpBoost = xpBoost + m_xpAbilities[abilityType]; end
			if abilityType == "ABILITY_GREAT_GENERAL_STRENGTH"  then isBoostedGeneral    = true; end
			if abilityType == "ABILITY_GREAT_ADMIRAL_STRENGTH"  then isBoostedGeneral    = true; end
			if abilityType == "ABILITY_COMANDANTE_AOE_STRENGTH" then isBoostedComandante = true; end
		end
		if xpBoost > 0 then
			unitEntry.AbilityXPIcon:SetShow(true);
			if     xpBoost >= 100 then unitEntry.AbilityXPTierIcon:SetColor(UI.GetColorValue(0.6,   0, 1, 1)); -- magenta
			elseif xpBoost >=  75 then unitEntry.AbilityXPTierIcon:SetColor(UI.GetColorValue(  0, 0.4, 1, 1)); -- light blue
			elseif xpBoost >=  50 then unitEntry.AbilityXPTierIcon:SetColor(UI.GetColorValue(  0, 0.8, 1, 1)); -- green
			elseif xpBoost >=  25 then unitEntry.AbilityXPTierIcon:SetColor(UI.GetColorValue(0.2,   1, 0, 1)); -- dark green
			else 				       unitEntry.AbilityXPTierIcon:SetColor(UI.GetColorValue(  1,   1, 0, 1)); -- yellow
			end
		end
		--[[ Infixo: strength needs more thorough analysis
		if BQUI_AbilitiesStrength > 0 then
			unitEntry.BQUI_UNIT_ABILITIES_STRENGTH_UnitList:SetShow(true);
			if     BQUI_AbilitiesStrength == 1 then unitEntry.BQUI_UNIT_ABILITIES_STRENGTH_TIER_UnitList:SetColorByName("GrayMedium");
			elseif BQUI_AbilitiesStrength == 2 then unitEntry.BQUI_UNIT_ABILITIES_STRENGTH_TIER_UnitList:SetColorByName("Gray");
			elseif BQUI_AbilitiesStrength == 3 then unitEntry.BQUI_UNIT_ABILITIES_STRENGTH_TIER_UnitList:SetColorByName("AirportDark");
			elseif BQUI_AbilitiesStrength == 4 then unitEntry.BQUI_UNIT_ABILITIES_STRENGTH_TIER_UnitList:SetColorByName("Airport");
			else 				                    unitEntry.BQUI_UNIT_ABILITIES_STRENGTH_TIER_UnitList:SetColorByName("MilitaryDark");
			end
		end --]]
		unitEntry.AbilityGPIcon:SetShow(isBoostedGeneral);
		unitEntry.AbilityCmdIcon:SetShow(isBoostedComandante);
	end -- Unit Abilities

	-- Infixo: highlight the currently selected unit or use default control
	unitEntry.Button:SetTexture( UI.IsUnitSelected(pUnit) and "Controls_ButtonControl_Tan" or "Controls_ButtonControl");
	
	unitEntry.Button:RegisterCallback( Mouse.eLClick, function() OnUnitEntryClicked(pUnit:GetID(), unitEntry, false)  end); -- left click does not close
	unitEntry.Button:RegisterCallback( Mouse.eMClick, function() BQUI_CalculateUnits( BQUI_UnitType, unitEntry.BQUI_UnitsSum ); end );    -- bolbas (Middle Click on Unit List entries added - shows total number of units of that type)
	unitEntry.Button:RegisterCallback( Mouse.eRClick, function() OnUnitEntryClicked(pUnit:GetID(), unitEntry, true) end); -- right click closes

	-- HEALTH
	-- Infixo: this is Firaxis' function from UnitPanel.lua
	local function GetPercentFromDamage( damage:number, maxDamage:number )
		if damage > maxDamage then
			damage = maxDamage;
		end
		return (damage / maxDamage);
	end
	local percent:number = 1 - GetPercentFromDamage( pUnit:GetDamage(), pUnit:GetMaxDamage() );
	if percent < 1 then
		unitEntry.BQUI_HPBarBG:SetShow(true);
		unitEntry.BQUI_HPBar:SetShow(true);
		local sizeY = math.max ( math.floor( (14 * percent) + 0.5 ), 2 );    -- bolbas: !!!!! next 3 lines here because Direction="Up" is bugged for bars in UnitPanel.xml. It works only when Speed="1" or more and doesn't work when Speed="0" !!!!! -- bolbas: added "math.max" to make low hp bars more visible
		unitEntry.BQUI_HPBar:SetSizeY( sizeY );
		unitEntry.BQUI_HPBar:SetPercent( 1 );

		if	( percent > 0.7 )	then
			unitEntry.BQUI_HPBar:SetColor( COLORS.METER_HP_GOOD );
		elseif ( percent > 0.4 )	then
			unitEntry.BQUI_HPBar:SetColor( COLORS.METER_HP_OK );
		else
			unitEntry.BQUI_HPBar:SetColor( COLORS.METER_HP_BAD );
		end
	else -- no damage
		unitEntry.BQUI_HPBarBG:SetShow(false);
		unitEntry.BQUI_HPBar:SetShow(false);
	end

	-- Unit icon
	UpdateUnitIcon(pUnit, unitEntry);
	unitEntry.UnitTypeIcon:SetShow(true); -- always show

	-- Update status icon
	unitEntry.UnitStatusIcon:SetShow(true); -- default, hidden in some cases only
	local activityType:number = UnitManager.GetActivityType(pUnit);
	if UnitManager.GetQueuedDestination( pUnit ) then
		unitEntry.UnitStatusIcon:SetIcon("ICON_MOVES");
	elseif pUnit:GetFortifyTurns() > 0 then
		unitEntry.UnitStatusIcon:SetIcon("ICON_DEFENSE");
	elseif activityType == ActivityTypes.ACTIVITY_HEAL      then unitEntry.UnitStatusIcon:SetIcon("ICON_DAMAGE");
	elseif activityType == ActivityTypes.ACTIVITY_HOLD      then unitEntry.UnitStatusIcon:SetIcon("ICON_STATS_SKIP");
	elseif activityType == ActivityTypes.ACTIVITY_INTERCEPT then unitEntry.UnitStatusIcon:SetIcon("ICON_STATS_INTERCEPTOR");
	elseif activityType == ActivityTypes.ACTIVITY_OPERATION then unitEntry.UnitStatusIcon:SetIcon("ICON_OVERVIEW");
	elseif activityType == ActivityTypes.ACTIVITY_SENTRY    then unitEntry.UnitStatusIcon:SetIcon("ICON_STATS_GENERIC_MODIFIER");
	elseif activityType == ActivityTypes.ACTIVITY_SLEEP     then unitEntry.UnitStatusIcon:SetIcon("ICON_STATS_SLEEP");
	else
		unitEntry.UnitStatusIcon:SetHide(true);
	end

	-- Update entry color if unit cannot take any action
	if pUnit:IsReadyToMove() then
		unitEntry.UnitTypeIcon:SetColorByName("UnitPanelTextCS");
		unitEntry.UnitName:SetColorByName("UnitPanelTextCS");
		unitEntry.ReligionIcon:SetColorByName("UnitPanelTextCS");
		unitEntry.UnitStatusIcon:SetColorByName("UnitPanelTextCS");
		unitEntry.CountLabel:SetColorByName("UnitPanelTextCS");
		unitEntry.LeviedUnitIcon:SetColorByName("UnitPanelTextCS");
		unitEntry.PromotionIcon1:SetColorByName("UnitPanelTextCS");
		unitEntry.PromotionIcon2:SetColorByName("UnitPanelTextCS");
		unitEntry.PromotionIcon3:SetColorByName("UnitPanelTextCS");
	else
		unitEntry.UnitTypeIcon:SetColorByName("UnitPanelTextDisabledCS");
		unitEntry.UnitName:SetColorByName("UnitPanelTextDisabledCS");
		unitEntry.ReligionIcon:SetColorByName("UnitPanelTextDisabledCS");
		unitEntry.UnitStatusIcon:SetColorByName("UnitPanelTextDisabledCS");
		unitEntry.CountLabel:SetColorByName("UnitPanelTextDisabledCS");
		unitEntry.LeviedUnitIcon:SetColorByName("UnitPanelTextDisabledCS");
		unitEntry.PromotionIcon1:SetColorByName("UnitPanelTextDisabledCS");
		unitEntry.PromotionIcon2:SetColorByName("UnitPanelTextDisabledCS");
		unitEntry.PromotionIcon3:SetColorByName("UnitPanelTextDisabledCS");
	end
	
	-- Infixo: build and show the tooltip
	unitEntry.Button:SetToolTipString(table.concat(tt, "[NEWLINE]"));
end

-- INFIXO: END OF BOLBAS' CODE



-- ===========================================================================
function OnUnitEntryClicked(unitID:number, unitEntry:table, closeList:boolean)
	local playerUnits:table = Players[Game.GetLocalPlayer()]:GetUnits();
	local selectedUnit:table = nil;
	if playerUnits then
		selectedUnit = playerUnits:FindID(unitID);
		if selectedUnit then
			UI.LookAtPlot(selectedUnit:GetX(), selectedUnit:GetY());
			UI.SelectUnit( selectedUnit );
		end
	end
	-- Infixo: close list, no tricks here
	if closeList then
		UpdateUnitListPanel(true); 
		StartUnitListSizeUpdate();
		return;
	end
	-- Infixo: remove highlight from all units and toggle the selected one
	for _,uiChild in ipairs(m_unitListInstance.UnitStack:GetChildren()) do
		uiChild:SetTexture("Controls_ButtonControl");
	end
	if selectedUnit then
		unitEntry.Button:SetTexture("Controls_ButtonControl_Tan");
	end
end




-- ===========================================================================
--	Game Engine Event
function OnUnitSelectionChanged( playerID:number, unitID:number, hexI:number, hexJ:number, hexK:number, isSelected:boolean, isEditable:boolean )
	if playerID ~= Game.GetLocalPlayer() then 
		return;
	end
	if isSelected then
		-- Infixo: toggle the selected one
		for _,uiChild in ipairs(m_unitListInstance.UnitStack:GetChildren()) do
			if uiChild:GetVoid1() == unitID then
				uiChild:SetTexture("Controls_ButtonControl_Tan");
				break;
			end
		end
	else
		-- Infixo: remove highlight
		for _,uiChild in ipairs(m_unitListInstance.UnitStack:GetChildren()) do
			if uiChild:GetVoid1() == unitID then
				uiChild:SetTexture("Controls_ButtonControl");
				break;
			end
		end
	end
end


-- ===========================================================================





-- ===========================================================================
function Subscribe()
	Events.UnitSelectionChanged.Add( OnUnitSelectionChanged ); -- Infixo
end

-- ===========================================================================
function Unsubscribe()
	Events.UnitSelectionChanged.Remove( OnUnitSelectionChanged ); -- Infixo
end




-- ===========================================================================
function Initialize()
	Controls.ToggleAllButton:RegisterCheckHandler( function() ToggleAll(not Controls.ToggleAllButton:IsChecked()) end);

	Controls.CivilianListButton:RegisterCallback( Mouse.eLClick,
		function()
			if not m_hideUnitList and m_isUnitListMilitary then m_hideUnitList = true; end -- showing military units -> change to civilian -> simulate "hidden"
			m_isUnitListMilitary = false;
			m_unitListInstance.TraderCheck:SetHide(false);
			UpdateUnitListPanel(not m_hideUnitList); 
			StartUnitListSizeUpdate();
		end);
		
	Controls.MilitaryListButton:RegisterCallback( Mouse.eLClick,
		function()
			if not m_hideUnitList and not m_isUnitListMilitary then m_hideUnitList = true; end -- showing civilian units -> change to military -> simulate "hidden"
			m_isUnitListMilitary = true;
			m_unitListInstance.TraderCheck:SetHide(true);
			UpdateUnitListPanel(not m_hideUnitList);
			StartUnitListSizeUpdate();
		end);
		
	m_unitListInstance.CloseButton:RegisterCallback( Mouse.eLClick,
		function()
			m_hideUnitList = true;
			UpdateUnitListPanel(m_hideUnitList);
			StartUnitListSizeUpdate();
		end);
		
	m_unitListInstance.TraderCheck:SetCheck(m_showTrader);
	m_unitListInstance.TraderCheck:RegisterCheckHandler(
		function()
			m_showTrader = not m_showTrader;
			m_unitListInstance.TraderCheck:SetCheck(m_showTrader);
			UpdateUnitListPanel(m_hideUnitList);
			StartUnitListSizeUpdate();
		end);
		


	InitializeUnitAbilities();
end
Initialize();

-- print("Loaded WorldTracker.lua from Better World Tracker Units");
