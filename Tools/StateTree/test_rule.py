import unreal
import sys

print("Has DZStateTreeInputBindingRule:", hasattr(unreal, 'DZStateTreeInputBindingRule'))
rule = unreal.DZStateTreeInputBindingRule()
print("type:", type(rule))
print("dir:", [a for a in dir(rule) if not a.startswith('_')])
print("node_type attr:", getattr(rule, 'node_type', 'MISSING'))
print("NodeType attr:", getattr(rule, 'NodeType', 'MISSING'))
