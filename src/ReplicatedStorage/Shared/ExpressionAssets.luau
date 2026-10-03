-- Approved three-state faces. Each rig owns its UV-compatible head textures; missing assets keep the source face.
return {
	Costumes = {
		Costume_HaloArcherM = {
			Neutral = "rbxassetid://114282379234661",
			Serious = "rbxassetid://130810730029380",
			SoftSmile = "rbxassetid://96983789676579",
			MeshName = "FaceExpression",
			SkinSchema = 1,
			SkinSourceSHA256 = "f23871e89b092cb69eb0547c2c77180ff4150ffbb8593eb47a220ac87aff060a",
			MeshId = "rbxassetid://88405558388221",
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
