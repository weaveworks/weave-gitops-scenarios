KIND_CLUSTER_NAME?=wego-scenarios

MINIO_NETWORK?=kind
MINIO_ROOT_USER?=admin
MINIO_ROOT_PASSWORD?=password
# Container name is also used as the hostname of the server on the docker network
MINIO_CONTAINER_NAME=minio-server

SCENARIOS_IMAGE?=gitops-scenarios

.PHONY: create-cluster list-clusters delete-cluster is-kind-cluster-context
##@ Cluster operations
create-cluster: ## Make a new kind cluster called $KIND_CLUSTER_NAME
	@if ( kind get clusters | grep $(KIND_CLUSTER_NAME) > /dev/null ) ; then \
		echo "cluster $(KIND_CLUSTER_NAME) already exists, either delete it or ignore this message"; \
	else \
		kind create cluster --name=$(KIND_CLUSTER_NAME) ; \
	fi

list-clusters: ## List all kind clusters
	@kind get clusters

delete-cluster: ## Make a delete the kind cluster called $KIND_CLUSTER_NAME
	@kind delete cluster --name=$(KIND_CLUSTER_NAME)

is-kind-cluster-context: ## Basic check that kubectl's context is for kind. Skip with SKIP_K8S_CONTEXT_CHECK
# This assumes that you've not made another context which shadows the default
# kind naming scheme. If you have done that then... why?
# Also, sorry for mixing makefile 'if' statements with shell 'if' statements...
ifdef SKIP_K8S_CONTEXT_CHECK
	@echo "Skipping context check"
else
	@if [ "kind-$(KIND_CLUSTER_NAME)" != $(shell kubectl config current-context) ] ; then \
		echo "Not in the expected kind cluster kubectl context, 'kind-$(KIND_CLUSTER_NAME)'." ; \
		echo "This check can be skipped by setting SKIP_K8S_CONTEXT_CHECK" ; \
		echo "otherwise run 'make create-cluster'" ; \
		exit 1; \
	fi
endif


.PHONY: start-minio add-minio-source add-flux-kustomization
##@ Minio
start-minio: ## Start a minio server running on the kind network
	@if [ ! -z "$(shell docker ps -qaf 'status=running' -f 'name=$(MINIO_CONTAINER_NAME)')" ] ; then \
		echo "minio already running" ; \
	else \
		docker run -d -v $(PWD):/data \
							-p 9000:9000 -p 9001:9001 --network=kind \
							-h $(MINIO_CONTAINER_NAME) \
							-e MINIO_ROOT_USER=$(MINIO_ROOT_USER) \
							-e MINIO_ROOT_PASSWORD=$(MINIO_ROOT_PASSWORD) \
							--name $(MINIO_CONTAINER_NAME) \
							minio/minio server /data --console-address ":9001" ; \
	fi

rm-minio: ## Stop and remove the minio server container
		@if [ ! -z "$(shell docker ps -qaf 'status=running' -f 'name=$(MINIO_CONTAINER_NAME)')" ] ; then \
			docker stop $(MINIO_CONTAINER_NAME); \
			docker container rm $(MINIO_CONTAINER_NAME); \
		else \
			echo "minio server, '$(MINIO_CONTAINER_NAME)', not running" ; \
		fi


.PHONY: install-flux
##@ Flux
install-flux: create-cluster is-kind-cluster-context ## Install flux (depends on create-cluster)
	@flux install

add-minio-source: install-flux start-minio ## Add Minio as a bucket source to flux
	@flux create source bucket flux-system \
				--bucket-name k8s \
				--endpoint="$(MINIO_CONTAINER_NAME):9000" \
				--insecure=true \
				--access-key=$(MINIO_ROOT_USER) \
				--secret-key=$(MINIO_ROOT_PASSWORD) \
				--interval=30s

add-flux-kustomization: add-minio-source ## Add the base flux-system kustomization to flux
	@flux create kustomization flux-system \
				--source=bucket/flux-system \
				--path='./cluster' \
				--prune=true \
				--interval=30s

access-weave-gitops: is-kind-cluster-context
	@echo "browse to: http://localhost:5000"
	@kubectl port-forward -n flux-system svc/weave-gitops-app 5000:9001


.PHONY: docker-scenarios-image interactive-scenarios-image
##@ Scenarios Docker Image
docker-scenarios-image: ## Create the scenarios docker image
	@docker build -t $(SCENARIOS_IMAGE) .

interactive-scenarios-image: docker-scenarios-image ## Start a shell in the scenarios docker image with $PWD mounted as /app
	@docker run -ti --rm --entrypoint=/bin/bash \
						-v $(PWD)/scenarios:/scenarios/ \
						-v $(PWD):/app/ \
						$(SCENARIOS_IMAGE)


.PHONY: many-namespaces
##@ Generate scenario resources
SCENARIO_SRC=$(shell find scenario-generators/ -type f)
scenarios/%: $(SCENARIO_SRC)
	@echo "Generating resources for scenario: '$*' => $(subst -,_,$*)"
	@if [ -z "$(shell docker image ls -q $(SCENARIOS_IMAGE))" ]; then \
		echo "scenario image, '$(SCENARIOS_IMAGE)', not found, please run:\n\tmake docker-scenarios-image" ; \
	else \
		docker run --rm -v $(PWD)/scenarios:/scenarios/ \
							$(SCENARIOS_IMAGE) \
							'scenario-generators.$(subst -,_,$*).generate' \
							-d /scenarios/$* $(SCENARIO_ARGS) ; \
		echo "done"; \
	fi


.PHONY: run-many-namespaces rm-many-namespaces
##@ Run Scenarios
_run-%: is-kind-cluster-context scenarios/%
	@flux create kustomization $* \
				--source=bucket/scenarios \
				--path=./$* \
				--prune=true \
				--interval=30s

_rm-%: is-kind-cluster-context
	@flux delete kustomization $*

run-many-namespaces: _run-many-namespaces ## Create a flux kustomization that adds 6 namespaces to the cluster

rm-many-namespaces: _rm-many-namespaces ## Delete the many-namespaces kustomization

run-many-podinfo-kustomizations: _run-many-podinfo-kustomizations ## Create a load of flux kustomizations to run podinfo

rm-many-podinfo-kustomizations: _rm-many-podinfo-kustomizations ## Delete the many-podinfo-kustomizations kustomization



##@ Utilities
clean:
	rm -r scenarios/*


.PHONY: help
##@ Meta
# Thanks to https://www.thapaliya.com/en/writings/well-documented-makefiles/
help:  ## Display this help.
ifeq ($(OS),Windows_NT)
				@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n make <target>\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-40s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
else
				@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-40s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
endif
