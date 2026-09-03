extends SceneTree

const SOURCE_DIRS := [
	"res://assets/ui/icons",
	"res://assets/ui/hud",
	"res://assets/ui/club_logos",
	"res://assets/ui/team_logos",
]
# Keep the sheet below the project's 1024 px import limit. If the importer
# resizes an atlas, its JSON pixel regions no longer point at the right icons.
# These assets are rendered at 44 px or smaller, so an 84 px inner image still
# gives comfortable Retina headroom while all 97 current glyphs fit in 960 px.
const SLOT := 96
const COLUMNS := 10
const OUTPUT_DIR := "res://assets/ui/atlas"

func _initialize() -> void:
	var files: Array[String] = []
	for folder in SOURCE_DIRS:
		collect_images(folder, files)
	files.sort()
	var rows := maxi(1, ceili(float(files.size()) / float(COLUMNS)))
	var atlas := Image.create_empty(COLUMNS * SLOT, rows * SLOT, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var mapping := {}
	for i in files.size():
		var image := Image.new()
		if image.load(ProjectSettings.globalize_path(files[i])) != OK:
			continue
		image.convert(Image.FORMAT_RGBA8)
		var scale := minf(float(SLOT - 12) / float(image.get_width()), float(SLOT - 12) / float(image.get_height()))
		var target := Vector2i(maxi(2, roundi(image.get_width() * scale)), maxi(2, roundi(image.get_height() * scale)))
		image.resize(target.x, target.y, Image.INTERPOLATE_LANCZOS)
		var cell := Vector2i((i % COLUMNS) * SLOT, (i / COLUMNS) * SLOT)
		var offset := cell + Vector2i((SLOT - target.x) / 2, (SLOT - target.y) / 2)
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, target), offset)
		mapping[files[i]] = [cell.x, cell.y, SLOT, SLOT]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	atlas.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/ui_icons_atlas.png"))
	var map_file := FileAccess.open(OUTPUT_DIR + "/ui_icons_atlas.json", FileAccess.WRITE)
	map_file.store_string(JSON.stringify(mapping))
	print("UI_ATLAS files=%d size=%dx%d" % [mapping.size(), atlas.get_width(), atlas.get_height()])
	quit()

func collect_images(folder: String, output: Array[String]) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	directory.list_dir_begin()
	var name := directory.get_next()
	while not name.is_empty():
		if not name.begins_with("."):
			var path := folder.path_join(name)
			if directory.current_is_dir():
				collect_images(path, output)
			elif name.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
				output.append(path)
		name = directory.get_next()
	directory.list_dir_end()
