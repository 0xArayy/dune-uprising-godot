extends RefCounted
class_name GameConstants

const PHASE_ROUND_START := "round_start"
const PHASE_PLAYER_TURNS := "player_turns"
const PHASE_CONFLICT := "conflict"
const PHASE_MAKERS := "makers"
const PHASE_RECALL := "recall"

const STATUS_IN_PROGRESS := "in_progress"
const STATUS_FINISHED := "finished"

const DEFAULT_PLAYER_IDS: PackedStringArray = ["p1", "p2", "p3", "p4"]

const PENDING_SLOT_CONFLICT_COST := 9999
const PENDING_SLOT_CONFLICT_INFLUENCE := 10000
const PENDING_SLOT_CARD_EFFECT := 10001
const PENDING_SLOT_CONTRACT := 10002

const RESOURCE_SPICE := "spice"
const RESOURCE_SOLARI := "solari"
const RESOURCE_WATER := "water"
