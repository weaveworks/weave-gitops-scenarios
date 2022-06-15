#
# Test how flux & weave gitops cope with a silly number of kustomizations
#
# target structure:
# scenarios/
# └── many-kustomizations/
#     ├── kustomization.yaml          -- Flux kustomization that refs kustomization-[1...N].yaml
#     ├── namespace.yaml              -- Create everything in a single namespace for ease of destruction
#     ├── kustomizations/
#     │   ├── kustomization-1.yaml    -- Each flux kustomization refs the appropriate podinfo-X/ directory
#     │   ├── kustomization-2.yaml
#     │   │ ...
#     │   └── kustomization-N.yaml
#     ├── podinfo-kustomization-1/
#     │   └── release.yaml            -- Deploy podinfo
#     │ ...
#     └── podinfo-kustomization-N/
#         └── release.yaml            -- Deploy podinfo
#
from ..lib.generate import get_argparser, write_scenario
from ..lib.make_resource import (
    make_flux_kustomization,
    make_kustomization,
    make_namespace,
)


def podinfo_release(idx: int, namespace: str):
    name = f"podinfo-{idx}"
    port = 8000 + idx
    return {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {
            "name": name,
            "namespace": namespace,
        },
        "spec": {
            "replicas": 1,
            "selector": {
                "matchLabels": {
                    "app": name,
                },
            },
            "template": {
                "metadata": {
                    "labels": {
                        "app": name,
                    },
                },
                "spec": {
                    "containers": [
                        {
                            "name": name,
                            "image": "ghcr.io/stefanprodan/podinfo:6.1.6",
                            "imagePullPolicy": "IfNotPresent",
                            "ports": [
                                {
                                    "name": "http",
                                    "containerPort": port,
                                    "protocol": "TCP",
                                }
                            ],
                            "command": [
                                "./podinfo",
                                f"--port={port}",
                            ],
                        }
                    ]
                },
            },
        },
    }


def main(namespace_count: int) -> dict[list]:
    namespace = "many-podinfo-kustomizations"
    namespace_filename = "namespace.yaml"

    res = {namespace_filename: make_namespace(namespace)}

    resource_list = [namespace_filename]

    for idx in range(namespace_count):
        name = f"podinfo-kustomization-{idx}"
        kustomization_file = f"kustomizations/kustomization-{idx}.yaml"
        release_file = f"{name}/release.yaml"

        res[kustomization_file] = make_flux_kustomization(
            name, f"./many-podinfo-kustomizations/{name}"
        )
        res[release_file] = podinfo_release(idx, namespace)
        resource_list.append(kustomization_file)

    res["kustomization.yaml"] = make_kustomization(resource_list)

    return res


if __name__ == "__main__":
    import argparse

    parser = get_argparser(
        "many-podinfo-kustomizations", "Generate an arbitrary number of namespaces"
    )

    parser.add_argument(
        "-n",
        "--namespaces",
        default=6,
        metavar="N",
        type=int,
        help="how many namespaces to generate",
    )

    args = parser.parse_args()

    res = main(args.namespaces)
    write_scenario(res, args.dir, args.stdout)
