import os
import yaml

from uuid import uuid4
from base64 import b64encode

from ..lib.generate import get_argparser, write_scenario
from ..lib.make_resource import make_namespace, make_kustomization

__SCENARIO__ = "dex"
__OIDC_CLIENT_CONF__ = {
    "name": "Weave Gitops",
    # The issuer is the full k8s service address
    "issuer": "http://dex-dex.dex.svc.cluster.local:5556",
    "secret": "B7Skl2cfSoOQgOhIkeqxx1uJjWxjCFoEEymk",
    "id": "weave-gitops-app",
    "redirectURIs": ["http://localhost:9001/oauth2/callback"],
}

# Map the dex OIDC static client config keys to the weave-gitops ones
# (skip 'name' & ignore duration as that has a default)
__DEX_GITOPS_OIDC_MAPPING__ = [
    ("issuer", "issuerURL"),
    ("secret", "clientSecret"),
    ("id", "clientID"),
    ("redirectURIs", "redirectURL"),
]

# Use the same bcrypt hash for every user's password (which is 'password')
# generated using:
#  $> htpasswd -nbBC10 n/a password | cut -d ':'  -f2
__PASSWORD_HASH__ = "$2y$10$5b/iK/HHCyYRk7S0iNaqn.mb36QbC0sSNKR5Rnhh/cITPgdviwfcu"


__RELEASE_FILE__ = os.path.join(os.path.dirname(__file__), "./templates/release.yaml")


def make_user(name):
    name = name.lower()
    return {
        "email": f"{name}@test.invalid",
        "username": name,
        "userID": str(uuid4()),
        "hash": __PASSWORD_HASH__,
    }


def make_dex_release(user_names=["alice", "bob"]):
    with open(__RELEASE_FILE__) as base_release:
        base = yaml.load(base_release, yaml.Loader)

    config = base["spec"]["values"]["config"]

    config["issuer"] = __OIDC_CLIENT_CONF__["issuer"]

    config["staticClients"] = [
        {k: __OIDC_CLIENT_CONF__[k] for k in ["name", "id", "secret", "redirectURIs"]}
    ]

    config["staticPasswords"] = [make_user(u) for u in user_names]

    return base


def to_b64(string):
    return b64encode(string.encode("utf-8")).decode("utf-8")


def make_secret(data):
    return {
        "apiVersion": "v1",
        "kind": "Secret",
        "metadata": {
            "name": "oidc-auth",
            "namespace": "flux-system",
        },
        "data": {k: to_b64(v) for (k, v) in data.items()},
    }


def main() -> dict[list]:

    oidc_data = {
        gitops_key: __OIDC_CLIENT_CONF__[dex_key]
        for (dex_key, gitops_key) in __DEX_GITOPS_OIDC_MAPPING__
    }

    oidc_data["redirectURL"] = oidc_data["redirectURL"][0]

    resources = {
        "namespace.yaml": make_namespace(__SCENARIO__),
        "release.yaml": make_dex_release(),
        "oidc-secret.yaml": make_secret(oidc_data),
    }

    resources["kustomization.yaml"] = make_kustomization(list(resources.keys()))

    return resources


if __name__ == "__main__":
    import argparse

    parser = get_argparser(__SCENARIO__, "Install and run dex")

    args = parser.parse_args()
    write_scenario(main(), args.dir, args.stdout)
