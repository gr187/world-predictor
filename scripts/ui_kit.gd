extends RefCounted
## 화면(UI)을 코드로 만들 때 쓰는 작은 도구와 공통 문구.

const CONTROLS_TEXT := "이동   A / D\n점프   Space\n사다리   W / S\n조사·조작   E  (노란 표시, 레버, 승강기, 귀환 장치)\n단서 수첩   Q\n일시정지   Esc\n전투   숫자 1·2·3 또는 클릭  (5초 안에 고르기)\n\n목표: 멸망한 세계를 돌아다니며 단서를 모으고, 하늘색 귀환 장치에서 상사에게 보고하세요."

const INTRO_PAGES := [
	"당신은 세계의 멸망을 막는 회사의 사원이다.",
	"어느 날 상사가 말했다.\n\"세계 예측기라는 기계가 있네. 세계가 언제, 어떻게 멸망할지를 시뮬레이션으로 보여 주지.\"",
	"\"자네가 그 안으로 들어가, 이미 멸망한 세계를 직접 조사해 오게. 무엇이, 왜 세계를 무너뜨렸는지 말이야.\"",
]


static func label(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size: int = 11,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align as HorizontalAlignment
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, pos: Vector2, sz: Vector2, font_size: int, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


static func dim(parent: Node, color: Color) -> ColorRect:
	var d := ColorRect.new()
	d.color = color
	d.size = Vector2(480, 270)
	parent.add_child(d)
	return d
