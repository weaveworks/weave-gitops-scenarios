# GitOps Scenarios

The aim of this repo is to provide some easy to install GitOps configurations that
can be used to test potential configurations of a cluster.

## HEALTH WARNING

The scenarios configured in this repo are designed for local use only. Running
them against kubernetes clusters elsewhere should only be done after careful
inspection of the configuration.

This repo configures several systems with the password `password`.


## Usage

This shows how to start the minio server, a kind cluster with flux and then
run a scenario against it.

```console
$ make install-weave-gitops              # Create the cluster & install flux on it
$ make run-many-podinfo-kustomizations   # Run the many-podinfo-kustomizations scenario
$ make access-weave-gitops               # View the gitops UI
browse to: http://localhost:5000
Forwarding from 127.0.0.1:5000 -> 9001
Forwarding from [::1]:5000 -> 9001
...
$ make rm-many-podinfo-kustomizations    # Stop running the scenario
$ make delete-cluster                    # Stop the cluster
$ make rm-minio                          # Stop minio
```

If you're developing scenario-generators you can run
```console
$ make interactive-scenarios-image
> runscenario many_podinfo_kustomizations -n 90 --stdout
```
to start a TTY shell in the docker image. The helper function `runscenario` is
configured to make it easy to run scenarios.

**Note** because the scenario-generators are written in python they use `_` in
their names rather than `-` (as is used elsewhere).


## Scenarios

There are various scenarios we want to test but initially

* Multi-namespace workloads: some number of namespaces, each with a workload
  (initially podinfo)
* Realistic OIDC configurations (this will need DEX setting up)
* Load test workloads e.g. high (network|memory|CPU) loads

### Dex

The Dex scenario configures several static users, all with the same password
(`password`):

* alice@test.invalid (password: 'password')
* bob@test.invalid (password: 'password')

Because of how dex works to use this scenario you need to add the following
to your `/etc/hosts` file (or other, OS appropriate, analogue):

```
# enable dex callbacks to route kind
127.0.0.1 dex-dex.dex.svc.cluster.local
```

This specifies that, on your machine only, the URL `dex-dex.dex.svc.cluster.local`
resolves to `127.0.0.1` (the localhost, i.e. your machine). This should only be
done on your dev machine.

If you want to know _why_ you have to do this, please read
[why edit /etc/hosts](./docs/why-edit-etc-hosts.md)


## How this works

1. Run a [kind cluster](https://kind.sigs.k8s.io/) as a k8s environment
2. Run [minio](https://docs.min.io/) as an S3-style bucket source with every directory in this
   repo as a bucket
3. Install flux on the cluster
4. Add the minio `./k8s` bucket as a flux bucket-source for `flux-system`
5. Add a `flux-system` as a kustomization
6. Add scenarios as specific kustomizations.

## Scenario Generators

Scenarios that require a lot of resources to be made (e.g. for load testing)
can be created by adding a `<scenario-name>/generate.py` in
`scenario-generators` and running `make scenario/<scenario-name>` which will
run the script and write the output to `/scenarios`.

The generators assume they'll receive an argument of `-d <directory>` to indicate
where the output files will be written to. The default make target runs a docker
image that will call the generator targetting the mounted `/scenarios` directory.
