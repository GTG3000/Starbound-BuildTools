Framework = WeaponAbility:new()

function Framework:frameworkInit()
	activeItem.setInstanceValue("retainScriptStorageInItem",true)

	self.weapon.onLeaveAbility = function()
		self.weapon:setDamage()
		activeItem.setScriptedAnimationParameter("chains", {})
		animator.setParticleEmitterActive("beamCollision", false)
		animator.stopAllSounds("fireLoop")
		self.weapon:setStance(self.stances.idle)
	end
	
	self.renderTimer = 0
	self.renderTime = 0.25
	self.holdTimer = 0
	self.doubletapTimer = 0
	self.shiftHoldSupressed = false
	self.shiftHoldComplete = false
	self.tapDelay = 0.5
	self.holdDelay = 1.5
	
	--chain settings (overriding aegisaltpistol defaults)
	self.chain.renderLayer = "ForegroundOverlay"
	self.chain.segmentSize = 2
	self.chain.waveform = nil
	self.chain.endSegmentImage = nil
	self.chain.startOffset = nil
	self.chain.overdrawLength = 0
	self.bSegment = "/particles/treestems/wood.png"
	
	self.funcName = "function"
	
	self.modeMax = {1,1} -- normal, mask
	storage.mode = storage.mode or 1
	storage.altMode = storage.altMode or 1
	storage.modeMask = storage.modeMask or 1
	
	self.modeFriendly = {
		{"Blue"},
		{"Orange"}
	}
	
end

function Framework:frameworkUpdate(dt,fireMode,shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)
	sb.setLogMap("^pink;TOOLSTATE^reset;",self.modeFriendly[storage.modeMask][storage.mode])
	local a_c = (self.shiftHoldComplete or self.shiftHoldSupressed or self.holdTimer == 0) and 0 or math.floor(255 * self.holdTimer / self.holdDelay)	
	
	self.renderTimer = math.max(self.renderTimer-dt,0)
	
	local beamEnd = activeItem.ownerAimPosition()
	
	beamEnd[1] = math.floor(beamEnd[1])
	beamEnd[2] = math.floor(beamEnd[2])
	
	if self.renderTimer == 0 then
		self.renderTimer = self.renderTime
		self:render_regular()
		--self:renderMask()
		if self.cursorDisplay then
			self:renderCursorText(beamEnd)
			self.cursorDisplay = false
		end
	end
	
	world.sendEntityMessage(activeItem.ownerEntityId(),"setBar","PaintToolBar",storage.mode/self.modeMax[storage.modeMask], storage.modeMask == 1 and {a_c,160,255,255} or {255,160,a_c,255})
	
	if not shiftHeld or self.shiftHoldComplete then
		BeamFire[self.funcName.."_"..storage.modeMask.."_"..storage.mode](self, fireMode) --do the mode
		
		if self.holdTimer > 0 and not self.shiftHoldSupressed and not self.shiftHoldComplete then	--set up doubletapping, if shift was previously held and no mouse buttons were pressed
			self.doubletapTimer = self.tapDelay
		end
		self.doubletapTimer = math.max(self.doubletapTimer-dt,0)
		
		self.holdTimer = 0
		self.shiftHoldSupressed = false
		self.shiftHoldComplete = self.shiftHoldComplete and shiftHeld
	else
		self.holdTimer = math.min(self.holdTimer+dt,self.holdDelay)
		if self.doubletapTimer > 0 then -- handle doubletapping
			self.shiftHoldSupressed = true
			self.doubletapTimer = 0
			storage.modeMask = storage.modeMask % 2 + 1
			self.cursorDisplay = self.modeFriendly[storage.modeMask][storage.mode]
			storage.mode, storage.altMode = storage.altMode, storage.mode
			self.b_d = false
			self.b_u = false
			self.b_l = false
			self.b_r = false
		else	-- don't want to do other stuff at the same time as doubletapping. maybe add cooldown?
			if fireMode == "primary" or fireMode == "alt" then --supress shift holding trigger if modes were cycled, cycle modes as long as you like
				self.shiftHoldSupressed = true	
				self.b_d = false
				self.b_u = false
				self.b_l = false
				self.b_r = false
			end
			
			if fireMode == "primary"
				and fireMode ~= self.fireModeLast
			then --cycle mode left
				storage.mode = storage.mode - 1
				if storage.mode < 1 then storage.mode = self.modeMax[storage.modeMask] end
				self.cursorDisplay = self.modeFriendly[storage.modeMask][storage.mode]
			end
			
			if fireMode == "alt" 
				and fireMode ~= self.fireModeLast
			then --cycle mode right
				storage.mode = storage.mode % self.modeMax[storage.modeMask] + 1
				self.cursorDisplay = self.modeFriendly[storage.modeMask][storage.mode]
			end
			
			if self.holdTimer == self.holdDelay --empty both selection and mask
				and not self.shiftHoldComplete
				and not self.shiftHoldSupressed
			then
				self:shift_hold()
				self.shiftHoldComplete = true
			end
		end
	end
	
	self.fireModeLast = fireMode
	self.shiftPressed = shiftHeld
end

function Framework:render_regular()
end

function Framework:shift_hold()
end

function Framework:frameworkUnInit()
	world.sendEntityMessage(activeItem.ownerEntityId(),"removeBar","PaintToolBar")
	self.weapon:setDamage()
	activeItem.setScriptedAnimationParameter("chains", {})
	animator.setParticleEmitterActive("beamCollision", false)
	animator.stopAllSounds("fireStart")
	animator.stopAllSounds("fireLoop")
end

function Framework:renderCursorText(pos)
	local textParticle ={
		timeToLive = 0,
		speed = 0,
		damageTeam = {type = "passive"},
		damageType = "NoDamage",
		actionOnReap = {{
			action = "particle",
			damageTeam = {type = "passive"},
			specification = {
				timeToLive = self.renderTime,
				layer = "front",
				fullbright = true,
				["type"] = "text",
				size = 0.75,
				text = "^shadow;"..self.cursorDisplay.."^reset;",
				color = storage.modeMask == 1 and {0,160,255,255} or {255,160,0,255}
			}}
		}
	}
	world.spawnProjectile("invisibleprojectile",world.xwrap({pos[1],pos[2]+1.5}),activeItem.ownerEntityId(),{0,0},false,textParticle)
end

function Framework:renderBox(rectangle,outputTable,directives)
	if type(rectangle)~="table" or #rectangle~= 4 then return false end
	if not directives or type(directives)~="string" then directives = "" end
	
	local nC1 = copy(self.chain)
	local nC2 = copy(self.chain)
	local nC3 = copy(self.chain)
	local nC4 = copy(self.chain)
	
	local l1 = world.magnitude({rectangle[1],rectangle[2]},{rectangle[1],rectangle[4]})
	local l2 = world.magnitude({rectangle[1],rectangle[4]},{rectangle[3],rectangle[4]})
	
	nC1.segmentSize = l1
	nC2.segmentSize = l2
	nC3.segmentSize = l1
	nC4.segmentSize = l2
	
	nC1.segmentImage = self.bSegment.."?scale="..tostring(l1*8)..";2;"..directives
	nC2.segmentImage = self.bSegment.."?scale="..tostring(l2*8)..";2;"..directives
	nC3.segmentImage = self.bSegment.."?scale="..tostring(l1*8)..";2;"..directives
	nC4.segmentImage = self.bSegment.."?scale="..tostring(l2*8)..";2;"..directives
	

	nC1.startPosition = {rectangle[1],rectangle[2]}	-- start position 
	nC1.endPosition = {rectangle[1],rectangle[4]}		-- end position
	
	nC2.startPosition = {rectangle[1],rectangle[4]}
	nC2.endPosition = {rectangle[3],rectangle[4]}
	
	nC3.startPosition = {rectangle[3],rectangle[4]}
	nC3.endPosition = {rectangle[3],rectangle[2]}
	
	nC4.startPosition = {rectangle[3],rectangle[2]}
	nC4.endPosition = {rectangle[1],rectangle[2]}
	
	table.insert(outputTable,nC1)
	table.insert(outputTable,nC2)
	table.insert(outputTable,nC3)
	table.insert(outputTable,nC4)
end