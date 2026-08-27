# goapps-shared-proto Makefile
# Protobuf contracts — source of truth for Go + TypeScript codegen.

.PHONY: help tools tools-verify lint format format-check breaking gen gen-go gen-ts gen-all

# =============================================================================
# Pinned Plugin Versions
# =============================================================================
# These versions are the CONTRACT for reproducible codegen. The contents of
# goapps-backend/gen/ were generated with exactly these plugins. Using anything
# else (especially @latest) produces spurious diffs across dozens of files.
# Bump deliberately, regenerate, and commit the resulting diff in one change.

PROTOC_GEN_GO_VERSION          := v1.36.11
PROTOC_GEN_GO_GRPC_VERSION     := v1.6.2
GRPC_GATEWAY_VERSION           := v2.27.0

# protoc-gen-grpc-gateway and protoc-gen-openapiv2 both live inside the
# grpc-gateway module, so they always share GRPC_GATEWAY_VERSION.
PROTOC_GEN_GO_PKG              := google.golang.org/protobuf/cmd/protoc-gen-go
PROTOC_GEN_GO_GRPC_PKG         := google.golang.org/grpc/cmd/protoc-gen-go-grpc
PROTOC_GEN_GRPC_GATEWAY_PKG    := github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway
PROTOC_GEN_OPENAPIV2_PKG       := github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2

help:
	@echo "goapps-shared-proto Makefile"
	@echo ""
	@echo "Toolchain:"
	@echo "  make tools          - Install pinned protoc plugins via 'go install'"
	@echo "  make tools-verify   - Print installed plugin versions"
	@echo ""
	@echo "Checks:"
	@echo "  make lint           - buf lint"
	@echo "  make format         - buf format -w (rewrites in place)"
	@echo "  make format-check   - buf format -d --exit-code (no rewrite)"
	@echo "  make breaking       - buf breaking against origin main"
	@echo ""
	@echo "Codegen:"
	@echo "  make gen-go         - ./scripts/gen-go.sh  (-> ../goapps-backend/gen)"
	@echo "  make gen-ts         - ./scripts/gen-ts.sh  (-> ../goapps-frontend/src/types/generated)"
	@echo "  make gen-all        - both"
	@echo ""
	@echo "Pinned versions:"
	@echo "  protoc-gen-go            $(PROTOC_GEN_GO_VERSION)"
	@echo "  protoc-gen-go-grpc       $(PROTOC_GEN_GO_GRPC_VERSION)"
	@echo "  protoc-gen-grpc-gateway  $(GRPC_GATEWAY_VERSION)"
	@echo "  protoc-gen-openapiv2     $(GRPC_GATEWAY_VERSION)"

# =============================================================================
# Toolchain
# =============================================================================

tools:
	@echo "🔧 Installing pinned protoc plugins..."
	go install $(PROTOC_GEN_GO_PKG)@$(PROTOC_GEN_GO_VERSION)
	go install $(PROTOC_GEN_GO_GRPC_PKG)@$(PROTOC_GEN_GO_GRPC_VERSION)
	go install $(PROTOC_GEN_GRPC_GATEWAY_PKG)@$(GRPC_GATEWAY_VERSION)
	go install $(PROTOC_GEN_OPENAPIV2_PKG)@$(GRPC_GATEWAY_VERSION)
	@echo "✅ Plugins installed to $$(go env GOPATH)/bin"
	@$(MAKE) --no-print-directory tools-verify

tools-verify:
	@echo "📋 Installed plugin versions:"
	@printf '  protoc-gen-go            %s\n' "$$(protoc-gen-go --version 2>&1)"
	@printf '  protoc-gen-go-grpc       %s\n' "$$(protoc-gen-go-grpc --version 2>&1)"
	@printf '  protoc-gen-grpc-gateway  %s\n' "$$(protoc-gen-grpc-gateway --version 2>&1)"
	@printf '  protoc-gen-openapiv2     %s\n' "$$(protoc-gen-openapiv2 --version 2>&1)"

# =============================================================================
# Checks
# =============================================================================

lint:
	buf lint

format:
	buf format -w

format-check:
	buf format -d --exit-code

breaking:
	buf breaking --against 'https://github.com/mutugading/goapps-shared-proto.git#branch=main'

# =============================================================================
# Codegen
# =============================================================================

gen: gen-go

gen-go:
	./scripts/gen-go.sh

gen-ts:
	./scripts/gen-ts.sh

gen-all:
	./scripts/gen-all.sh
