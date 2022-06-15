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
#     ├── podinfo-1/
#     │   └── release.yaml            -- Deploy podinfo
#     │ ...
#     └── podinfo-1/
#         └── release.yaml            -- Deploy podinfo

import yaml
import pathlib


def make_kustomization(resource_filenames: list[str]) -> dict:
    return {
        "apiVersion": "kustomize.config.k8s.io/v1beta1",
        "kind": "Kustomization",
        "resources": resource_filenames,
    }


def generate_namespaces(namespace_count: int) -> list[dict]:
    res = []
    for i in range(namespace_count):
        res.append(make_namespace(i))

    return res


# FIXME make this write to proper files
def main(namespace_count: int, output_directory: pathlib.Path):
    resource_filename = "many-namespaces.yaml"
    kustomization = make_kustomization([resource_filename])
    namespaces = generate_namespaces(namespace_count)

    with open(f"{output_directory}/kustomization.yaml", "w") as kustomization_file:
        with open(f"{output_directory}/{resource_filename}", "w") as resource_file:
            yaml.dump(kustomization, kustomization_file)
            yaml.dump_all(namespaces, resource_file)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate some namespaces and associated podinfo instances"
    )

    parser.add_argument(
        "-n",
        "--namespaces",
        default=6,
        metavar="N",
        type=int,
        help="how many namespaces to generate",
    )

    parser.add_argument(
        "-d",
        "--dir",
        default="/scenarios/many-namespaces",
        type=pathlib.Path,
        help="Output directory",
    )

    args = parser.parse_args()

    main(args.namespaces, args.dir)
