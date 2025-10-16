class_name AnimLayer extends Resource

var enabled: bool = true
var current: int = 0
var frame: int = 0
var frames = []

func assemble():
	var buf = PackedByteArray()
	buf.resize(4)
	buf.encode_u32(0,6)
	for i in range(frames.size()):
		var frameBuf = PackedByteArray()
		var p = 0
		var layerCnt = frames[i].active_layers.size() + frames[i].inactive_layers.size()
		if frames[i].dur_min == frames[i].dur_max:
			frameBuf.resize(4+(layerCnt*4))
			frameBuf.encode_u16(0,7)
			frameBuf.encode_u16(2,frames[i].duration)
			p = 4
		else:
			frameBuf.resize(6+(layerCnt*4))
			frameBuf.encode_u16(0,14)
			frameBuf.encode_u16(2,frames[i].dur_min)
			frameBuf.encode_u16(4,frames[i].dur_max)
			p = 6
		
		for j in range(frames[i].active_layers.size()):
			frameBuf.encode_u16(p,9)
			frameBuf.encode_u16(p+2,frames[i].active_layers[j])
			p += 4
		for j in range(frames[i].inactive_layers.size()):
			frameBuf.encode_u16(p,8)
			frameBuf.encode_u16(p+2,frames[i].inactive_layers[j])
			p += 4
		buf.append_array(frameBuf)
	return buf
