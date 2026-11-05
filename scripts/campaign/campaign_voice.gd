class_name CampaignVoice
extends RefCounted
## Recorded VOICE LINES for the campaign's dialogue (campaign-m1): one file per line,
##   res://campaign/voice/<the mission's "voice" folder, else its id>/<line id>.ogg
## (e.g. campaign/voice/p01/k_pipe.ogg). Played when the file is there, silent when not, so the owner's recordings
## (ElevenLabs) drop in without touching the mission. The list of lines to record: docs/campaign_mission1_voice.md.
## (.wav and .mp3 are taken too, in that order after .ogg.)

const DIR := "res://campaign/voice"
const EXTS := ["ogg", "wav", "mp3"]


static func path_of(m: Dictionary, lid: String) -> String:
	var folder := String(m.get("voice", m.get("id", "")))
	for ext in EXTS:
		var p := "%s/%s/%s.%s" % [DIR, folder, lid, ext]
		if ResourceLoader.exists(p):
			return p
	return ""


## Plays the line's recording on a player under `owner` (the one before it stops). Returns its length in seconds
## (0: no recording).
static func play(owner: Node, m: Dictionary, lid: String) -> float:
	stop(owner)
	var p := path_of(m, lid)
	if p == "" or owner == null:
		return 0.0
	var st: AudioStream = load(p)
	if st == null:
		return 0.0
	var pl := AudioStreamPlayer.new()
	pl.name = "CampaignVoice"
	pl.stream = st
	pl.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	pl.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.add_child(pl)
	pl.play()
	pl.finished.connect(pl.queue_free)
	return st.get_length()


static func stop(owner: Node) -> void:
	if owner == null:
		return
	var old := owner.get_node_or_null("CampaignVoice")
	if old:
		old.name = "CampaignVoiceOld"
		old.queue_free()
