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
	storage.sizeIndex = storage.sizeIndex or 1
	
	--rectangle select (bottom left x, bottom left y, top right x, top right y)
	local aimpos = activeItem.ownerAimPosition()
	storage.points = storage.points or false--{math.floor(aimpos[1]),math.floor(aimpos[2]),math.floor(aimpos[1]),math.floor(aimpos[2])}
	
	storage.maskData = storage.maskData or false
	
	self.modeMax = {5,6} -- normal, mask
	storage.mode = storage.mode or 1
	storage.altMode = storage.altMode or 1
	storage.modeMask = storage.modeMask or 1
	self.funcName = "paint"
	
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
	
	self.chain.segmentImage = self.bSegment.."?setcolor="..self.colours[storage.colourIndex]
		
	local beamStart = self:firePosition()
	local beamEnd = activeItem.ownerAimPosition()
	
	beamEnd[1] = math.floor(beamEnd[1])
	beamEnd[2] = math.floor(beamEnd[2])
	
	self:render(beamEnd)
	
	--world.sendEntityMessage(activeItem.ownerEntityId(),"setBar","randombar",0,{255,255,255,255})
	--world.sendEntityMessage(activeItem.ownerEntityId(),"setBar","PaintToolBar2",self.holdTimer/self.holdDelay, self.shiftHoldSupressed and {255,0,160,255} or (self.shiftHoldComplete and {255,255,160,255} or {0,255,160,255}))
		
	self:frameworkUpdate(dt,fireMode,shiftHeld)

end

function BeamFire:render_regular()
	self:renderMask()
end

function BeamFire:shift_hold()
	storage.points = false
	storage.maskData = false	
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
	
	
	local s_rect = {} --rectangle for highlighting selection modification
	
	--has to change if the coursor is over one of the edges or corners	
	if storage.points then
		if self.b_r and self.b_u then
			s_rect = {storage.points[3]-1,storage.points[4]-1,storage.points[3],storage.points[4]}
		elseif self.b_r and self.b_d then
			s_rect = {storage.points[3]-1,storage.points[2],storage.points[3],storage.points[2]+1}
		elseif self.b_l and self.b_u then
			s_rect = {storage.points[1],storage.points[4]-1,storage.points[1]+1,storage.points[4]}
		elseif self.b_l and self.b_d then
			s_rect = {storage.points[1],storage.points[2],storage.points[1]+1,storage.points[2]+1}
		elseif self.b_r then
			s_rect = {storage.points[3]-1,storage.points[2],storage.points[3],storage.points[4]}
		elseif self.b_l then
			s_rect = {storage.points[1],storage.points[2],storage.points[1]+1,storage.points[4]}
		elseif self.b_u then
			s_rect = {storage.points[1],storage.points[4]-1,storage.points[3],storage.points[4]}
		elseif self.b_d then
			s_rect = {storage.points[1],storage.points[2],storage.points[3],storage.points[2]+1}
		end
	end
	
	if #s_rect>0 then
		self:renderBox(s_rect,chains,"?setcolor=FFFF00")
	end
	
	if storage.points then
		self:renderBox(storage.points,chains,"?setcolor=ffa000;")
	end

	activeItem.setScriptedAnimationParameter("chains", chains)
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
	
	--[[
		Optimised particle renderer.
		Turns columns of particles into one stretched particle to improve fps by limiting their number.
		Very effective with the one-colour masks
		> Iterate over the mask table and build a max and min to be able to decisively see when the next value is not a true
		> Iterate using the min and max. Take first true values' y position, iterate until the next value is not true.
		> Push a particle with an average y of start and end, stretch vertically to fill the entire gap
	]]
	
	local iMin,iMax,jMin,jMax = 10000,0,10000,0 --magic numbers. Let's hope there's never a max value over 10000
	
	for i,temp_table in pairs(storage.maskData) do
		local iT = tonumber(i)
		if iT > iMax then iMax = iT end
		if iT < iMin then iMin = iT end
		for j,v in pairs(temp_table) do
			local jT = tonumber(j)
			if jT > jMax then jMax = jT end
			if jT < jMin then jMin = jT end
		end
	end
	
	local jStart = 0
	local jReset = true
	local multiplier = 1
	
	for i = iMin,iMax do
		jReset = true
		for j = jMin,jMax do
			local iS = tostring(i)
			if storage.maskData[iS] then
				local jS = tostring(j)
				if jReset then --getting new line position after pushing render
					jStart = j
					multiplier = 1
					jReset = false
				end 
				if storage.maskData[iS][jS] then
					if storage.maskData[iS][tostring(j+1)] then
						multiplier = multiplier + 1
					else
						DRAW = true
						jReset = true
						local lParticle = copy(particle)
						lParticle.specification.image = lParticle.specification.image.."?scale=1;"..multiplier..";"
						lParticle.specification.position = {i - storage.points[1] + 0.5,(j+jStart)/2-storage.points[2] + 0.5}
						table.insert(pixel.actionOnReap,lParticle)					
					end
				else
					jReset = true
				end
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
	pos[1] = math.floor(pos[1])
	pos[2] = math.floor(pos[2])
	
	if fireMode ~= self.fireModeLast then
		self.selPos = false
		self.selMove = false
		self.selMake = false
		self.cursorDisplay = false
	end
	
	if fireMode ~= "alt" and fireMode ~= "primary" and storage.points then
		self.b_l = pos[1] == storage.points[1] and pos[2] >= storage.points[2] and pos[2] < storage.points[4]
		self.b_r = pos[1] == storage.points[3] - 1 and pos[2] >= storage.points[2] and pos[2] < storage.points[4]
		self.b_d = pos[2] == storage.points[2] and pos[1] >= storage.points[1] and pos[1] < storage.points[3]
		self.b_u = pos[2] == storage.points[4] - 1 and pos[1] >= storage.points[1] and pos[1] < storage.points[3]
	end
	
	if fireMode == "primary"
		--and fireMode ~= self.fireModeLast
	then
		if not storage.points then storage.points = {pos[1],pos[2],pos[1],pos[2]} end
		
		if ((pos[1] < storage.points[1]
			or pos[2] < storage.points[2] 
			or pos[1] > storage.points[3] - 1
			or pos[2] > storage.points[4] - 1)
			and not (self.b_l or self.b_r or self.b_d or self.b_u)
			and not self.selMove) or self.selMake -- not inside selection, not currently moving a border or the whole rect, or already making one
		then
			if not self.selPos then self.selPos = pos end
			if self.selPos[1] > pos[1] then
				storage.points[1] = pos[1]
				storage.points[3] = self.selPos[1]+1
			else
				storage.points[1] = self.selPos[1]
				storage.points[3] = pos[1]+1
			end
			
			if self.selPos[2] > pos[2] then
				storage.points[2] = pos[2]
				storage.points[4] = self.selPos[2]+1
			else
				storage.points[2] = self.selPos[2]
				storage.points[4] = pos[2]+1
			end
			self.selMake = true
		else
			if self.b_r and pos[1] >= storage.points[1] then --moving sides/edges
				storage.points[3] = pos[1]+1
			end
			if self.b_l and pos[1] < storage.points[3] then
				storage.points[1] = pos[1]
			end
			if self.b_u and pos[2] >= storage.points[2] then
				storage.points[4] = pos[2]+1
			end
			if self.b_d and pos[2] < storage.points[4] then
				storage.points[2] = pos[2]
			end
			if not (self.b_l or self.b_r or self.b_d or self.b_u) -- not on edges
				and ((pos[1] >= storage.points[1] and pos[1] < storage.points[3] and pos[2] >= storage.points[2] and pos[2] < storage.points[4]) or self.selMove) --within the rectangle or already moving it, duh
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
		self.cursorDisplay = string.format("%s x %s",storage.points[3]-storage.points[1],storage.points[4]-storage.points[2])
	end
	
	if fireMode == "alt"
		and storage.points
		--and fireMode ~= self.fireModeLast
	then
		storage.points = false
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
			if not storage.maskData[si] then storage.maskData[si] = {} end
			for j = aim[2]+self.sizes[storage.sizeIndex][1],aim[2]+self.sizes[storage.sizeIndex][2] do
				if self:inSelection({i,j}) then
					local sj = tostring(j)
					storage.maskData[si][sj] = value
				end
			end
			if storage.maskData[si] and next(storage.maskData[si]) == nil then storage.maskData[si] = nil end
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
						if storage.maskData[si] and next(storage.maskData[si]) == nil then storage.maskData[si] = nil end
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
						if storage.maskData[si] and next(storage.maskData[si]) == nil then storage.maskData[si] = nil end
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
			if storage.maskData[si] and next(storage.maskData[si]) == nil then storage.maskData[si] = nil end
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
	self:frameworkUnInit()
	--sb.logInfo(sb.printJson(storage.maskData))
	--world.sendEntityMessage(activeItem.ownerEntityId(),"removeBar","randombar")
end
