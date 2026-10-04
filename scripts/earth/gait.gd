extends RefCounted
## Distance, not wall time, advances a planted-foot cycle. Values measured in 432×248 runtime canvas.
const CYCLE_PIXELS={"male-heavy":312.0,"pale-hair-katana":315.0,"bull-spider":112.0}

static func frame(distance: float,cycle_pixels: float,count: int) -> int:
	if count<=0 or cycle_pixels<=0: return 0
	return int(fposmod(distance,cycle_pixels)/cycle_pixels*count)%count

static func legacy_cycle(kind: String,height: float) -> float:
	return CYCLE_PIXELS.get(kind,300.0)*height/224.0
