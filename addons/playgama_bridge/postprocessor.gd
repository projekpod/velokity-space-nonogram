extends EditorExportPlugin

const INDEX_FILE_NAME = "index.html"
const TMP_JS_EXPORT_INDEX_FILE_NAME = "tmp_js_export.html"
const JS_SDK_FILE_NAME = "playgama-bridge.js"
const JS_SDK_CONFIG_FILE_NAME = "playgama-bridge-config.json"
const JS_SDK_PATH = "res://addons/playgama_bridge/template/"


var _path = null

func _get_name() -> String:
	return "Bridge"

func _export_begin(features, is_debug, path, flags):
	if features.has("web"):
		_path = path
		
		_copy_file(JS_SDK_FILE_NAME)
		_copy_file(JS_SDK_CONFIG_FILE_NAME)
		_copy_file("../LICENSE", "playgama-bridge-LICENSE.txt")

func _copy_file(file_name, export_name = ""):
	var file_from = FileAccess.open(JS_SDK_PATH + file_name, FileAccess.READ)
	if file_from == null:
		push_error("Bridge: failed to read " + JS_SDK_PATH + file_name)
		return
	
	var output_name = file_name if export_name.is_empty() else export_name
	var file_to = FileAccess.open(_path.get_base_dir().path_join(output_name), FileAccess.WRITE)
	if file_to == null:
		push_error("Bridge: failed to write " + file_name)
		return
	
	file_to.store_string(file_from.get_as_text())
	
	file_from = null
	file_to = null
