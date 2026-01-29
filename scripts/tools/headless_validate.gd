extends SceneTree

func _initialize() -> void:
    var main_scene: String
    main_scene = ProjectSettings.get_setting("application/run/main_scene")
    if main_scene == "":
        push_error("No main scene configured in ProjectSettings.")
        quit(1)
        return

    var packed: PackedScene
    packed = load(main_scene)
    if packed == null:
        push_error("Failed to load main scene: " + str(main_scene))
        quit(1)
        return

    var instance: Node = packed.instantiate()
    root.add_child(instance)
    call_deferred("_finish_validation")

func _finish_validation() -> void:
    await process_frame
    quit(0)
