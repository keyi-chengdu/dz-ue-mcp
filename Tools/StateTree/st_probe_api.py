import unreal

unreal.log("[probe] has get_tree_parameters: {}".format(hasattr(unreal.DZStateTreeEditTools, "get_tree_parameters")))
unreal.log("[probe] has bind_task_inputs_from_tree_parameters: {}".format(hasattr(unreal.DZStateTreeEditTools, "bind_task_inputs_from_tree_parameters")))
unreal.log("[probe] has migrate_blueprint_task_off_try_get_tree_param: {}".format(hasattr(unreal.DZStateTreeEditTools, "migrate_blueprint_task_off_try_get_tree_param")))
unreal.log("[probe] has clean_stale_set_tree_param_out_bindings: {}".format(hasattr(unreal.DZStateTreeEditTools, "clean_stale_set_tree_param_out_bindings")))
unreal.log("[probe] dir: {}".format([m for m in dir(unreal.DZStateTreeEditTools) if not m.startswith("_")]))
