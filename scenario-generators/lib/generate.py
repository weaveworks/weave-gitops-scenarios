import yaml
import argparse
from pathlib import Path


def write_scenario(files_dict: dict[list], output_directory: str, stdout: bool):
    outdir = Path(output_directory)
    for (filename, contents) in files_dict.items():
        if stdout:
            print(f"# {filename}")
            print(yaml.dump_all(contents))
            continue

        with open(outdir.joinpath(filename), "w") as out_file:
            yaml.dump_all(contents, out_file)


def get_argparser(description):

    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "-d",
        "--dir",
        default="/scenarios/many-namespaces",
        type=Path,
        help="Output directory",
    )

    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Print everything to stdout (debug purposes only)",
    )

    return parser


if __name__ == "__main__":
    raise Exception(
        "This is a library of useful tools and doesn't, itself, generate a scenario"
    )
