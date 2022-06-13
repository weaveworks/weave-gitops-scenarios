# GitOps Scenarios

The aim of this repo is to provide some easy to install GitOps configurations that
can be used to test potential configurations of a cluster.


## Usage

This shows how to start the minio server, a kind cluster with flux and then
run a scenario against it.

```console
$ make add-flux-kustomization
```


## Scenarios

There are various scenarios we want to test but initially

* Multi-namespace workloads: some number of namespaces, each with a workload
  (initially podinfo)
* Realistic OIDC configurations (this will need DEX setting up)
* Load test workloads e.g. high (network|memory|CPU) loads


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
