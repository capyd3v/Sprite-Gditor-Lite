@tool
extends VBoxContainer

var image: Image
var texture: ImageTexture
var is_drawing: bool = false
var current_button: int = -1 


var undo_stack: Array[PackedByteArray] = []
var redo_stack: Array[PackedByteArray] = []
const MAX_HISTORY = 30


var current_zoom: float = 1.0
const ZOOM_SPEED = 0.1
const MIN_ZOOM = 0.2
const MAX_ZOOM = 5.0

@onready var canvas: TextureRect = %Canvas
@onready var color_picker: ColorPickerButton = %ColorPickerButtons
@onready var spin_size: SpinBox = %SpinSize
@onready var spin_brush: SpinBox = %SpinBrush 

var save_dialog: FileDialog

func _ready():
	_setup_dialogs()
	
	
	%BtnUndo.pressed.connect(_undo)
	%BtnRedo.pressed.connect(_redo)
	%BtnSave.pressed.connect(func(): save_dialog.popup_centered())
	%BtnClear.pressed.connect(func(): setup_canvas(int(spin_size.value)))
	
	canvas.gui_input.connect(_on_canvas_gui_input)
	setup_canvas(int(spin_size.value))

func setup_canvas(size: int):
	image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.15, 0.17, 0.2, 1.0))
	undo_stack.clear()
	redo_stack.clear()
	undo_stack.push_back(image.get_data())
	_refresh_display()

func _on_canvas_gui_input(event: InputEvent):
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(current_zoom + ZOOM_SPEED)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(current_zoom - ZOOM_SPEED)
			return

		
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_drawing = true
				current_button = event.button_index
				draw_at_pos(event.position)
			else:
				if is_drawing:
					_save_state()
				is_drawing = false
				current_button = -1
				
	elif event is InputEventMouseMotion and is_drawing:
		draw_at_pos(event.position)

func _set_zoom(new_zoom: float):
	current_zoom = clamp(new_zoom, MIN_ZOOM, MAX_ZOOM)
	
	var base_size = 256.0
	canvas.custom_minimum_size = Vector2(base_size, base_size) * current_zoom
	
	canvas.update_minimum_size()

func draw_at_pos(gui_pos: Vector2):
	if not image: return
	var img_size = Vector2(image.get_size())
	var canvas_size = canvas.get_rect().size
	
	var scale_factor = min(canvas_size.x / img_size.x, canvas_size.y / img_size.y)
	var actual_size = img_size * scale_factor
	var offset = (canvas_size - actual_size) / 2.0
	
	var adj_pos = gui_pos - offset
	var center_x = int((adj_pos.x * img_size.x) / actual_size.x)
	var center_y = int((adj_pos.y * img_size.y) / actual_size.y)
	
	
	var draw_color = color_picker.color
	if current_button == MOUSE_BUTTON_RIGHT:
		draw_color = Color(0.15, 0.17, 0.2, 1.0) 

	
	var brush_offset = int(spin_brush.value)
	for dx in range(brush_offset):
		for dy in range(brush_offset):
			var px = center_x + dx
			var py = center_y + dy
			if px >= 0 and px < img_size.x and py >= 0 and py < img_size.y:
				image.set_pixel(px, py, draw_color)
	
	texture.update(image)



func _save_state():
	undo_stack.push_back(image.get_data())
	if undo_stack.size() > MAX_HISTORY: undo_stack.pop_front()
	redo_stack.clear()

func _undo():
	if undo_stack.size() > 1:
		redo_stack.push_back(undo_stack.pop_back())
		var data = undo_stack.back()
		image.set_data(image.get_width(), image.get_height(), false, image.get_format(), data)
		_refresh_display()

func _redo():
	if redo_stack.size() > 0:
		var data = redo_stack.pop_back()
		undo_stack.push_back(data)
		image.set_data(image.get_width(), image.get_height(), false, image.get_format(), data)
		_refresh_display()

func _refresh_display():
	texture = ImageTexture.create_from_image(image)
	canvas.texture = texture
	_set_zoom(current_zoom)

func _setup_dialogs():
	if not save_dialog:
		save_dialog = FileDialog.new()
		add_child(save_dialog)
		save_dialog.file_selected.connect(_on_file_selected)
		save_dialog.access = FileDialog.ACCESS_FILESYSTEM
		save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		save_dialog.add_filter("*.png", "PNG Images")

func _on_file_selected(path):
	image.save_png(path)
	EditorInterface.get_resource_filesystem().scan()

func _can_drop_data(_pos, data):
	return typeof(data) == TYPE_DICTIONARY and data.has("files")

func _drop_data(_pos, data):
	var path = data["files"][0]
	var new_img = null
	if path.begins_with("res://"):
		new_img = load(path).get_image()
	else:
		new_img = Image.load_from_file(path)
	
	if new_img:
		new_img.convert(Image.FORMAT_RGBA8)
		image = new_img
		_save_state()
		_refresh_display()
		spin_size.set_block_signals(true)
		spin_size.value = image.get_width()
		spin_size.set_block_signals(false)
