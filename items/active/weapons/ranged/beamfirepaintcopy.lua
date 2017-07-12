require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

BeamFire = WeaponAbility:new()

function BeamFire:init()
	activeItem.setInstanceValue("retainScriptStorageInItem",true)
	self.damageConfig.baseDamage = self.baseDps * self.fireTime

	self.weapon:setStance(self.stances.idle)

	self.cooldownTimer = 0
	self.doubletapTimer = 0
	self.fireModeLast = false

	self.weapon.onLeaveAbility = function()
		self.weapon:setDamage()
		activeItem.setScriptedAnimationParameter("chains", {})
		animator.setParticleEmitterActive("beamCollision", false)
		animator.stopAllSounds("fireLoop")
		self.weapon:setStance(self.stances.idle)
	end
	
	storage.colourIndex = storage.colourIndex or 1
	
	local aimpos = activeItem.ownerAimPosition()
	--[[
	storage.points = storage.points or {{math.floor(aimpos[1]),math.floor(aimpos[2])},{math.floor(aimpos[1]),math.floor(aimpos[2])}} -- top left and bottom right, hopefully. Shouldn't matter actually
	if world.magnitude(storage.points[1],aimpos) > 100 then
		storage.points[1] = {math.floor(aimpos[1]-1),math.floor(aimpos[2]-1)}
	end
	if world.magnitude(storage.points[2],aimpos) > 100 then
		storage.points[2] = {math.floor(aimpos[1]+1),math.floor(aimpos[2]+1)}
	end]]
	
	--bottom left x, bottom left y, top right x, top right y
	storage.points = storage.points or {math.floor(aimpos[1]),math.floor(aimpos[2]),math.floor(aimpos[1]),math.floor(aimpos[2])}
	
	storage.storedData = storage.storedData or false
	storage.flipY = storage.flipY or false
	storage.flipX = storage.flipY or false
	
	
	--chain settings (overriding aegisaltpistol defaults)
	self.chain.renderLayer = "ForegroundOverlay"
	self.chain.segmentSize = 2
	self.chain.waveform = nil
	self.chain.endSegmentImage = nil
	self.chain.overdrawLength = 0
	self.bSegment = "/particles/treestems/wood.png"
	
	self.colours 	= {"808080","ff0000","ff8000","ffff00","00ff00","0000ff","d22dc1","ffffff","101010"}
	self.cValue 	= {0,1,5,4,3,2,6,8,7}
	self.rValue		= {1,2,6,5,4,3,7,9,8}
	-- colours of the beam and corresponding material colour indexes
	--	0			1			2			3			4			5			6			7			8
	--{	"808080",	"ff0000",	"0000ff",	"00ff00",	"ffff00",	"ff8000",	"d22dc1",	"101010",	"ffffff"}
	
	self.modes = {"Selecting","Copying","Pasting","Flipping","Preview"}
	
	self.modeMax = 4
	storage.modeIndex = storage.modeIndex or 1
	
	
	--preview and shift-holding related stuff
	self.shiftDelay = 1.5 --hold shift for x to make preview appear
	self.shiftTimer = 0
	self.cooldown = 0
	self.cooldownValue = 1 --spawn preview projectile every x seconds, with particles lasting for x seconds
	self.bPreview = false
	
end

function BeamFire:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)	
	
	
	local beamStart = self:firePosition()
	local beamEnd = activeItem.ownerAimPosition()
	
	beamEnd[1] = math.floor(beamEnd[1])+0.5
	beamEnd[2] = math.floor(beamEnd[2])+0.5

	self:render(beamEnd)
	
	if shiftHeld then
		self.shiftTimer = math.min(self.shiftTimer + dt,self.shiftDelay)
		self.shiftPressed = true
	else
		if self.shiftTimer < 0.5 and self.shiftPressed then		
			storage.modeIndex = storage.modeIndex % self.modeMax +1
			storage.colourIndex = math.min(storage.modeIndex,9)
			self.shiftPressed = true
		end
		self.shiftTimer = 0
		self.bPreview = false
	end
	
	if self.shiftTimer == self.shiftDelay and not self.bPreview then
		self.bPreview = true
		--self:preview()
	end
	
	if self.bPreview then
		if self.cooldown < self.cooldownValue then
			self.cooldown = self.cooldown + dt
		else
			self.cooldown = 0
			self:preview()
		end
	end
	
	sb.setLogMap("^pink;TOOLSTATE^reset;",self.modes[storage.modeIndex])
	sb.setLogMap("^pink;FLIPPING^reset;",(storage.flipX and "horizontally" or "").." "..(storage.flipY and "vertically" or ""))
	
	BeamFire["paint_"..storage.modeIndex](self,dt, fireMode, shiftHeld)

	self.fireModeLast = fireMode
	self.shiftPressed = shiftHeld and self.shiftPressed
	self.movePressed = self.movePressed and moves.up
end

function BeamFire:render(endPos)
	local chains = {}
	
	self.chain.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex]
	
	local newChain = copy(self.chain)
	newChain.waveform = nil
	newChain.startOffset = self.weapon.muzzleOffset
	newChain.endPosition = endPos	
	
	local muzzlePos = vec2.add(mcontroller.position(),activeItem.handPosition(self.weapon.muzzleOffset))
	local length = world.magnitude(muzzlePos,endPos)
	
	newChain.segmentSize = length
	newChain.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex].."?scale="..tostring(length*8)..";2;"
	
	table.insert(chains,newChain)
	
	local nC1 = copy(self.chain)
	local nC2 = copy(self.chain)
	local nC3 = copy(self.chain)
	local nC4 = copy(self.chain)
	
	local l1 = world.magnitude({storage.points[1],storage.points[2]},{storage.points[1],storage.points[4]+1})
	local l2 = world.magnitude({storage.points[1],storage.points[4]+1},{storage.points[3]+1,storage.points[4]+1})
	
	nC1.segmentSize = l1
	nC2.segmentSize = l2
	nC3.segmentSize = l1
	nC4.segmentSize = l2
	
	nC1.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex].."?scale="..tostring(l1*8)..";2;"
	nC2.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex].."?scale="..tostring(l2*8)..";2;"
	nC3.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex].."?scale="..tostring(l1*8)..";2;"
	nC4.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex].."?scale="..tostring(l2*8)..";2;"
	
	--current selection rectangle
	nC1.startPosition = {storage.points[1],storage.points[2]}
	nC1.startOffset = nil														
	nC1.endPosition = {storage.points[1],storage.points[4]+1}
	
	nC2.startPosition = {storage.points[1],storage.points[4]+1}
	nC2.startOffset = nil
	nC2.endPosition = {storage.points[3]+1,storage.points[4]+1}
	
	nC3.startPosition = {storage.points[3]+1,storage.points[4]+1}
	nC3.startOffset = nil
	nC3.endPosition = {storage.points[3]+1,storage.points[2]}
	
	nC4.startPosition = {storage.points[3]+1,storage.points[2]}
	nC4.startOffset = nil
	nC4.endPosition = {storage.points[1],storage.points[2]}
	--current selection end
	table.insert(chains,nC1)
	table.insert(chains,nC2)
	table.insert(chains,nC3)
	table.insert(chains,nC4)
	
	--stored selection rectangle
	if storage.storedData and storage.storedData[1] then
		local sizeX = #storage.storedData
		local sizeY = #storage.storedData[1]
	
		l1 = world.magnitude({storage.points[1],storage.points[2]},{storage.points[1],storage.points[2]+sizeY})
		l2 = world.magnitude({storage.points[1],storage.points[2]+sizeY},{storage.points[1]+sizeX,storage.points[2]+sizeY})
	
		--self.chain.segmentImage = self.bSegment.."?setcolor=ff5a00?multiply=ffffff80"
		
		nC1 = copy(self.chain)
		nC2 = copy(self.chain)
		nC3 = copy(self.chain)
		nC4 = copy(self.chain)
	
		nC1.segmentSize = l1
		nC2.segmentSize = l2
		nC3.segmentSize = l1
		nC4.segmentSize = l2
	
		nC1.segmentImage = self.bSegment.."?setcolor=ff5a00?scale="..tostring(l1*8)..";1?multiply=ffffff80"
		nC2.segmentImage = self.bSegment.."?setcolor=ff5a00?scale="..tostring(l2*8)..";1?multiply=ffffff80"
		nC3.segmentImage = self.bSegment.."?setcolor=ff5a00?scale="..tostring(l1*8)..";1?multiply=ffffff80"
		nC4.segmentImage = self.bSegment.."?setcolor=ff5a00?scale="..tostring(l2*8)..";1?multiply=ffffff80"
		
		
		nC1.startPosition = {storage.points[1],storage.points[2]}
		nC1.startOffset = nil														
		nC1.endPosition = {storage.points[1],storage.points[2]+sizeY}
		
		nC2.startPosition = {storage.points[1],storage.points[2]+sizeY}
		nC2.startOffset = nil
		nC2.endPosition = {storage.points[1]+sizeX,storage.points[2]+sizeY}
		
		nC3.startPosition = {storage.points[1]+sizeX,storage.points[2]+sizeY}
		nC3.startOffset = nil
		nC3.endPosition = {storage.points[1]+sizeX,storage.points[2]}
		
		nC4.startPosition = {storage.points[1]+sizeX,storage.points[2]}
		nC4.startOffset = nil
		nC4.endPosition = {storage.points[1],storage.points[2]}
		
		table.insert(chains,nC1)
		table.insert(chains,nC2)
		table.insert(chains,nC3)
		table.insert(chains,nC4)
	end
	--stored selection rectangle ]]
	


	activeItem.setScriptedAnimationParameter("chains", chains)
end

function BeamFire:preview()
	if storage.storedData and storage.storedData[1] then
		local DRAW = false
		
		local sizeX = #storage.storedData
		local sizeY = #storage.storedData[1]
				
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
				image = "/particles/treestems/wood.png",
				layer = "front",
				timeToLive = self.cooldownValue,
				fullbright = true,
				destructionAction = "fade",
				size = 8,
				color = {255, 255, 255, 255},
				position = {0.5,0.5},
				hydrophobic = false,
				destructionTime = 0					
			}
		}
		for i = storage.points[1], storage.points[3] do
			local multiply = 1
			local j1 = storage.points[2]
			local lParticle = copy(particle)
			for j = storage.points[2], storage.points[4] do
			
				local posX = BeamFire:flipX(i,sizeX,storage.flipX)
				local posY = BeamFire:flipY(j,sizeY,storage.flipY)
							
				if posX > 0 
					and posY > 0
					and posX <= sizeX
					and posY <= sizeY
				then
					local cColour = storage.storedData[posX][posY]
					--[[lParticle.specification.color = {
						tonumber(cString:sub(1,2),16),
						tonumber(cString:sub(3,4),16),
						tonumber(cString:sub(5,6),16),
						255
					}]]
					if storage.storedData[posX][posY+1] ~= cColour then --optimisation, spawn one particle for a row of same values
						local cString = self.colours[self.rValue[cColour+1]]
						if cColour > 0 then
							DRAW = true
							lParticle.specification.image = lParticle.specification.image.."?setcolor="..cString.."?scale=1;"..multiply..";"
							lParticle.specification.position = {BeamFire:flipX(i,sizeX,false)-0.5,BeamFire:flipY((j+j1)/2,sizeY,false)-0.5}
							table.insert(pixel.actionOnReap,lParticle)
						end
						lParticle = copy(particle)
						j1 = j + 1
						multiply = 1
					else
						multiply = multiply + 1
					end
					
				end
			end
		end
		if DRAW then world.spawnProjectile("invisibleprojectile",world.xwrap({storage.points[1],storage.points[2]}), activeItem.ownerEntityId(), {0, 0}, true, pixel) end
	end
end

function BeamFire:firePosition()
	return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function BeamFire:paint_1(dt, fireMode, shiftHeld) --setting position

	if fireMode == "primary"
		--and fireMode ~= self.fireModeLast
	then
		local pos = activeItem.ownerAimPosition()
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
		local pos = activeItem.ownerAimPosition()
		pos[1] = math.floor(pos[1])
		pos[2] = math.floor(pos[2])
		
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

function BeamFire:paint_2(dt, fireMode, shiftHeld) --copying
	if fireMode == "primary" 
		and fireMode ~= self.fireModeLast 
	then	
		storage.storedData = {}
		for i = storage.points[1], storage.points[3] do
			storage.storedData[i-storage.points[1]+1] = {}
			for j = storage.points[2], storage.points[4] do
				storage.storedData[i-storage.points[1]+1][j-storage.points[2]+1] = world.materialColor(world.xwrap({i,j}),"foreground")
			end
		end
	end
	
	if fireMode == "alt" 
		and fireMode ~= self.fireModeLast 
	then	
		storage.storedData = {}
		for i = storage.points[1], storage.points[3] do
			storage.storedData[i-storage.points[1]+1] = {}
			for j = storage.points[2], storage.points[4] do
				storage.storedData[i-storage.points[1]+1][j-storage.points[2]+1] = world.materialColor(world.xwrap({i,j}),"background")
			end
		end
	end
	
end

function BeamFire:paint_3(dt, fireMode, shiftHeld) --pasting

	if fireMode == "primary"
		and fireMode ~= self.fireModeLast
		and storage.storedData
		and storage.storedData[1]
	then		
		local sizeX = #storage.storedData
		local sizeY = #storage.storedData[1]
		
		for i = storage.points[1], storage.points[3] do
			for j = storage.points[2], storage.points[4] do
			
				local posX = BeamFire:flipX(i,sizeX,storage.flipX)
				local posY = BeamFire:flipY(j,sizeY,storage.flipY)
			
				if posX > 0 
					and posY > 0
					and posX <= sizeX
					and posY <= sizeY
				then
					world.setMaterialColor(world.xwrap({i,j}),"foreground",storage.storedData[posX][posY] or 0)
				end
			end
		end
	end
	
	if fireMode == "alt"
		and fireMode ~= self.fireModeLast
		and storage.storedData
		and storage.storedData[1]
	then		
		local sizeX = #storage.storedData
		local sizeY = #storage.storedData[1]
		
		local debugString = ""
		
		for i = storage.points[1], storage.points[3] do
			for j = storage.points[2], storage.points[4] do
			
				local posX = BeamFire:flipX(i,sizeX,storage.flipX)
				local posY = BeamFire:flipY(j,sizeY,storage.flipY)
			
				if posX > 0 
					and posY > 0
					and posX <= sizeX
					and posY <= sizeY
				then
					world.setMaterialColor(world.xwrap({i,j}),"background",storage.storedData[posX][posY] or 0)
				end
			end
		end
	end
end

function BeamFire:paint_4(dt, fireMode, shiftHeld) --flipping
	if fireMode == "primary"
		and fireMode ~= self.fireModeLast
	then
		storage.flipX = not storage.flipX
	end
	
	if fireMode == "alt"
		and fireMode ~= self.fireModeLast
	then
		storage.flipY = not storage.flipY
	end
	
end

function BeamFire:flipX(iterator, size, flip)
	if flip then
		return size - (iterator - storage.points[1])
	else
		return iterator - storage.points[1] + 1
	end
end

function BeamFire:flipY(iterator, size, flip)
	if flip then
		return size - (iterator - storage.points[2])
	else
		return iterator - storage.points[2] + 1
	end
end

function BeamFire:uninit()
	self:reset()
	sb.setLogMap("^pink;TOOLSTATE^reset;","")
	sb.setLogMap("^pink;FLIPPING^reset;","")
end

function BeamFire:reset()
	self.weapon:setDamage()
	activeItem.setScriptedAnimationParameter("chains", {})
	animator.setParticleEmitterActive("beamCollision", false)
	animator.stopAllSounds("fireStart")
	animator.stopAllSounds("fireLoop")
end

