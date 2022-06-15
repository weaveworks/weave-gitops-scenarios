from ..lib.generate import get_argparser, write_scenario
from ..lib.make_resource import make_namespace, make_kustomization


def generate_namespaces(namespace_count: int) -> list[dict]:
    res = []
    for idx in range(namespace_count):
        res.append(make_namespace("many-namespaces", "test-namespace", idx))

    return res


def main(namespace_count: int) -> dict[list]:
    resource_filename = "many-namespaces.yaml"
    return {
        "kustomization.yaml": make_kustomization([resource_filename]),
        resource_filename: generate_namespaces(namespace_count),
    }


if __name__ == "__main__":
    import argparse

    parser = get_argparser(
        "many-namespaces", "Generate an arbitrary number of namespaces"
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
