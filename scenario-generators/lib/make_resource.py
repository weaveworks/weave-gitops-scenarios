def make_namespace(
    scenario_name: str, namespace_root: str = None, namespace_id: str = None
):
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


def make_kustomization(resource_filenames: list[str]) -> dict:
    return {
        "apiVersion": "kustomize.config.k8s.io/v1beta1",
        "kind": "Kustomization",
        "resources": resource_filenames,
    }


def make_flux_kustomization(name: str, path: str):
    return {
        "apiVersion": "kustomize.toolkit.fluxcd.io/v1beta1",
        "kind": "Kustomization",
        "metadata": {
            "name": name,
            "namespace": "flux-system",
        },
        "spec": {
            "interval": "30s",
            "sourceRef": {
                "kind": "Bucket",
                "name": "scenarios",
            },
            "path": path,
            "prune": True,
            "validation": "client",
        },
    }
