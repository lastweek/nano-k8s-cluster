// Go module for LLMCluster Operator

module github.com/example/llmcluster-operator

go 1.21

require (
	k8s.io/api v0.28.3
	k8s.io/apimachinery v0.28.3
	k8s.io/client-go v0.28.3
	sigs.k8s.io/controller-runtime v0.16.3
)

// To build the operator:
//
// 1. Initialize the module:
//    go mod init github.com/example/llmcluster-operator
//    go mod tidy
//
// 2. Generate CRD types (if using controller-gen):
//    go install sigs.k8s.io/controller-tools/cmd/controller-gen@latest
//    controller-gen object:headerFile="header.go" paths="./..."
//
// 3. Build the binary:
//    go build -o /tmp/manager main.go
//
// 4. Build Docker image:
//    docker build -t llmcluster-operator:latest .
//
// Note: This is a simplified example. For production, you'd use
// Kubebuilder to scaffold the full project structure.
