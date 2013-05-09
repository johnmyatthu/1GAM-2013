require "core"

LogoScreen = class("LogoScreen", Screen )

function LogoScreen:initialize( fonts, screencontrol )
	Screen.initialize(self, fonts, screencontrol)

	self.icon = love.graphics.newImage( "assets/logos/icon.png" )
	self.logo = love.graphics.newImage( "assets/logos/logo.png" )

	self.fade_states = {
		{ time=2, alpha=255 }, -- fade in seconds
		{ time=0.5, alpha=255 }, -- fade transition seconds		
		{ time=2, alpha=0 }, -- fade out seconds
	}

	self.fade_state = 1
	self.fade_time = 0

	self.current_alpha = 0

	self.finished = false
	self.sound = nil
end

function LogoScreen:draw_image( img, width, height )
	local sx = img:getWidth()
	local sy = img:getHeight()

	local xo = (love.graphics.getWidth() / 2) - (sx/2)
	if width ~= nil then
		xo = width
	end

	local yo = (love.graphics.getHeight() / 2) - (sy/2)
	if height ~= nil then
		yo = height
	end
	love.graphics.draw( img, xo, yo, 0, 1, 1, 0, 0 )
end

function LogoScreen:onShow( params )
	self.sound = params.gamerules:playSound( "menu_intro" )
end

function LogoScreen:onHide( params )
	if self.sound then
		self.sound:stop()
	end	
end

function LogoScreen:onDraw( params )
	love.graphics.setColor( 255, 255, 255, self.current_alpha )
	self:draw_image( self.icon, 20, 200 )
	self:draw_image( self.logo, nil, nil )	
end

function LogoScreen:onUpdate( params )
	if self.fade_state > #self.fade_states then
		return
	end

	self.fade_time = self.fade_time + params.dt
	local state = self.fade_states[ self.fade_state ]

	-- interpolate states
	self.current_alpha = self.current_alpha + (state.alpha-self.current_alpha) * (self.fade_time/state.time)
	
	if self.fade_time >= state.time then
		self.current_alpha = state.alpha
		if self.fade_state < #self.fade_states then
			self.fade_state = self.fade_state + 1
			self.fade_time = 0
		else
			self.finished = true
		end
	end
end


function LogoScreen:skipScreen(params)
	self.screencontrol:setActiveScreen("mainmenu", params)
end

function LogoScreen:onKeyPressed( params )
	if params.key == "escape" or params.key == " " then
		self:skipScreen(params)
	end
end

function LogoScreen:onMousePressed( params )
	self:skipScreen(params)
end

function LogoScreen:onJoystickPressed( params )
	self.skipScreen(params)
end