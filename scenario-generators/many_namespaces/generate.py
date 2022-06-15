import yaml
import pathlib

from ..lib.generate import get_argparser, write_scenario
from ..lib.make_resource import namespace


def make_kustomization(resource_filenames: list[str]) -> dict:
    return {
        "apiVersion": "kustomize.config.k8s.io/v1beta1",
        "kind": "Kustomization",
        "resources": resource_filenames,
    }


def generate_namespaces(namespace_count: int) -> list[dict]:
    res = []
    for i in range(namespace_count):
        res.append(namespace("many-namespaces", i, "test-namespace"))

    return res


def main(namespace_count: int) -> dict[list]:
    resource_filename = "many-namespaces.yaml"
    return {
        "kustomization.yaml": [make_kustomization([resource_filename])],
        resource_filename: generate_namespaces(namespace_count),
    }


if __name__ == "__main__":
    import argparse

    parser = get_argparser("Generate an arbitrary number of namespaces")

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
