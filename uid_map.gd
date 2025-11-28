extends Node

func _ready():
    var uid_map = {}
    var dir = DirAccess.open("res://")
    if dir == null:
        push_error("Cannot open project root")
        get_tree().quit()
        return
    _scan_dir(dir, "res://")
    var json = JSON.print(uid_map)
    var out = FileAccess.open("res://uid_map.json", FileAccess.WRITE)
    out.store_string(json)
    out.close()
    print("UID map generated with %d entries." % uid_map.size())
    get_tree().quit()

func _scan_dir(dir: DirAccess, base_path: String) -> void:
    dir.list_dir_begin(true, true)
    while true:
        var entry = dir.get_next()
        if entry == "":
            break
        var full_path = base_path + entry
        if dir.current_is_dir():
            var sub_dir = DirAccess.open(full_path)
            if sub_dir:
                _scan_dir(sub_dir, full_path + "/")
        else:
            if entry.get_extension().to_lower() == "uid":
                var resource_path = full_path.substr(0, full_path.length() - 4) # strip .uid
                var uid_file = FileAccess.open(full_path, FileAccess.READ)
                if uid_file:
                    var uid = uid_file.get_as_text().strip()
                    uid_file.close()
                    uid_map[resource_path] = uid
    dir.list_dir_end()
}
