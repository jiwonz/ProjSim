--!strict

local Jecs = require(script.Parent.jecs)
local components = require(script.components)
local Components = require(script.components)
local ProjSim = {} :: ProjSimImpl
ProjSim.__index = ProjSim

type Entity<T=any> = Jecs.Entity<T>

export type ProjSim = typeof(setmetatable(
	{} :: {
		world: Jecs.WorldShim,
		Component: {
			Position: Entity<Components.Position>,
			Momentum: Entity<Components.Momentum>,
			Gravity: Entity<Components.Gravity>,
			Elasticity: Entity<Components.Elasticity>,
			Appearance: Entity<Components.Appearance>,
			BoxCollider: Entity<Components.BoxCollider>,
			SphereCollider: Entity<Components.SphereCollider>,
			Filter: Entity<Components.Filter>,
		}
	},
	{} :: ProjSimImpl
))

type ProjSimImpl = {
	__index: ProjSimImpl,
	new: (world: Jecs.WorldShim?) -> (ProjSim),
	spawn: (self: ProjSim, components: {
		Position: Components.Position?,
		Momentum: Components.Momentum?,
		Gravity: Components.Gravity?,
		Elasticity: Components.Elasticity?,
		Appearance: Components.Appearance?,
		BoxCollider: Components.BoxCollider?,
		SphereCollider: Components.SphereCollider?,
		Filter: Components.Filter?,
	}) -> (Entity),
	getCollisionSize: (self: ProjSim, entity: Entity) -> (Vector3?),
	getMomentum: (self: ProjSim, entity: Entity) -> (Components.Momentum),
	getAppearance: (self: ProjSim, entity: Entity) -> (Components.Appearance?),
	getFilter: (self: ProjSim, entity: Entity) -> (Components.Filter?),
	getGravity: (self: ProjSim, entity: Entity) -> (Components.Gravity?),
	getElasticity: (self: ProjSim, entity: Entity) -> (Components.Elasticity?),
	update: (self: ProjSim, deltaTime: number) -> ()
}

local function getNextRayFaceDirection(momentum: Components.Momentum)
	local direction = Vector3.zero

	if momentum.velocity.X > 0 then
		direction += Vector3.new(1, 0, 0)
	elseif momentum.velocity.X < 0 then
		direction -= Vector3.new(1, 0, 0)
	end

	if momentum.velocity.Y > 0 then
		direction += Vector3.new(0, 1, 0)
	elseif momentum.velocity.Y < 0 then
		direction -= Vector3.new(0, 1, 0)
	end

	if momentum.velocity.Z > 0 then
		direction += Vector3.new(0, 0, 1)
	elseif momentum.velocity.Z < 0 then
		direction -= Vector3.new(0, 0, 1)
	end

	return direction
end

local function decelerate(momentum: components.Momentum, multiplier: number, decelerationValue: Vector3)
	local deceleration = decelerationValue * multiplier

	if momentum.velocity.X < 0 then
		deceleration = Vector3.new(-deceleration.X, deceleration.Y, deceleration.Z)
	end

	if momentum.velocity.Y < 0 then
		deceleration = Vector3.new(deceleration.X, -deceleration.Y, deceleration.Z)
	end

	if momentum.velocity.Z < 0 then
		deceleration = Vector3.new(deceleration.X, deceleration.Y, -deceleration.Z)
	end

	local newVelocity = momentum.velocity - deceleration

	if momentum.velocity.X ~= 0 then
		if momentum.velocity.X > 0 then
			if newVelocity.X < 0 then
				newVelocity = Vector3.new(0, newVelocity.Y, newVelocity.Z)
			end
		else
			if newVelocity.X > 0 then
				newVelocity = Vector3.new(0, newVelocity.Y, newVelocity.Z)
			end
		end
	else
		newVelocity = Vector3.new(0, newVelocity.Y, newVelocity.Z)
	end

	if momentum.velocity.Y ~= 0 then
		if momentum.velocity.Y > 0 then
			if newVelocity.Y < 0 then
				newVelocity = Vector3.new(newVelocity.X, 0, newVelocity.Z) -- edit: add newVelocity assignment
			end
		else
			if newVelocity.Y > 0 then
				newVelocity = Vector3.new(newVelocity.X, 0, newVelocity.Z) -- edit: add newVelocity assignment
			end
		end
	else
		newVelocity = Vector3.new(newVelocity.X, 0, newVelocity.Z)
	end

	if momentum.velocity.Z ~= 0 then
		if momentum.velocity.Z > 0 then
			if newVelocity.Z < 0 then
				newVelocity = Vector3.new(newVelocity.X, newVelocity.Y, 0)
			end
		else
			if newVelocity.Z > 0 then
				newVelocity = Vector3.new(newVelocity.X, newVelocity.Y, 0)
			end
		end
	else
		newVelocity = Vector3.new(newVelocity.X, newVelocity.Y, 0)
	end

	-- prevents a funky behavior where bounce object would moves ever so slightly up and down when its velocity should be at 0
	if newVelocity.Y > -2 and newVelocity.Y < -0.2 then
		newVelocity = Vector3.new(newVelocity.X, 0, newVelocity.Z)
	end

	if newVelocity.Y > 0 and newVelocity.Y < 0.1 then
		newVelocity = Vector3.new(newVelocity.X, 0, newVelocity.Z)
	end

	momentum.velocity = newVelocity
end

function ProjSim.new(world)
	world = world or Jecs.World.new()
	if not world then
		error("Could not create a world")
	end
	return setmetatable({
		world = world,
		Component = {
			Position = world:component(),
			Momentum = world:component(),
			Gravity = world:component(),
			Elasticity = world:component(),
			Appearance = world:component(),
			BoxCollider = world:component(),
			SphereCollider = world:component(),
			Filter = world:component()
		}
	}, ProjSim)
end

function ProjSim.spawn(self, components)
	local entity = self.world:entity()
	for componentName, value in components do
		self.world:set(entity, self.Component[componentName], value)
	end
	return entity
end

function ProjSim.getCollisionSize(self, entity)
	local boxCollider = self.world:get(entity, self.Component.BoxCollider)
	if boxCollider then
		return boxCollider.size
	end
	return
end

function ProjSim.getMomentum(self, entity)
	local momentum = self.world:get(entity, self.Component.Momentum)
	if momentum then
		return momentum
	else
		local newMomentum = {
			velocity = Vector3.new(),
			["momentumDecelerationOvertime"] = Vector3.new(),
			["rotationalVelocity"] = Vector3.new()
		}
		self.world:set(entity, self.Component.Momentum, newMomentum)
		return newMomentum
	end
end

function ProjSim.getAppearance(self, entity)
	return self.world:get(entity, self.Component.Appearance)
end

function ProjSim.getFilter(self, entity)
	local filter = self.world:get(entity, self.Component.Filter)
	if filter then
		return filter
	else
		local appearance = self:getAppearance(entity)
		if appearance then
			local newFilter = RaycastParams.new()
			newFilter:AddToFilter(appearance)
			return newFilter
		end
		return
	end
end

function ProjSim.getGravity(self, entity)
	return self.world:get(entity, self.Component.Gravity)
end

function ProjSim.getElasticity(self, entity)
	return self.world:get(entity, self.Component.Elasticity)
end

function ProjSim.update(self, deltaTime)
	for entity: Entity<any>, position: Components.Position in self.world:query(self.Component.Position) do
		local momentum = self:getMomentum(entity)
		local nextRayFaceDirection = getNextRayFaceDirection(momentum)
		local collisionSize = self:getCollisionSize(entity)
		if collisionSize then
			collisionSize /= 2
		end
		local nextPosition = position + momentum.velocity * deltaTime
		local direction = nextPosition - position + (nextRayFaceDirection * (collisionSize or 1))
		local result = workspace:Raycast(position, direction, self:getFilter(entity))

		local gravity = self:getGravity(entity)

		if result and momentum.velocity ~= Vector3.zero then
			if not (result.Instance :: BasePart).CanCollide then
				continue
			end
			local surfacenormal = result.Normal
			local elasticity = self:getElasticity(entity)
			local reflect = Vector3.zero
			if elasticity then
				reflect = elasticity.scale * (momentum.velocity - (2 * momentum.velocity:Dot(surfacenormal) * surfacenormal))
			end
			if gravity then
				momentum.velocity = reflect - Vector3.new(0, gravity, 0)
			else
				momentum.velocity = reflect
			end
			if elasticity then
				decelerate(momentum, deltaTime, elasticity.momentumDecelerationBounce)
			end
		else
			position = nextPosition
			self.world:set(entity, self.Component.Position, position)
			if gravity and momentum.velocity ~= Vector3.zero then
				momentum.velocity -= Vector3.new(0, gravity, 0)
			end
		end
	end
end

return ProjSim
