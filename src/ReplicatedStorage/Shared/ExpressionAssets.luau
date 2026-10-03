-- Approved three-state faces. Each rig owns its UV-compatible head textures; missing assets keep the source face.
return {
	Costumes = {
		Costume_HaloArcherM = {
			Neutral = "rbxassetid://114282379234661",
			Serious = "rbxassetid://130810730029380",
			SoftSmile = "rbxassetid://96983789676579",
			MeshName = "FaceExpression",
			SkinSchema = 1,
			SkinSourceSHA256 = "17972af93f7ecd176f96af8db81fdff00c04e055a1d340b9dd9f288196d54584",
			MeshId = "rbxassetid://120232648183385",
		},
		Costume_HaloWarriorM = {
			Neutral = "rbxassetid://121674541725480",
			Serious = "rbxassetid://104677901335263",
			SoftSmile = "rbxassetid://133057889021878",
			MeshName = "FaceExpression",
		},
	},
	Monsters = {}, -- MonsterKind = the same three texture keys, with an optional MeshName for the face material.
}
