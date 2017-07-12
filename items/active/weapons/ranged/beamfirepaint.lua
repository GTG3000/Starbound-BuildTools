require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

BeamFire = WeaponAbility:new()

function BeamFire:init()
	activeItem.setInstanceValue("retainScriptStorageInItem",true)
	self.damageConfig.baseDamage = self.baseDps * self.fireTime

	self.weapon:setStance(self.stances.idle)

	self.holdTimer = 0
	self.doubletapTimer = 0
	self.renderTimer = 0
	self.renderTime = 0.25
	self.fireModeLast = false
	self.shiftHoldSupressed = false
	self.shiftHoldComplete = false
	self.tapDelay = 0.5
	self.holdDelay = 2

	self.weapon.onLeaveAbility = function()
		self.weapon:setDamage()
		activeItem.setScriptedAnimationParameter("chains", {})
		animator.setParticleEmitterActive("beamCollision", false)
		animator.stopAllSounds("fireLoop")
		self.weapon:setStance(self.stances.idle)
	end
	
	storage.colourIndex = storage.colourIndex or 1
	storage.sizeIndex = storage.sizeIndex or 1
	
	--chain settings (overriding aegisaltpistol defaults)
	self.chain.renderLayer = "ForegroundOverlay"
	self.chain.segmentSize = 2
	self.chain.waveform = nil
	self.chain.endSegmentImage = nil
	self.chain.startOffset = nil
	self.chain.overdrawLength = 0
	self.bSegment = "/particles/treestems/wood.png"
	
	--rectangle select (bottom left x, bottom left y, top right x, top right y)
	local aimpos = activeItem.ownerAimPosition()
	storage.points = storage.points or false--{math.floor(aimpos[1]),math.floor(aimpos[2]),math.floor(aimpos[1]),math.floor(aimpos[2])}
	
	storage.maskData = storage.maskData or false
	
	self.modeMax = {5,6} -- normal, mask
	storage.mode = storage.mode or 1
	storage.altMode = storage.altMode or 1
	storage.modeMask = storage.modeMask or 1
	
	self.modeFriendly = {
		{"Painting","Selecting colour","Selecting size","Filling selection","Replacing colour"},
		{"Selecting","Drawing mask","Colour to mask","Colour from mask","Fill mask","Invert mask"}
	}
	
	
	self.colours 	= {"808080","ff0000","ff8000","ffff00","00ff00","0000ff","d22dc1","ffffff","101010"}
	self.cValue 	= {0,1,5,4,3,2,6,8,7}
	-- colours of the beam and corresponding material colour indexes
	--	0			1			2			3			4			5			6			7			8
	--{	"808080",	"ff0000",	"0000ff",	"00ff00",	"ffff00",	"ff8000",	"d22dc1",	"101010",	"ffffff"}
	self.sizes = {{0,0},{0,1},{-1,1},{-1,2},{-2,2}} -- offsets for the box sizes, topleft corner and bottomright. Only one number per corner since it's a square
	
	
end

function BeamFire:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)
	
	self.chain.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex]
	
	local beamStart = self:firePosition()
	local beamEnd = activeItem.ownerAimPosition()
	
	beamEnd[1] = math.floor(beamEnd[1])
	beamEnd[2] = math.floor(beamEnd[2])
	
	self.renderTimer = math.max(self.renderTimer-dt,0)
	
	if self.renderTimer == 0 then
		self.renderTimer = self.renderTime
		self:renderMask()
	end
	
	self:render(beamEnd)
	
	world.sendEntityMessage(activeItem.ownerEntityId(),"setBar","PaintToolBar",storage.mode/self.modeMax[storage.modeMask], storage.modeMask == 1 and {0,160,255,255} or {255,160,0,255})
	
	sb.setLogMap("^pink;TOOLSTATE^reset;",self.modeFriendly[storage.modeMask][storage.mode])
	
	
	if not shiftHeld then
		BeamFire["paint_"..storage.modeMask.."_"..storage.mode](self, fireMode) --do the mode
		
		if self.holdTimer > 0 and not self.shiftHoldSupressed then	--set up doubletapping, if shift was previously held and no mouse buttons were pressed
			self.doubletapTimer = self.tapDelay
		end
		self.doubletapTimer = math.max(self.doubletapTimer-dt,0)
		
		self.holdTimer = 0
		self.shiftHoldSupressed = false
		self.shiftHoldComplete = false
	else
		self.holdTimer = math.min(self.holdTimer+dt,self.holdDelay)
		if self.doubletapTimer > 0 then -- handle doubletapping
			self.shiftHoldSupressed = true
			self.doubletapTimer = 0
			storage.modeMask = storage.modeMask % 2 + 1
			storage.mode, storage.altMode = storage.altMode, storage.mode
		else	-- don't want to do other stuff at the same time as doubletapping. maybe add cooldown?
			if fireMode == "primary" or fireMode == "alt" then --supress shift holding trigger if modes were cycled, cycle modes as long as you like
				self.shiftHoldSupressed = true
			end
			
			if fireMode == "primary"
				and fireMode ~= self.fireModeLast
			then --cycle mode left
				storage.mode = storage.mode - 1
				if storage.mode < 1 then storage.mode = self.modeMax[storage.modeMask] end
			end
			
			if fireMode == "alt" 
				and fireMode ~= self.fireModeLast
			then --cycle mode right
				storage.mode = storage.mode % self.modeMax[storage.modeMask] + 1
			end
			
			if self.holdTimer == self.holdDelay --empty both selection and mask
				and not self.shiftHoldComplete
				and not self.shiftHoldSupressed
			then
				storage.points = false
				storage.maskData = false
				self.shiftHoldComplete = true
			end
		end
	end
	
	self.fireModeLast = fireMode
	self.shiftPressed = shiftHeld
	self.movePressed = self.movePressed and moves.up
end

function BeamFire:render(endPos)
	local chains = {}
	self.chain.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex]
	
	local newChain = copy(self.chain)
	newChain.startOffset = self.weapon.muzzleOffset
	newChain.endPosition = {endPos[1] + 1  - storage.sizeIndex%2/2,endPos[2] + 1  - storage.sizeIndex%2/2}
	
	local muzzlePos = vec2.add(mcontroller.position(),activeItem.handPosition(self.weapon.muzzleOffset))
	local length = world.magnitude(muzzlePos,newChain.endPosition)
	
	newChain.segmentSize = length
	newChain.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex].."?scale="..tostring(length*8)..";2;"
	
	table.insert(chains,newChain)
	
	local pos1 = vec2.add(endPos,{self.sizes[storage.sizeIndex][1],self.sizes[storage.sizeIndex][1]})-- making a rectangle. sizes[x][1] is the upper right corner offset, sizes[x][2] is the lower left corner offset
	local pos2 = vec2.add(endPos,{self.sizes[storage.sizeIndex][2]+1,self.sizes[storage.sizeIndex][2]+1})
	self:renderBox({pos1[1],pos1[2],pos2[1],pos2[2]},chains,"?setcolor="..self.colours[storage.colourIndex])
	
	if storage.points then
		self:renderBox(storage.points,chains,"?setcolor=ffa000;")
	end

	activeItem.setScriptedAnimationParameter("chains", chains)
end

function BeamFire:renderBox(rectangle,outputTable,directives)
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

function BeamFire:renderMask()
	if not storage.maskData or not storage.points then return false end
	local DRAW = false
	
	local pixel ={
		timeToLive = 0,
		speed = 0,
		damageTeam = {type = "passive"},
		bounces = -1,
		speedLimit = 0,
		maxMovementPerStep = 0,
		movementSettings = {
			collisionEnabled = false,
			collisionPoly = {{0,2000},{0,2000}}
		},
		actionOnReap = {
			
		}
	}
	
	local particle = {
		action = "particle",
		["time"] = 0,
		["repeat"] = false,
		specification = {
			["type"] = "textured",
			image = "/particles/treestems/wood.png?setcolor=ffffff?multiply=ff404040",
			layer = "front",
			timeToLive = self.renderTime*3/4,
			fullbright = true,
			destructionAction = "fade",
			size = 8,
			color = {255, 255, 255, 255},
			position = {0.5,0.5},
			hydrophobic = false,
			destructionTime = self.renderTime/4	
		}
	}
	for i,temp_table in pairs(storage.maskData) do
		for j,v in pairs(temp_table) do
			if v then
				DRAW = true
				local lParticle = copy(particle)
				lParticle.specification.position = {tonumber(i) - storage.points[1] + 0.5,tonumber(j)-storage.points[2] + 0.5}
				table.insert(pixel.actionOnReap,lParticle)
			end
		end
	end
	if DRAW then world.spawnProjectile("invisibleprojectile",world.xwrap({storage.points[1],storage.points[2]}), activeItem.ownerEntityId(), {0, 0}, true, pixel) end
end

function BeamFire:inSelection(pos,useMask)
	if not storage.points then return true end
	if useMask and storage.maskData then
		s1 = tostring(pos[1])
		s2 = tostring(pos[2])
		return (pos[1] >= storage.points[1]) and (pos[2] >= storage.points[2]) and (pos[1] < storage.points[3]) and ((pos[2] < storage.points[4]) and (storage.maskData[s1] and not storage.maskData[s1][s2]) or not storage.maskData[s1])
	else
		return (pos[1] >= storage.points[1]) and (pos[2] >= storage.points[2]) and (pos[1] < storage.points[3]) and (pos[2] < storage.points[4])
	end
end


function BeamFire:paint_1_1(fireMode) -- normal painting

	local beamEnd = activeItem.ownerAimPosition()
	beamEnd[1] = math.floor(beamEnd[1])
	beamEnd[2] = math.floor(beamEnd[2])
	
	if fireMode == "primary"
	then
		for i = beamEnd[1]+self.sizes[storage.sizeIndex][1],beamEnd[1]+self.sizes[storage.sizeIndex][2] do
			for j = beamEnd[2]+self.sizes[storage.sizeIndex][1],beamEnd[2]+self.sizes[storage.sizeIndex][2] do
				if self:inSelection({i,j},true) then
					world.setMaterialColor(world.xwrap({i,j}),"foreground",self.cValue[storage.colourIndex])
				end
			end
		end
	end
	
	if fireMode == "alt"
	then		
		for i = beamEnd[1]+self.sizes[storage.sizeIndex][1],beamEnd[1]+self.sizes[storage.sizeIndex][2] do
			for j = beamEnd[2]+self.sizes[storage.sizeIndex][1],beamEnd[2]+self.sizes[storage.sizeIndex][2] do
				if self:inSelection({i,j},true) then
					world.setMaterialColor(world.xwrap({i,j}),"background",self.cValue[storage.colourIndex])
				end
			end
		end
	end	
end


function BeamFire:paint_1_2(fireMode) -- change colour
	if fireMode == "primary"
		and fireMode ~= self.fireModeLast 
	then
		storage.colourIndex = storage.colourIndex - 1
		if storage.colourIndex < 1 then storage.colourIndex = 9 end
	end
	
	if fireMode == "alt"
		and fireMode ~= self.fireModeLast 
	then
		storage.colourIndex = storage.colourIndex % 9 + 1
	end
end


function BeamFire:paint_1_3(fireMode) -- change sizeIndex
	local size = #self.sizes
	if fireMode == "primary"
		and fireMode ~= self.fireModeLast 
	then
		storage.sizeIndex = storage.sizeIndex - 1
		if storage.sizeIndex < 1 then storage.sizeIndex = size end
	end
	
	if fireMode == "alt"
		and fireMode ~= self.fireModeLast 
	then
		storage.sizeIndex = storage.sizeIndex % size + 1
	end	
end


function BeamFire:paint_1_4(fireMode) -- fill selection
	if not storage.points then return false end
	
	if (fireMode == "primary" or fireMode == "alt") 
		and fireMode ~= self.fireModeLast 
	then
		local layer = (fireMode == "primary") and "foreground" or "background"
		for i = storage.points[1], storage.points[3]-1 do
			for j = storage.points[2], storage.points[4]-1 do
				if self:inSelection({i,j},true) then
					world.setMaterialColor(world.xwrap({i,j}),layer,self.cValue[storage.colourIndex])
				end
			end
		end
	end
end


function BeamFire:paint_1_5(fireMode) -- replace color with selected
	if not storage.points then return false end
	
	if (fireMode == "primary" or fireMode == "alt") 
		and fireMode ~= self.fireModeLast 
	then
		local aim = activeItem.ownerAimPosition()
		aim[1] = math.floor(aim[1])
		aim[2] = math.floor(aim[2])
		local layer = (fireMode == "primary") and "foreground" or "background"
		local color = world.materialColor(world.xwrap(aim),layer)
		for i = storage.points[1], storage.points[3]-1 do
			for j = storage.points[2], storage.points[4]-1 do
				if self:inSelection({i,j},true) 
					and world.materialColor(world.xwrap{i,j},layer) == color 
				then
					world.setMaterialColor(world.xwrap({i,j}),layer,self.cValue[storage.colourIndex])
				end
			end
		end
	end
end


function BeamFire:paint_2_1(fireMode) -- select area
	local pos = activeItem.ownerAimPosition()
	if not storage.points then storage.points = {pos[1],pos[2],pos[1],pos[2]} end
	if fireMode == "primary"
		--and fireMode ~= self.fireModeLast
	then
		pos[1] = math.floor(pos[1])
		pos[2] = math.floor(pos[2])
		
		if pos[1] <= storage.points[3] then
			storage.points[1] = pos[1]
		else
			storage.points[1] = storage.points[3]+1
			storage.points[3] = pos[1]
		end
			
		if pos[2] <= storage.points[4] then
			storage.points[2] = pos[2]
		else
			storage.points[2] = storage.points[4]+1
			storage.points[4] = pos[2]
		end
	end
	
	if fireMode == "alt"
		--and fireMode ~= self.fireModeLast
	then
		pos[1] = math.floor(pos[1]+1)
		pos[2] = math.floor(pos[2]+1)
		
		if pos[1] >= storage.points[1] then
			storage.points[3] = pos[1]
		else
			storage.points[3] = storage.points[1]-1
			storage.points[1] = pos[1]
		end
			
		if pos[2] >= storage.points[2] then
			storage.points[4] = pos[2]
		else
			storage.points[4] = storage.points[2]-1
			storage.points[2] = pos[2]
		end
	end
end


function BeamFire:paint_2_2(fireMode) -- draw mask
	if not storage.maskData then storage.maskData = {} end
	
	if (fireMode == "primary" or fireMode == "alt")
	then
		local aim = activeItem.ownerAimPosition()
		aim[1] = math.floor(aim[1])
		aim[2] = math.floor(aim[2])
		local value = (fireMode == "primary") and true or nil
		for i =  aim[1]+self.sizes[storage.sizeIndex][1],aim[1]+self.sizes[storage.sizeIndex][2] do
			local si = tostring(i)
			for j = aim[2]+self.sizes[storage.sizeIndex][1],aim[2]+self.sizes[storage.sizeIndex][2] do
				if self:inSelection({i,j}) then
					local sj = tostring(j)
					storage.maskData[si][sj] = value
				end
			end
			if next(storage.maskData[si]) == nil then storage.maskData[si] = nil end
		end
		if next(storage.maskData)==nil then storage.maskData = false end
	end
end


function BeamFire:paint_2_3(fireMode) -- colour to mask
	if not storage.points then return false end
	if not storage.maskData then storage.maskData = {} end
	
	if (fireMode == "primary" or fireMode == "alt") 
		and fireMode ~= self.fireModeLast 
	then
		local aim = activeItem.ownerAimPosition()
		aim[1] = math.floor(aim[1])
		aim[2] = math.floor(aim[2])
		local layer = (fireMode == "primary") and "foreground" or "background"
		local color = world.materialColor(world.xwrap(aim),layer)
		for i = storage.points[1], storage.points[3]-1 do
			for j = storage.points[2], storage.points[4]-1 do
				if world.materialColor(world.xwrap{i,j},layer) == color 
				then
					if not storage.maskData[tostring(i)] then storage.maskData[tostring(i)] = {} end
					storage.maskData[tostring(i)][tostring(j)] = true
				end
			end
		end
	end
end


function BeamFire:paint_2_4(fireMode) -- colour from mask
	if not storage.points then return false end
	if not storage.maskData then return false end
	
	if (fireMode == "primary" or fireMode == "alt") 
		and fireMode ~= self.fireModeLast 
	then
		local aim = activeItem.ownerAimPosition()
		aim[1] = math.floor(aim[1])
		aim[2] = math.floor(aim[2])
		local layer = (fireMode == "primary") and "foreground" or "background"
		local color = world.materialColor(world.xwrap(aim),layer)
		for i = storage.points[1], storage.points[3]-1 do
			for j = storage.points[2], storage.points[4]-1 do
				if world.materialColor(world.xwrap{i,j},layer) == color 
				then
					local si = tostring(i)
					local sj = tostring(j)
					if storage.maskData[si] then  
						storage.maskData[si][sj] = nil
						if next(storage.maskData[si]) == nil then storage.maskData[si] = nil end
					end
				end
			end
		end
		if next(storage.maskData)==nil then storage.maskData = false end
	end
end


function BeamFire:paint_2_5(fireMode) -- fill/empty mask
	if not storage.points then return false end
	
	if (fireMode == "primary" or fireMode == "alt") 
		and fireMode ~= self.fireModeLast 
	then
		if fireMode == "primary" then
			if not storage.maskData then storage.maskData = {} end
			for i = storage.points[1], storage.points[3]-1 do
				for j = storage.points[2], storage.points[4]-1 do
					local si = tostring(i)
					local sj = tostring(j)		
					if not storage.maskData[si] then storage.maskData[si] = {} end
					storage.maskData[si][sj] = true
				end
			end
		else
			if not storage.maskData then return false end
			for i = storage.points[1], storage.points[3]-1 do
				for j = storage.points[2], storage.points[4]-1 do
					local si = tostring(i)
					local sj = tostring(j)		
					if storage.maskData[si] then
						storage.maskData[si][sj] = nil
						if next(storage.maskData[si]) == nil then storage.maskData[si] = nil end
					end
				end
			end
			if next(storage.maskData)==nil then storage.maskData = false end
		end
	end
	
end

function BeamFire:paint_2_6(fireMode) -- invert mask
	if not storage.points then return false end
	if not storage.maskData then storage.maskData = {} end
	
	if (fireMode == "primary" or fireMode == "alt") 
		and fireMode ~= self.fireModeLast 
	then
		for i = storage.points[1], storage.points[3]-1 do
			local si = tostring(i)	
			for j = storage.points[2], storage.points[4]-1 do
				local sj = tostring(j)	
				if not storage.maskData[si] then storage.maskData[si] = {} end
				if not storage.maskData[si][sj] then storage.maskData[si][sj] = true else storage.maskData[si][sj] = nil end
			end	
			if next(storage.maskData[si]) == nil then storage.maskData[si] = nil end
		end
		if next(storage.maskData)==nil then storage.maskData = false end
	end
end


function BeamFire:firePosition()
	return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function BeamFire:aimVector(inaccuracy)
	local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
	aimVector[1] = aimVector[1] * mcontroller.facingDirection()
	return aimVector
end

function BeamFire:uninit()
	self:reset()
	--sb.logInfo(sb.printJson(storage.maskData))
	world.sendEntityMessage(activeItem.ownerEntityId(),"removeBar","PaintToolBar")
end

function BeamFire:reset()
	self.weapon:setDamage()
	activeItem.setScriptedAnimationParameter("chains", {})
	animator.setParticleEmitterActive("beamCollision", false)
	animator.stopAllSounds("fireStart")
	animator.stopAllSounds("fireLoop")
end
