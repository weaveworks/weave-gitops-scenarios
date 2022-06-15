def namespace(scenario_name, namespace_root=None, namespace_id=None):
    namespace_root = f"{scenario_name}" if namespace_root is None else namespace_root
    namespace = (
        f"{namespace_root}"
        if namespace_id is None
        else f"{namespace_root}-{namespace_id}"
    )

    return {
        "apiVersion": "v1",
        "kind": "Namespace",
        "metadata": {
            "name": namespace.replace("_", "-"),
            "annotations": {
                "scenario": scenario_name,
                "namespace_root": namespace_root,
                "namespace_id": "--" if namespace_id is None else namespace_id,
            },
        },
    }
