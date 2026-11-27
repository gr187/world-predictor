extends RefCounted
## 장면을 다시 불러와도 유지되어야 하는 상태. (죽어도 단서는 유지된다는 설계 때문)
## 저장 파일로 내보내는 기능은 아직 없다.

const ClueBook := preload("res://scripts/clue_book.gd")

static var _book: RefCounted = null


static func get_book() -> RefCounted:
	if _book == null:
		_book = ClueBook.new()
	return _book


static func reset() -> void:
	_book = null
