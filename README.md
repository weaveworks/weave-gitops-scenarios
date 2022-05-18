# GitOps Scenarios

The aim of this repo is to provide some easy to install GitOps configurations that
can be used to test potential configurations of a cluster.

## Proposed method
<!-- FIXME: once this is working change to 'how it works' -->

Initial plan is to configure this with 2 flux directory layouts

1. Base flux: this will install flux, weave-gitops and minio
2. Scenario(s): various sources that can be hosted in minio then used as
   further sources for flux.

This is probably going to be a lot of bash...


## Scenarios

There are various scenarios we want to test but initially

* Multi-namespace workloads: some number of namespaces, each with a workload 
  (initially podinfo)
* Realistic OIDC configurations (this will need DEX setting up)
* Load test workloads e.g. high (network|memory|CPU) loads
