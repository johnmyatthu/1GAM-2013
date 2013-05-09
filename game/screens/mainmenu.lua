require "core"

MainMenuScreen = class("MainMenuScreen", Screen )


function MainMenuScreen:OnNewGame(params)
end

function MainMenuScreen:OnOptions(params)
end

function MainMenuScreen:OnQuit(params)
	love.event.push("quit")
end

function MainMenuScreen:initialize( fonts, screencontrol )
	Screen.initialize(self, fonts, screencontrol)

	self.selected_index = 1
	self.options = {
		{name="New Game", action=nil},
		{name="Options", action=nil},
		{name="Quit", action=MainMenuScreen.OnQuit}
	}
end

function MainMenuScreen:onShow( params )
	self.menu_activate = params.gamerules:playSound("menu_activate", false)
	self.menu_select = params.gamerules:playSound("menu_select", false)
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

function MainMenuScreen:onKeyPressed( params )
	if params.key == "escape" then
		love.event.push("quit")
	elseif params.key == "return" then
		local selected_option = self.options[ self.selected_index ]
		if selected_option.action then
			selected_option.action(self, params)
		end

		-- don't play the activate sound if the user is quitting
		if self.selected_index < #self.options then
			self.menu_activate:rewind()
			self.menu_activate:play()
		end
	elseif params.key == "up" or params.key == "down" then
		local delta = 1
		if params.key == "up" then
			delta = -1
		end


		self.selected_index = self.selected_index + delta
		if self.selected_index > #self.options then
			self.selected_index = 1
		elseif self.selected_index < 1 then
			self.selected_index = #self.options
		end


		self.menu_select:rewind()
		self.menu_select:play()		
	end
end

function MainMenuScreen:onKeyReleased( params )
end

function MainMenuScreen:onMousePressed( params )
end

function MainMenuScreen:onMouseReleased( params )
end

function MainMenuScreen:onJoystickPressed( params )
end

function MainMenuScreen:onJoystickReleased( params )
end