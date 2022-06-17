import argparse
import sys
import yaml

from pathlib import Path


def __create_dir_if_needed(path, stdout):
    if stdout and path.exists():
        return

    if stdout and not path.exists():
        print(f"# Would create {path}")
        return

    if not path.exists():
        path.mkdir(parents=True)


def write_scenario(files_dict: dict, output_directory: str, stdout: bool):
    outdir = Path(output_directory)

    __create_dir_if_needed(outdir, stdout)

    for (filename, contents) in files_dict.items():
        if "/" in filename:
            subpaths = filename.split("/")[:-1]
            __create_dir_if_needed(outdir.joinpath(*subpaths), stdout)

        try:
            stream = sys.stdout if stdout else outdir.joinpath(filename).open("w")

            if stdout:
                print(f"# {filename}\n")

            if type(contents) is list:
                yaml.dump_all(contents, stream)
            else:
                yaml.dump(contents, stream)

        finally:
            if stream is not sys.stdout:
                stream.close()


def get_argparser(scenario, description):

    parser = argparse.ArgumentParser(description=description)
    parser.add_argument(
        "-d",
        "--dir",
        default=f"/scenarios/{scenario}",
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
