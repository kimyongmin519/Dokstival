--!strict

export type RemoteKind = "RemoteEvent" | "RemoteFunction"
export type RemoteDefinition = {
	Name: string,
	Kind: RemoteKind,
}

local definitions: { [string]: RemoteDefinition } = {
	QueueJoin = { Name = "QueueJoin", Kind = "RemoteEvent" },
	QueueLeave = { Name = "QueueLeave", Kind = "RemoteEvent" },
	QueueState = { Name = "QueueState", Kind = "RemoteEvent" },
	QueueError = { Name = "QueueError", Kind = "RemoteEvent" },
	GetQueueState = { Name = "GetQueueState", Kind = "RemoteFunction" },
	ChapterState = { Name = "ChapterState", Kind = "RemoteEvent" },
	GetChapterState = { Name = "GetChapterState", Kind = "RemoteFunction" },
}

return table.freeze({
	FolderName = "Remotes",
	Definitions = table.freeze(definitions),
})
