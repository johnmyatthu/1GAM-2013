require "core"

MainMenuScreen = class("MainMenuScreen", Screen )


function MainMenuScreen:OnNewGame(params)
end

function MainMenuScreen:OnOptions(params)
end


function MainMenuScreen:ShowHelp(params)
	self.screencontrol.last_screen = self.screencontrol:setActiveScreen("help", params)
end

function MainMenuScreen:OnQuit(params)
	love.event.push("quit")
end

function MainMenuScreen:StartNewGame(params)
	self.screencontrol:setActiveScreen("game", params)
end

function MainMenuScreen:initialize( params )
	Screen.initialize(self, params)
	self.selected_index = 1
	self.last_menu = nil
end

function MainMenuScreen:onShow( params )
	self.menu_activate = params.gamerules:playSound("menu_activate", false)
	self.menu_select = params.gamerules:playSound("menu_select", false)
	self.menu_back = params.gamerules:playSound("menu_back", false)

	self.menus = 
	{
		main =  {
			{name="New Game", action=MainMenuScreen.StartNewGame, target="newgame"},
			{name="Help", action=MainMenuScreen.ShowHelp},
			{name="Quit", action=MainMenuScreen.OnQuit}
		},

		options = {
			{name="Sound Volume", action=nil, value=1, scale=20, type="float"}
		}
	}

	self.options = self.menus.main



end

function MainMenuScreen:onHide( params )
end

function MainMenuScreen:onDraw( params )
	love.graphics.setFont( self.fonts["text16"] )
	love.graphics.setColor( 255, 255, 255, 255 )
	love.graphics.printf( "MainMenuScreen", 0, 50, love.graphics.getWidth(), "center" )

	local x = 0
	local y = 250

	for i,option in pairs(self.options) do
		local color = {255, 255, 255, 255}
		local display_string = option.name

		if i == self.selected_index then
			color = {255, 0, 0, 255}
			display_string = "> " .. option.name .. " <"
		end

		love.graphics.setColor(color[1], color[2], color[3], color[4])
		love.graphics.printf( display_string, x, y, love.graphics.getWidth(), "center" )
		y = y + 32
	end


end

function MainMenuScreen:onUpdate( params )
end


function MainMenuScreen:actionOnItem( action, params )
	local sound = nil
	local play_sound = true
	logging.verbose( "action: " .. action )

	if action == "back" then
		if self.last_menu then
			self.options = self.last_menu
			self.selected_index = 1
			self.last_menu = nil

			sound = self.menu_back
		end
		--love.event.push("quit")		
	elseif action == "activate" then
		local selected_option = self.options[ self.selected_index ]
		play_sound = (selected_option.target ~= nil)
		if selected_option.action then
			selected_option.action(self, params)
		end

		sound = self.menu_activate

		local target = selected_option.target
		if target then
			self.last_menu = self.options
			self.options = self.menus[ target ]
			self.selected_index = 1
		end		
	elseif action == "prev" or action == "next" then
		local delta = 1
		if action == "prev" then
			delta = -1
		end

		self.selected_index = self.selected_index + delta
		if self.selected_index > #self.options then
			self.selected_index = 1
		elseif self.selected_index < 1 then
			self.selected_index = #self.options
		end

		sound = self.menu_select
	
	end
	
	if sound and play_sound then
		sound:rewind()
		sound:play()
	end	
end

function MainMenuScreen:onKeyPressed( params )
	local action = ""

	if params.key == "escape" then
		action = "back"
	elseif params.key == "return" then
		action = "activate"
	elseif params.key == "up" or params.key == "down" then
		
		if params.key == "up" then
			action = "prev"
		else
			action = "next"
		end
	end

	self:actionOnItem( action, params )	
end

function MainMenuScreen:onKeyReleased( params )
end

function MainMenuScreen:onMousePressed( params )
end

function MainMenuScreen:onMouseReleased( params )
end

function MainMenuScreen:onJoystickPressed( params )
	logging.verbose( "on joy stick pressed: " .. params.joystick .. ", button: " .. params.button )
	local action = ""
	if params.button == 2 then
		action = "activate"
	elseif params.button == 3 then
		action = "back"
	end
	self:actionOnItem( action, params )
end

function MainMenuScreen:onJoystickReleased( params )
end