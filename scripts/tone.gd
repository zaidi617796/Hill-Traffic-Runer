extends RefCounted
## Chhoti si procedural tone generator — koi audio file nahi chahiye.
## Sine wave + fade-out envelope, AudioStreamWAV me pack karke play karta hai.

static func _make_stream(freq: float, seconds: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var frames := int(seconds * sample_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / sample_rate
		var env := 1.0 - float(i) / float(frames)
		env *= env
		var s := sin(TAU * freq * t) * volume * env
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav

static func play(parent: Node, freq: float, seconds: float = 0.18, volume: float = 0.4) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _make_stream(freq, seconds, volume)
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
