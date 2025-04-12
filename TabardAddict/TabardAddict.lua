--  ===============================
--	Tabard Addict - TabardAddict.lua
--	By: gmz323(Greg)
--  ===============================

-- Constants
local TABARD_ADDICT_VERSION = "1.05_3.3.5a"
local TABARD_ADDICT_DATA_ROWS = 70

-- Locals
local TabardAddictServerData = {} -- equip data from server

local CurrentTabardEntry_line = 0;
local CurrentTabardEntries_itemID = {} 
local CurrentTabardEntries_itemLink = {}

local tempDisplayData = {} -- temp table built to show subset of data
local tempDisplayData_rowcount;
local tabardsEquipped = 0;

-- Slash commands
SLASH_TABARDADDICT1 = "/ta"
SLASH_TABARDADDICT2 = "/tabardaddict"

local TabardAddict = LibStub("AceAddon-3.0"):NewAddon("TabardAddict", "AceConsole-3.0", "AceEvent-3.0")
local AceGUI = LibStub("AceGUI-3.0")

local defaults = {
    profile = {
        showAllianceOnly = true,
        showHordeOnly = true,
        showTCG = true,
        showOther = true,
    }
}

function TabardAddict:OnInitialize()
    -- Initialize database
    self.db = LibStub("AceDB-3.0"):New("TabardAddictDB", defaults)
    
    -- Register slash command
    self:RegisterChatCommand("ta", "SlashCommand")
    self:RegisterChatCommand("tabardaddict", "SlashCommand")
end

function TabardAddict:OnEnable()
    -- Nothing to do on enable
end

function TabardAddict:SlashCommand(input)
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    else
        self:ShowMainFrame()
    end
end

function TabardAddict:UpdateTabardList()
    if not self.scrollframe then return end
    
    -- Clear previous entries
    self.scrollframe:ReleaseChildren()
    
    -- Get tabard data
    local tabards = self:GetTabardList()
    
    -- Count equipped tabards and determine next achievement
    local nextAchievement = 0
    if tabardsEquipped >= 25 then
        nextAchievement = "none"
    elseif tabardsEquipped >= 10 then
        nextAchievement = 25
    elseif tabardsEquipped >= 1 then
        nextAchievement = 10
    else
        nextAchievement = 1
    end
    
    -- Update bottom status text
    if self.bottomStatus then
        self.bottomStatus:SetText(string.format("Equipped: |cff00ff00%d|r Next Achievement: |cffff9900%d|r Showing: |cffffffff%d|r", 
            tabardsEquipped, nextAchievement, #tabards))
    end
    
    -- Add tabard entries
    for _, tabardInfo in ipairs(tabards) do
        local entry = AceGUI:Create("SimpleGroup")
        entry:SetFullWidth(true)
        entry:SetHeight(50)
        entry:SetLayout("Flow")
        
        local icon = AceGUI:Create("Icon")
        icon:SetImage(tabardInfo.icon)
        icon:SetImageSize(36, 36)
        icon:SetWidth(40)
        icon:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(icon.frame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(tabardInfo.link)
            if IsModifiedClick("DRESSUP") then
                ShowInspectCursor()
            end
            GameTooltip:Show()
        end)
        icon:SetCallback("OnLeave", function()
            GameTooltip:Hide()
            ResetCursor()
        end)
        icon:SetCallback("OnClick", function(_, _, button)
            if IsModifiedClick("DRESSUP") then
                DressUpItemLink(tabardInfo.link)
            elseif IsModifiedClick("CHATLINK") then
                if ChatEdit_GetActiveWindow() then
                    ChatEdit_InsertLink(tabardInfo.link)
                end
            end
        end)
        entry:AddChild(icon)
        
        local name = AceGUI:Create("Label")
        name:SetText(tabardInfo.name)
        name:SetWidth(180)
        entry:AddChild(name)
        
        local equipped = AceGUI:Create("Label")
        equipped:SetText(tabardInfo.equipped and "|cff00FF00Been Equipped: Yes|r" or "|cffFF0000Been Equipped: No|r")
        equipped:SetWidth(120)
        entry:AddChild(equipped)
        
        -- Add faction icon if applicable
        if tabardInfo.faction == 1 or tabardInfo.faction == 2 then
            local factionIcon = AceGUI:Create("Icon")
            factionIcon:SetImage(tabardInfo.faction == 1 and 
                "Interface\\TargetingFrame\\UI-PVP-Alliance" or 
                "Interface\\TargetingFrame\\UI-PVP-Horde")
            factionIcon:SetImageSize(16, 16)
            factionIcon:SetWidth(20)
            entry:AddChild(factionIcon)
        end
        
        self.scrollframe:AddChild(entry)
    end
end

function TabardAddict:CreateTabardsTab(container)
    -- Create a container for the entire content
    local contentGroup = AceGUI:Create("SimpleGroup")
    contentGroup:SetLayout("List")
    contentGroup:SetFullWidth(true)
    contentGroup:SetFullHeight(true)
    container:AddChild(contentGroup)
    
    -- Add description text
    local desc = AceGUI:Create("Label")
    desc:SetText("Many of the tabards listed below may not be available to " .. UnitName("player") .. ". Check config tab for display filtering!")
    desc:SetFullWidth(true)
    contentGroup:AddChild(desc)
    
    -- Add tabard list
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    contentGroup:AddChild(scroll)
    
    -- Add status text at the bottom
    local status = AceGUI:Create("Label")
    status:SetFullWidth(true)
    contentGroup:AddChild(status)
    
    self.scrollframe = scroll
    self.bottomStatus = status
    
    -- Update the list
    self:UpdateTabardList()
end

function TabardAddict:CreateConfigTab(container)
    -- Create a container for the entire content
    local contentGroup = AceGUI:Create("SimpleGroup")
    contentGroup:SetLayout("List")
    contentGroup:SetFullWidth(true)
    contentGroup:SetFullHeight(true)
    container:AddChild(contentGroup)
    
    -- Add title
    local title = AceGUI:Create("Label")
    title:SetText("Tabard Display Configuration")
    title:SetFontObject(GameFontNormalLarge)
    title:SetFullWidth(true)
    contentGroup:AddChild(title)
    
    -- Add some spacing
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    contentGroup:AddChild(spacer)
    
    -- Alliance Only checkbox
    local allianceCheck = AceGUI:Create("CheckBox")
    allianceCheck:SetLabel("Show Alliance Only Tabards")
    allianceCheck:SetValue(self.db.profile.showAllianceOnly)
    allianceCheck:SetCallback("OnValueChanged", function(widget, event, value)
        self.db.profile.showAllianceOnly = value
        if self.scrollframe then
            self:UpdateTabardList()
        end
    end)
    allianceCheck:SetWidth(200)
    contentGroup:AddChild(allianceCheck)
    
    -- Horde Only checkbox
    local hordeCheck = AceGUI:Create("CheckBox")
    hordeCheck:SetLabel("Show Horde Only Tabards")
    hordeCheck:SetValue(self.db.profile.showHordeOnly)
    hordeCheck:SetCallback("OnValueChanged", function(widget, event, value)
        self.db.profile.showHordeOnly = value
        if self.scrollframe then
            self:UpdateTabardList()
        end
    end)
    hordeCheck:SetWidth(200)
    contentGroup:AddChild(hordeCheck)
    
    -- TCG checkbox
    local tcgCheck = AceGUI:Create("CheckBox")
    tcgCheck:SetLabel("Show TCG Tabards")
    tcgCheck:SetValue(self.db.profile.showTCG)
    tcgCheck:SetCallback("OnValueChanged", function(widget, event, value)
        self.db.profile.showTCG = value
        if self.scrollframe then
            self:UpdateTabardList()
        end
    end)
    tcgCheck:SetWidth(200)
    contentGroup:AddChild(tcgCheck)
    
    -- Other checkbox
    local otherCheck = AceGUI:Create("CheckBox")
    otherCheck:SetLabel("Show Other Tabards")
    otherCheck:SetValue(self.db.profile.showOther)
    otherCheck:SetCallback("OnValueChanged", function(widget, event, value)
        self.db.profile.showOther = value
        if self.scrollframe then
            self:UpdateTabardList()
        end
    end)
    otherCheck:SetWidth(200)
    contentGroup:AddChild(otherCheck)
end

function TabardAddict:CreateAboutTab(container)
    -- Create a container for the entire content
    local contentGroup = AceGUI:Create("SimpleGroup")
    contentGroup:SetLayout("List")
    contentGroup:SetFullWidth(true)
    contentGroup:SetFullHeight(true)
    container:AddChild(contentGroup)
    
    -- Add title
    local title = AceGUI:Create("Label")
    title:SetText("About Tabard Addict")
    title:SetFontObject(GameFontNormalLarge)
    title:SetFullWidth(true)
    contentGroup:AddChild(title)
    
    -- Add some spacing
    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    contentGroup:AddChild(spacer)
    
    -- Add main text
    local about = AceGUI:Create("Label")
    about:SetText("Tabard Addict is a simple mod that shows which tabards you have and have not equipped on your way to meeting the various tabard achievements. It also allows you to play dressup with tabards not available to your character.\n\nHold down CTRL and left click on a tabard icon to launch the Dressing Room.\n\nUse slash commands |cFFFF0000/ta|r or |cFFFF0000/tabardaddict|r to open and/or close the window.\n\nDownload updates and leave comments at: |cFFFFFF00wowinterface.com|r and |cFFFFFF00wow.curse.com|r\n\nAuthored by: |cFFFFFF00gmz323 (Greg)")
    about:SetFontObject(GameFontWhite)
    about:SetFullWidth(true)
    contentGroup:AddChild(about)
    
    -- Add version at the bottom
    local version = AceGUI:Create("Label")
    version:SetText("v" .. TABARD_ADDICT_VERSION)
    version:SetFontObject(GameFontNormal)
    version:SetFullWidth(true)
    contentGroup:AddChild(version)
    
    -- Set faction background
    local englishFaction = UnitFactionGroup("player")
    if englishFaction == "Horde" then
        -- Add Horde background if needed
    else
        -- Add Alliance background if needed
    end
end

function TabardAddict:ShowMainFrame()
    if not self.frame then
        local frame = AceGUI:Create("Frame")
        frame:SetTitle("Tabard Addict")
        frame:SetLayout("Fill")  -- Changed back to Fill for better layout
        frame:SetWidth(350)
        frame:SetHeight(500)
        
        -- Create the tab group
        local tab = AceGUI:Create("TabGroup")
        tab:SetLayout("Fill")  -- Changed to Fill for better content area
        tab:SetFullWidth(true)
        tab:SetFullHeight(true)
        tab:SetTabs({
            {text="Tabards", value="tabards"},
            {text="Config", value="config"},
            {text="About", value="about"}
        })
        frame:AddChild(tab)
        
        -- Setup tab content
        tab:SetCallback("OnGroupSelected", function(widget, event, group)
            widget:ReleaseChildren()
            if group == "tabards" then
                self:CreateTabardsTab(widget)
            elseif group == "config" then
                self:CreateConfigTab(widget)
            elseif group == "about" then
                self:CreateAboutTab(widget)
            end
        end)
        
        self.frame = frame
        self.tabgroup = tab
        
        -- Set initial tab
        tab:SelectTab("tabards")
    end
    
    self.frame:Show()
end

function TabardAddict:GetTabardList()
    -- Reset equipped count
    tabardsEquipped = 0
    
    -- Get server data for equipped tabards
    TabardAddict_GetServerData()
    
    -- Create display table
    local tabards = {}
    
    -- This creates a table by joining local tabard data and server results
    for _, tabardData in ipairs(taTabardData) do
        local displayThisRow = false
        
        -- determine if this row should be displayed based on settings
        if (tabardData[5] == 0 and self.db.profile.showOther) then
            displayThisRow = true
        elseif (tabardData[5] == 1 and self.db.profile.showAllianceOnly) then
            displayThisRow = true
        elseif (tabardData[5] == 2 and self.db.profile.showHordeOnly) then
            displayThisRow = true
        elseif (tabardData[5] == 3 and self.db.profile.showTCG) then
            displayThisRow = true
        end
        
        if displayThisRow then
            local isEquipped = false
            -- Check if tabard was equipped from server data
            for _, serverData in ipairs(TabardAddictServerData) do
                if serverData[1] == tabardData[1] then
                    isEquipped = serverData[2]
                    break
                end
            end
            
            -- Add tabard to display list
            table.insert(tabards, {
                id = tabardData[1],
                name = tabardData[2],
                link = tabardData[3],
                icon = tabardData[4],
                faction = tabardData[5],
                equipped = isEquipped
            })
        end
    end
    
    -- Sort by name
    table.sort(tabards, function(a,b) return a.name < b.name end)
    
    return tabards
end

--*****************************************************************************
--*****************************************************************************
local function TabardAddict_PopulateDisplayTable()
	
	local maintableRow, j, b1, b2, displayThisRow;
	
	wipe(tempDisplayData);
	
	tempDisplayData_rowcount = 0;
	
	-- This creates a temp table by joining local tabard data and server results
	for maintableRow in ipairs(taTabardData)
	do
		-- determine if this row should be displayed
		if ((taTabardData[maintableRow][5] == 0) and (TabardAddictConfigCB_Other == 1)) then
			displayThisRow = 1;
		elseif ((taTabardData[maintableRow][5] == 1) and (TabardAddictConfigCB_AO == 1)) then
			displayThisRow = 1; 
		elseif ((taTabardData[maintableRow][5] == 2) and (TabardAddictConfigCB_HO == 1)) then
			displayThisRow = 1; 
		elseif ((taTabardData[maintableRow][5] == 3) and (TabardAddictConfigCB_TCG == 1)) then
			displayThisRow = 1; 
		else
			displayThisRow = 0;
		end;
		
		if (displayThisRow == 1) then
			tempDisplayData_rowcount = tempDisplayData_rowcount + 1;
			tempDisplayData[tempDisplayData_rowcount] = {};     -- create a new row
			for j=1,4 do -- copy first 4 column
				tempDisplayData[tempDisplayData_rowcount][j] = taTabardData[maintableRow][j];
			end
			-- column 6 - alliance or horde indicator
			tempDisplayData[tempDisplayData_rowcount][6] = taTabardData[maintableRow][5];
		  
			-- init equipped bool
			tempDisplayData[tempDisplayData_rowcount][5] = false;
			
			-- set equipped bool from server data
			for b1,b2 in ipairs(TabardAddictServerData)
			do
				if (b2[1] == tempDisplayData[tempDisplayData_rowcount][1]) then
					tempDisplayData[tempDisplayData_rowcount][5] = TabardAddictServerData[b1][2];
				end
			end
		end
    end
end

--*****************************************************************************
--*****************************************************************************
local function TabardAddict_SortDisplayTable()

	-- currently sorting only on tabard name
	table.sort(tempDisplayData, function(a,b) return a[2]<b[2] end);
	
end

--*****************************************************************************
--*****************************************************************************
local function TabardAddict_OnEvent(self, event, ...)
	-- not currently handling any events
end
 
--*****************************************************************************
--*****************************************************************************
function TabardAddict_GetServerData() 

	local j,m,r,a,b;
	
	wipe(TabardAddictServerData);
	
	-- id 1020 = ten tabards achievement
	a=GetAchievementCriteriaInfo 
	for b=1,TABARD_ADDICT_DATA_ROWS
	do 
		_,_,_,_,_,_,_,_,_,j = a(1020,b); 
		_,_,m,_,_,_,_,r,_,_ = a(j);
		TabardAddictServerData[b] = {}     -- create a new row
		TabardAddictServerData[b][1] = r;  -- save id
		TabardAddictServerData[b][2] = m;  -- save "criteria met" true/false
		if m==true then
			-- increment total tabards equipped
			tabardsEquipped=tabardsEquipped + 1;
		end;
	end
end

--*****************************************************************************
--*****************************************************************************
function TabardAddictScrollBar_Update()
	local line; -- 1 through 8 of our window to scroll
	local lineplusoffset; -- an index into our data calculated from the scroll offset
	
	FauxScrollFrame_Update(TabardAddictScrollBar,tempDisplayData_rowcount,8,40);
	for line=1,8 do
		lineplusoffset = line + FauxScrollFrame_GetOffset(TabardAddictScrollBar);
		
		-- set alpha values for each row
		getglobal("TabardAddictEntry"..line).TabardAddictButtonBack:SetAlpha(0.35);
		getglobal("TabardAddictEntry"..line).TabardAddictButtonHighlight:SetAlpha(0.70);
		
		if lineplusoffset <= tempDisplayData_rowcount then
			getglobal("TabardAddictEntry"..line).TabardName:SetText(tempDisplayData[lineplusoffset][2]);
			getglobal("TabardAddictEntry"..line).TabardName:Show();
			
			-- check if equipped
			if (tempDisplayData[lineplusoffset][5] == true) then
				getglobal("TabardAddictEntry"..line).TabardEquipped:SetText("Been Equipped: |cff00FF00Yes|r");
				-- show overlay on equipped tabards
				getglobal("TabardAddictEntry"..line).TabardIconOverlay:Show(); 
				getglobal("TabardAddictEntry"..line).TabardIconOverlay:SetDrawLayer("OVERLAY",5);
			else
				getglobal("TabardAddictEntry"..line).TabardEquipped:SetText("Been Equipped: |cffFF0000No|r");
				getglobal("TabardAddictEntry"..line).TabardIconOverlay:Hide();
			end
			getglobal("TabardAddictEntry"..line).TabardEquipped:Show();
			
			-- set tabard icon texture
			getglobal("TabardAddictEntry"..line).TabardIcon:SetTexture(tempDisplayData[lineplusoffset][4]);
			getglobal("TabardAddictEntry"..line).TabardIcon:Show();
			
			-- set local vars
			CurrentTabardEntries_itemID[line] = tempDisplayData[lineplusoffset][1];
			CurrentTabardEntries_itemLink[line] = tempDisplayData[lineplusoffset][3];
			
			-- set faction icon
			if (tempDisplayData[lineplusoffset][6] == 2) then
				getglobal("TabardAddictEntry"..line).TabardFactionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Horde");
				getglobal("TabardAddictEntry"..line).TabardFactionIcon:Show();
				getglobal("TabardAddictEntry"..line).TabardFactionIcon:SetDrawLayer("OVERLAY",7);
			elseif (tempDisplayData[lineplusoffset][6] == 1) then
				getglobal("TabardAddictEntry"..line).TabardFactionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-Alliance");
				getglobal("TabardAddictEntry"..line).TabardFactionIcon:Show();
				getglobal("TabardAddictEntry"..line).TabardFactionIcon:SetDrawLayer("OVERLAY",7);
			else
				getglobal("TabardAddictEntry"..line).TabardFactionIcon:Hide();
			end;
			
			-- update tooltip
			if (CurrentTabardEntry_line > 0) then
				TabardAddictEntryButton_OnEnter(CurrentTabardEntry_line);
			end
		else
			getglobal("TabardAddictEntry"..line).TabardName:Hide();
			getglobal("TabardAddictEntry"..line).TabardEquipped:Hide();
			getglobal("TabardAddictEntry"..line).TabardIcon:Hide();
			getglobal("TabardAddictEntry"..line).TabardIconOverlay:Hide();
			getglobal("TabardAddictEntry"..line).TabardFactionIcon:Hide();
			-- set local vars
			CurrentTabardEntries_itemID[line] = 0;
			CurrentTabardEntries_itemLink[line] = 0;
			
			-- warn user
			if ((tempDisplayData_rowcount == 0) and (line == 2)) then
				getglobal("TabardAddictEntry"..line).TabardName:SetText("No Tabards to show - Check Config!");
				getglobal("TabardAddictEntry"..line).TabardName:Show();
			end;
		end
	end	
end

--*****************************************************************************
--*****************************************************************************
function TabardAddictEntryButton_OnEnter(line)
	CurrentTabardEntry_line = line;
end

--*****************************************************************************
--*****************************************************************************
function TabardAddictEntryButton_OnLeave()
	CurrentTabardEntry_line = 0;
	ResetCursor();
	GameTooltip:Hide();
end

--*****************************************************************************
--*****************************************************************************
function TabardAddictEntryButton_OnUpdate(line)
	
	local itemID = CurrentTabardEntries_itemID[line];
	
	-- Show tooltip if over tabard icon
	if ( (MouseIsOver(getglobal("TabardAddictEntry"..line).TabardIcon)) and (itemID > 0) ) then
		GameTooltip:SetOwner(frameTabardAddict, "ANCHOR_RIGHT", 0, -120);
		GameTooltip:SetHyperlink("item:"..itemID);
		GameTooltip:Show();
		-- if ctrl is down show inspect cursor else reset it
		if ( IsModifiedClick("DRESSUP") ) then
			ShowInspectCursor();
		else
			ResetCursor();
		end
	else
		-- not over icon - hide tooltip and reset cursor
		GameTooltip:Hide();
		ResetCursor();
	end
end

--*****************************************************************************
--*****************************************************************************
function TabardAddictEntryButton_OnModifiedClick(line)
	local itemID = CurrentTabardEntries_itemID[line];
	local itemLink = CurrentTabardEntries_itemLink[line];
	
	-- If there was a DRESSUP or CHATLINK click over a tabard icon handle it
	if ( (MouseIsOver(getglobal("TabardAddictEntry"..line).TabardIcon)) and (itemID > 0) ) then
		if ( IsModifiedClick("DRESSUP") ) then
			DressUpItemLink(itemID);
		elseif ( IsModifiedClick("CHATLINK") ) then
			if (ChatEdit_GetActiveWindow()) then
				ChatEdit_InsertLink(itemLink);
			end;
		end;
	end;
end

--*****************************************************************************
--*****************************************************************************
function TabardAddictTab_OnClick(self, tabID)
	if ( not tabID ) then
		tabID = self:GetID();
	end
	PanelTemplates_SetTab(frameTabardAddict, tabID);
	if ( tabID == 1 ) then
		-- Tabards tab clicked
		TabardAddictScrollBar:Show();
		TabardAddictTab1:Show();
		TabardAddictTab2:Hide();
		TabardAddictTab3:Hide();
		-- populate the display table
		TabardAddict_PopulateDisplayTable();
		-- sort the display table
		TabardAddict_SortDisplayTable();
		-- initial display
		TabardAddictScrollBar_Update();
		TabardAddictShowTabards();
	elseif ( tabID == 2 ) then
		-- Config tab clicked
		TabardAddictScrollBar:Hide();
		TabardAddictTab1:Hide();
		TabardAddictTab2:Show();
		TabardAddictTab3:Hide();
		-- set checkbox values
		CheckButtonAO:SetChecked(TabardAddictConfigCB_AO);
		CheckButtonHO:SetChecked(TabardAddictConfigCB_HO);
		CheckButtonTCG:SetChecked(TabardAddictConfigCB_TCG);
		CheckButtonOther:SetChecked(TabardAddictConfigCB_Other);
		TabardAddictHideTabards();
	elseif ( tabID == 3 ) then
		-- About tab clicked
		TabardAddictScrollBar:Hide();
		TabardAddictTab1:Hide();
		TabardAddictTab2:Hide();
		TabardAddictTab3:Show();
		TabardAddictHideTabards();
	end
	PlaySound("igCharacterInfoTab");
end

--*****************************************************************************
--*****************************************************************************
function TabardAddict_OnShow(self)
	
	local tabardsNextAchievement = 0;
	
	PlaySound("igCharacterInfoOpen");
	
	-- set description text
	TabardAddictTab1.taDescText:SetText("Many of the tabards listed below may not be available to "..UnitName("player")..". Check config tab for display filtering!");
	
	-- reset # of equipped tabards
	tabardsEquipped = 0;
	-- query server for data
	TabardAddict_GetServerData()

	-- populate counts
	if (tabardsEquipped >= 30) then
		tabardsNextAchievement = "none";
	elseif (tabardsEquipped >= 25) then
		tabardsNextAchievement = 30;
	elseif (tabardsEquipped >= 10) then
		tabardsNextAchievement = 25;
	elseif (tabardsEquipped >= 1) then
		tabardsNextAchievement = 10;
	else
		tabardsNextAchievement = 1;
	end;
	
	-- populate equipped count and next achievement text
	TabardAddictTab1.taTabardTotalText:SetText("Tabards Equipped: "..tabardsEquipped.."    Next Achievement: "..tabardsNextAchievement);
	
	-- populate the display table
	TabardAddict_PopulateDisplayTable();
	-- sort the display table
	TabardAddict_SortDisplayTable();
	-- initial display
	TabardAddictScrollBar_Update();
	
	-- show/hide panels
	TabardAddictTab1:Show();
	TabardAddictTab2:Hide();
	TabardAddictTab3:Hide();
	PanelTemplates_SetTab(frameTabardAddict, 1);
	TabardAddictShowTabards();
	
end

--*****************************************************************************
--*****************************************************************************
function TabardAddict_OnHide(self)

	PlaySound("igCharacterInfoClose");
	-- collectgarbage("collect");
end

--*****************************************************************************
--*****************************************************************************
function TabardAddictShowTabards()
	
	local line;

	for line=1,8 do
		getglobal("TabardAddictEntry"..line):Show();
	end;
end

--*****************************************************************************
--*****************************************************************************
function TabardAddictHideTabards()
	
	local line;

	for line=1,8 do
		getglobal("TabardAddictEntry"..line):Hide();
	end;
end

--*****************************************************************************
--*****************************************************************************
function TabardAddict_SetConfigVariables(self)

	if (CheckButtonAO:GetChecked() == 1) then
		TabardAddictConfigCB_AO = 1;
	else
		TabardAddictConfigCB_AO = 0;
	end;
	if (CheckButtonHO:GetChecked() == 1) then
		TabardAddictConfigCB_HO = 1;
	else
		TabardAddictConfigCB_HO = 0;
	end;
	if (CheckButtonTCG:GetChecked() == 1) then
		TabardAddictConfigCB_TCG = 1;
	else
		TabardAddictConfigCB_TCG = 0;
	end;
	if (CheckButtonOther:GetChecked() == 1) then
		TabardAddictConfigCB_Other = 1;
	else
		TabardAddictConfigCB_Other = 0;
	end;
	
end

--*****************************************************************************
--*****************************************************************************
function TabardAddict_OnLoad(self)

	-- Register the frame so it can be dragged
	self:RegisterForDrag("LeftButton")

	
	PanelTemplates_SetNumTabs(self, 3);
	PanelTemplates_SetTab(self, 1);
	
	
	TabardAddictTab1:Show();
	TabardAddictTab2:Hide();
	TabardAddictTab3:Hide();
	
	
	SetPortraitToTexture(self.taTabardEmblem, "Interface\\ICONS\\INV_Chest_Cloth_30")
	
	self.taTitleText:SetText("Tabard Addict");
	self.taVersionText:SetText("v"..TABARD_ADDICT_VERSION);
	
	-- set description text
	TabardAddictTab2.taConfigDescText:SetText("Tabard Display Configuration");
	TabardAddictTab3.taAboutDescText:SetText("About Tabard Addict");
	TabardAddictAboutInfo:SetText("Tabard Addict is a simple mod that shows which tabards you have and have not equipped on your way to meeting the various tabard achievements. It also allows you to play dressup with tabards not available to your character.|n|nHold down CTRL and left click on a tabard icon to launch the Dressing Room.|n|nUse slash commands |cFFFF0000/ta|r or |cFFFF0000/tabardaddict|r to open and/or close the window.|n|nDownload updates and leave comments at: |cFFFFFF00wowinterface.com|r and |cFFFFFF00wow.curse.com|r|n|nAuthored by: |cFFFFFF00gmz323 (Greg)|r");
	
	-- set alliance or horde background
	local englishFaction = UnitFactionGroup("player");
	if ( englishFaction == "Horde" ) then  -- horde
		TabardAddictBGFaction:Show();
		TabardAddictBGFaction2:Hide();
	else  -- alliance
		TabardAddictBGFaction:Hide();
		TabardAddictBGFaction2:Show();
	end;
	
	-- check for nil global config values
	if (TabardAddictConfigCB_AO == nil) then
		TabardAddictConfigCB_AO = 1;
	end;
	if (TabardAddictConfigCB_HO == nil) then
		TabardAddictConfigCB_HO = 1;
	end;
	if (TabardAddictConfigCB_TCG == nil) then
		TabardAddictConfigCB_TCG = 1;
	end;
	if (TabardAddictConfigCB_Other == nil) then
		TabardAddictConfigCB_Other = 1;
	end;
end;



