--!strict

export type QueueSnapshot = {
	PlayerUserIds: { number },
	PlayerCount: number,
	MaximumPlayers: number,
	CountdownEndsAt: number?,
}

export type ChapterSnapshot = {
	Act: number,
}

return table.freeze({})
