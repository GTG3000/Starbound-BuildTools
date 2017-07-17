require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/toolframework.lua"

BeamFire = Framework:new()

function BeamFire:init()
	self:frameworkInit()
	self.damageConfig.baseDamage = self.baseDps * self.fireTime

	self.weapon:setStance(self.stances.idle)

	self.fireModeLast = false
	
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
	storage.points = storage.points or false --{math.floor(aimpos[1]),math.floor(aimpos[2]),math.floor(aimpos[1]),math.floor(aimpos[2])}
	
	storage.storedData = storage.storedData or false
	storage.flipY = storage.flipY or false
	storage.flipX = storage.flipY or false
	
	
	self.modeMax = {2,2} -- normal, mask
	storage.mode = storage.mode or 1
	storage.altMode = storage.altMode or 1
	storage.modeMask = storage.modeMask or 1
	self.funcName = "paint"
	
	self.modeFriendly = {
		{"Copying","Pasting"},
		{"Selecting","Inverting"}
	}
	
	self.colours 	= {"808080","ff0000","ff8000","ffff00","00ff00","0000ff","d22dc1","ffffff","101010"}
	self.cValue 	= {0,1,5,4,3,2,6,8,7}
	self.rValue		= {1,2,6,5,4,3,7,9,8}
	-- colours of the beam and corresponding material colour indexes
	--	0			1			2			3			4			5			6			7			8
	--{	"808080",	"ff0000",	"0000ff",	"00ff00",	"ffff00",	"ff8000",	"d22dc1",	"101010",	"ffffff"}
	
	self.modes = {"Selecting","Copying","Pasting","Flipping","Preview"}
	
	
	--preview and shift-holding related stuff
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
	
	if self.bPreview then
		if self.cooldown > 0  then
			self.cooldown = self.cooldown - dt
		else
			self.cooldown = self.cooldownValue
			self:preview()
		end
	end
	
	--sb.setLogMap("^pink;TOOLSTATE^reset;",self.modes[storage.modeIndex])
	--sb.setLogMap("^pink;FLIPPING^reset;",(storage.flipX and "horizontally" or "").." "..(storage.flipY and "vertically" or ""))
	
	--BeamFire["paint_"..storage.modeIndex](self,dt, fireMode, shiftHeld)
	self:frameworkUpdate(dt, fireMode, shiftHeld)
	self.bPreview = self.bPreview and shiftHeld
	
end

function BeamFire:shift_hold()
	self.bPreview = true
	self.cooldown = 0
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
	
	
	if storage.points then
		local s_rect = {} --rectangle for highlighting selection modification
	
		--has to change if the coursor is over one of the edges or corners	
		if self.b_r and self.b_u then
			s_rect = {storage.points[3],storage.points[4],storage.points[3]+1,storage.points[4]+1}
		elseif self.b_r and self.b_d then
			s_rect = {storage.points[3],storage.points[2],storage.points[3]+1,storage.points[2]+1}
		elseif self.b_l and self.b_u then
			s_rect = {storage.points[1],storage.points[4],storage.points[1]+1,storage.points[4]+1}
		elseif self.b_l and self.b_d then
			s_rect = {storage.points[1],storage.points[2],storage.points[1]+1,storage.points[2]+1}
		elseif self.b_r then
			s_rect = {storage.points[3],storage.points[2],storage.points[3]+1,storage.points[4]+1}
		elseif self.b_l then
			s_rect = {storage.points[1],storage.points[2],storage.points[1]+1,storage.points[4]+1}
		elseif self.b_u then
			s_rect = {storage.points[1],storage.points[4],storage.points[3]+1,storage.points[4]+1}
		elseif self.b_d then
			s_rect = {storage.points[1],storage.points[2],storage.points[3]+1,storage.points[2]+1}
		end
	
		if #s_rect>0 then
			self:renderBox(s_rect,chains,"?setcolor=FFFF00")
		end
		
		self:renderBox({storage.points[1],storage.points[2],storage.points[3]+1,storage.points[4]+1},chains,"?setcolor=ffa000;")
	end
	
	--stored selection rectangle
	if storage.storedData and storage.storedData[1] and storage.points then
		local sizeX = #storage.storedData
		local sizeY = #storage.storedData[1]
		
		self:renderBox({storage.points[1],storage.points[2],storage.points[1]+sizeX,storage.points[2]+sizeY},chains,"?setcolor=ff5a00?multiply=ffffff80")
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
				local posYp = BeamFire:flipY(j+1,sizeY,storage.flipY)
							
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
					if storage.storedData[posX][posYp] ~= cColour 
						or (storage.flipY and posYp > BeamFire:flipY(storage.points[4]+2,sizeY,storage.flipY) or posYp > BeamFire:flipY(storage.points[4],sizeY,storage.flipY))
					then --optimisation, spawn one particle for a row of same values
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


function BeamFire:paint_1_1(fireMode) --copying
	if not storage.points then return false end
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


function BeamFire:paint_1_2(fireMode) --pasting
	if not storage.points then return false end
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


function BeamFire:paint_2_1(fireMode) --setting position
	local pos = activeItem.ownerAimPosition()
	pos[1] = math.floor(pos[1])
	pos[2] = math.floor(pos[2])
	
	if fireMode ~= self.fireModeLast then
		self.selPos = false
		self.selMove = false
		self.selMake = false
		self.cursorDisplay = false
	end
	
	if fireMode ~= "alt" and fireMode ~= "primary" and storage.points then
		self.b_l = pos[1] == storage.points[1] and pos[2] >= storage.points[2] and pos[2] <= storage.points[4]
		self.b_r = pos[1] == storage.points[3] and pos[2] >= storage.points[2] and pos[2] <= storage.points[4]
		self.b_d = pos[2] == storage.points[2] and pos[1] >= storage.points[1] and pos[1] <= storage.points[3]
		self.b_u = pos[2] == storage.points[4] and pos[1] >= storage.points[1] and pos[1] <= storage.points[3]
	end
	
	if fireMode == "primary"
		--and fireMode ~= self.fireModeLast
	then
		if not storage.points then storage.points = {pos[1],pos[2],pos[1],pos[2]} end
		
		if ((pos[1] < storage.points[1]
			or pos[2] < storage.points[2] 
			or pos[1] > storage.points[3]
			or pos[2] > storage.points[4])
			and not (self.b_l or self.b_r or self.b_d or self.b_u)
			and not self.selMove) or self.selMake -- not inside selection, not currently moving a border or the whole rect, or already making one
		then
			if not self.selPos then self.selPos = pos end
			if self.selPos[1] > pos[1] then
				storage.points[1] = pos[1]
				storage.points[3] = self.selPos[1]
			else
				storage.points[1] = self.selPos[1]
				storage.points[3] = pos[1]
			end
			
			if self.selPos[2] > pos[2] then
				storage.points[2] = pos[2]
				storage.points[4] = self.selPos[2]
			else
				storage.points[2] = self.selPos[2]
				storage.points[4] = pos[2]
			end
			self.selMake = true
		else
			if self.b_r and pos[1] >= storage.points[1] then --moving sides/edges
				storage.points[3] = pos[1]
			end
			if self.b_l and pos[1] <= storage.points[3] then
				storage.points[1] = pos[1]
			end
			if self.b_u and pos[2] >= storage.points[2] then
				storage.points[4] = pos[2]
			end
			if self.b_d and pos[2] <= storage.points[4] then
				storage.points[2] = pos[2]
			end
			if not (self.b_l or self.b_r or self.b_d or self.b_u) -- not on edges
				and ((pos[1] >= storage.points[1] and pos[1] <= storage.points[3] and pos[2] >= storage.points[2] and pos[2] <= storage.points[4]) or self.selMove) --within the rectangle or already moving it, duh
			then --moving the whole rectangle
				if not self.selPos then self.selPos = pos end
				self.selMove = true
				local x = pos[1] - self.selPos[1]
				local y = pos[2] - self.selPos[2]
				
				storage.points[1] = storage.points[1] + x
				storage.points[2] = storage.points[2] + y
				storage.points[3] = storage.points[3] + x
				storage.points[4] = storage.points[4] + y
			end
		end
		if self.selMove then
			self.selPos = pos
		end
		self.cursorDisplay = string.format("%s x %s",storage.points[3]-storage.points[1]+1,storage.points[4]-storage.points[2]+1)
	end
	
	if fireMode == "alt"
		and storage.points
		--and fireMode ~= self.fireModeLast
	then
		storage.points = false
	end
end


function BeamFire:paint_2_2(fireMode) --flipping
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
	
	if fireMode~= self.fireModeLast then
		self.cursorDisplay = "Flip "..(storage.flipX and "horizontal " or "")..(storage.flipY and "vertical" or "")
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
	self:frameworkUnInit()
end

