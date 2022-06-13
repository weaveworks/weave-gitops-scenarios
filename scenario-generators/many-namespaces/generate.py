import yaml
import pathlib


def make_namespace(namespace_id, namespace_root="test-namespace"):
    return {
        "apiVersion": "v1",
        "kind": "Namespace",
        "metadata": {
            "name": f"{namespace_root}-{namespace_id}",
            "annotations": {
                "generated-by": "gitops-scenarios/scenarios/many-namespaces",
                "params": f"make_namespace(f{namespace_id}, f{namespace_root})",
            },
        },
    }


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
