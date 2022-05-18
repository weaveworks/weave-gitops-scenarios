KIND_CLUSTER_NAME?=wego-scenarios

MINIO_CONTAINER_NAME=minio-server
MINIO_ROOT_USER?=minio
MINIO_ROOT_PASSWORD?=minioPassword

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


.PHONY: install-flux
##@ Flux
install-flux: create-cluster is-kind-cluster-context ## Install flux (depends on create-cluster)
	@flux install


.PHONY: start-minio add-minio-source add-flux-kustomization
##@ Minio
# start-minio: install-flux ## Install Minio (depends on install-flux)
start-minio: ## Start a minio server running on the kind network
# 	if ( docker inspect $(MINIO_CONTAINER_NAME) &> /dev/null ) ; then
	@if [ ! -z "$(shell docker ps -qaf 'status=running' -f 'name=$(MINIO_CONTAINER_NAME)')" ] ; then \
		echo "minio already running" ; \
	else \
		docker run -d -v $(PWD):/data \
		 						-p 9000:9000 -p 9001:9001 --network=kind \
		 						-e MINIO_ROOT_USER=$(MINIO_ROOT_USER) \
		 						-e MINIO_ROOT_PASSWORD=$(MINIO_ROOT_PASSWORD) \
		 					  --name $(MINIO_CONTAINER_NAME) \
 		 						minio/minio server /data --console-address ":9001" ; \
 	fi

add-minio-source: start-minio install-flux
	@flux create source bucket flux-system \
				--bucket-name k8s \
				--endpoint="$(shell docker inspect -f '{{ .NetworkSettings.Networks.kind.IPAddress }}' $(MINIO_CONTAINER_NAME)):9000" \
				--insecure=true \
				--access-key=$(MINIO_ROOT_USER) \
				--secret-key=$(MINIO_ROOT_PASSWORD) \
				--interval=30s

add-flux-kustomization: add-minio-source
	@flux create kustomization bucket flux-system \
				--source=bucket/flux-system \
				--path='./cluster' \
  			--prune=true \
  			--validation=client \
				--interval=30s


.PHONY: help
##@ Meta
# Thanks to https://www.thapaliya.com/en/writings/well-documented-makefiles/
help:  ## Display this help.
ifeq ($(OS),Windows_NT)
				@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n make <target>\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  %-40s %s\n", $$1, $$2 } /^##@/ { printf "\n%s\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
else
				@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-40s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
endif

