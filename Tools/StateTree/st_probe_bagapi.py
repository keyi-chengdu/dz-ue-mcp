# -*- coding: utf-8 -*-
import unreal
st = unreal.EditorAssetLibrary.load_asset("/Game/Blueprint/StateTree/05002101/ST_05002101")
cands = [m for m in dir(st) if "editor" in m.lower() or "data" in m.lower()]
unreal.log("ST editor/data attrs: {}".format(cands))
for name in ("EditorData", "editor_data", "EdData"):
    try:
        ed = st.get_editor_property(name)
        unreal.log("OK name={} type={}".format(name, type(ed)))
        params = ed.get_editor_property("parameters")
        unreal.log("PARAMS TYPE: {}".format(type(params)))
        unreal.log("PARAMS methods: {}".format(
            [m for m in dir(params) if "add" in m.lower() or "propert" in m.lower()]))
        unreal.log("props: {}".format(params.get_properties_names()))
        break
    except Exception as e:
        unreal.log_warning("name={} failed: {}".format(name, e))
