local Jecs = require(script.Parent.Parent.jecs)

export type Position = Vector3

export type Momentum = {
	momentumDecelerationOvertime: Vector3,
	velocity: Vector3,
	rotationalVelocity: Vector3 -- new thing
}

export type Gravity = number

export type Elasticity = {
	momentumDecelerationBounce: Vector3,
	scale: number
}

export type Appearance = Instance

export type BoxCollider = {
	size: Vector3
}

export type SphereCollider = { -- new thing
	radius: number
}

export type Filter = RaycastParams

return nil
