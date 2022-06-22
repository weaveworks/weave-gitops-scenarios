KIND_NETWORK_NAME=kind
KIND_CLUSTER_NAME?=wego-scenarios

MINIO_NETWORK?=kind
MINIO_ROOT_USER?=admin
MINIO_ROOT_PASSWORD?=password
# Container name is also used as the hostname of the server on the docker network
MINIO_CONTAINER_NAME=minio-server

REGISTRY_CONTAINER_NAME=kind-registry

SCENARIOS_IMAGE?=gitops-scenarios

IMAGE_TO_PUSH?=localhost:5001/gitops-server

.PHONY: create-cluster list-clusters delete-cluster is-kind-cluster-context
##@ Cluster operations
create-cluster: ## Make a new kind cluster called $KIND_CLUSTER_NAME
	@if ( kind get clusters | grep $(KIND_CLUSTER_NAME) > /dev/null ) ; then \
		echo "cluster $(KIND_CLUSTER_NAME) already exists, either delete it or ignore this message" ; \
	else \
		kind create cluster --name=$(KIND_CLUSTER_NAME) ; \
		echo "cluster ${KIND_CLUSTER_NAME} created" ; \
	fi

create-cluster-with-registry: start-registry ## Start a kind cluster with an attached registry
	@if ( kind get clusters | grep $(KIND_CLUSTER_NAME) > /dev/null ) ; then \
		echo "cluster $(KIND_CLUSTER_NAME) already exists, either delete it or ignore this message" ; \
	else \
		kind create cluster --name=$(KIND_CLUSTER_NAME) --config=kind/cluster-with-registry-config.yaml ; \
		kubectl apply -f kind/cluster-registry-config-map.yaml ; \
		echo "cluster ${KIND_CLUSTER_NAME} created with registry $(REGISTRY_CONTAINER_NAME)" ; \
	fi

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

# Because of the required order of operations (particularly building a cluster
# with a registry) we may need to make our kind network
create-kind-network:
	@if [ -z "$(shell docker network ls -qf 'name=$(KIND_NETWORK_NAME)')" ] ; then \
		docker network create --subnet "fc00:f853:ccd:e793::/64" \
												  --opt "com.docker.network.bridge.enable_ip_masquerade=true" \
													--opt "com.docker.network.driver.mtu=1500" \
													$(KIND_NETWORK_NAME) ; \
	fi


.PHONY: start-minio add-minio-source add-flux-kustomization
##@ Minio
start-minio: create-kind-network ## Start a minio server running on the kind network
	@if [ ! -z "$(shell docker ps -qaf 'status=running' -f 'name=$(MINIO_CONTAINER_NAME)')" ] ; then \
		echo "$(MINIO_CONTAINER_NAME) already running" ; \
	else \
		docker run -d -v $(PWD):/data \
							-p 9070:9070 -p 9071:9071 --network=$(KIND_NETWORK_NAME) \
							-h $(MINIO_CONTAINER_NAME) \
							-e MINIO_ROOT_USER=$(MINIO_ROOT_USER) \
							-e MINIO_ROOT_PASSWORD=$(MINIO_ROOT_PASSWORD) \
							--name $(MINIO_CONTAINER_NAME) \
							minio/minio server /data --console-address ":9071" --address ":9070"; \
	fi

rm-minio: ## Stop and remove the minio server container
		@if [ ! -z "$(shell docker ps -qaf 'status=running' -f 'name=$(MINIO_CONTAINER_NAME)')" ] ; then \
			docker stop $(MINIO_CONTAINER_NAME); \
			docker container rm $(MINIO_CONTAINER_NAME); \
		else \
			echo "$(MINIO_CONTAINER_NAME) not running" ; \
		fi


.PHONY: start-registry rm-registry
##@ Docker Registry
start-registry: create-kind-network ## Start a docker registry running on the kind network
	@if [ ! -z "$(shell docker ps -qaf 'status=running' -f 'name=$(REGISTRY_CONTAINER_NAME)')" ] ; then \
		echo "$(REGISTRY_CONTAINER_NAME) already running" ; \
	else \
		docker run -d \
							-p "127.0.0.1:5001:5000" --network=$(KIND_NETWORK_NAME) \
							-h $(REGISTRY_CONTAINER_NAME) \
							--name $(REGISTRY_CONTAINER_NAME) \
							registry:2; \
	fi

rm-registry: ## Stop and remove the docker registry container
		@if [ ! -z "$(shell docker ps -qaf 'status=running' -f 'name=$(REGISTRY_CONTAINER_NAME)')" ] ; then \
			docker stop $(REGISTRY_CONTAINER_NAME); \
			docker container rm $(REGISTRY_CONTAINER_NAME); \
		else \
			echo "$(REGISTRY_CONTAINER_NAME) not running" ; \
		fi

push-to-registry: ## Push the image, $IMAGE_TO_PUSH, to the kind-registry (default localhost:5001/gitops-server)
	@docker push $(IMAGE_TO_PUSH)


.PHONY: install-flux add-minio-source add-flux-kustomization access-weave-gitops
##@ Flux
install-flux: create-cluster is-kind-cluster-context ## Install flux
	@flux install

add-minio-source: install-flux start-minio ## Add Minio as a bucket source to flux
	@flux create source bucket flux-system \
				--bucket-name k8s \
				--endpoint="$(MINIO_CONTAINER_NAME):9070" \
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

access-weave-gitops: is-kind-cluster-context ## Set up port-forwarding to access the weave gitops app
	@echo "browse to: http://localhost:9001"
	@kubectl port-forward -n flux-system svc/weave-gitops-app 9001:9001


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
## @ Generate scenario resources
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

.PHONY: run-many-namespaces rm-many-namespaces run-many-podinfo-kustomizations rm-many-podinfo-kustomizations
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


.PHONY: clean-scenarios clean-all-containers
##@ Utilities
clean-scenarios: ## Delete the contents of the scenarios directory
	rm -r scenarios/*

clean-all-docker: delete-cluster rm-minio rm-registry ## delete docker resources (cluster, minio, the registry and the kind network)
	@docker network rm $(KIND_NETWORK_NAME)


.PHONY: help
##@ Meta
# Thanks to https://www.thapaliya.com/en/writings/well-documented-makefiles/
help:  ## Display this help.
ifeq ($(OS),Windows_NT)
				@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n make <target>\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-40s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
else
				@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-40s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
endif
