// +kubebuilder:object:generate=true
// +groupName=serving.ai

package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// LLMClusterSpec defines the desired state of LLMCluster
type LLMClusterSpec struct {
	// Model is the model identifier (e.g., meta-llama/Meta-Llama-3-70B)
	Model string `json:"model"`

	// ModelSize is the size category (8B, 13B, 70B, 405B)
	// +optional
	ModelSize string `json:"modelSize,omitempty"`

	// Replicas is the number of model pods
	Replicas int `json:"replicas"`

	// GPUsPerPod is the number of GPUs per pod
	GPUsPerPod int `json:"gpusPerPod"`

	// TensorParallelSize is the total TP size (replicas × gpusPerPod)
	// +optional
	TensorParallelSize int `json:"tensorParallelSize,omitempty"`

	// Image is the container image for inference
	// +optional
	Image string `json:"image,omitempty"`

	// InferenceEngine is the type of inference engine
	// +optional
	InferenceEngine string `json:"inferenceEngine,omitempty"`

	// InferenceArgs contains additional arguments for the inference engine
	// +optional
	InferenceArgs InferenceArgs `json:"inferenceArgs,omitempty"`

	// Resources defines resource requests and limits
	// +optional
	Resources ResourceRequirements `json:"resources,omitempty"`

	// Router defines router/load balancer configuration
	// +optional
	Router RouterConfig `json:"router,omitempty"`

	// Queue defines request queue configuration
	// +optional
	Queue QueueConfig `json:"queue,omitempty"`

	// Autoscaling defines autoscaling configuration
	// +optional
	Autoscaling AutoscalingConfig `json:"autoscaling,omitempty"`

	// Coordination defines distributed coordination settings
	// +optional
	Coordination CoordinationConfig `json:"coordination,omitempty"`

	// Monitoring defines observability settings
	// +optional
	Monitoring MonitoringConfig `json:"monitoring,omitempty"`

	// Storage defines storage configuration
	// +optional
	Storage StorageConfig `json:"storage,omitempty"`

	// Scheduling defines pod scheduling constraints
	// +optional
	Scheduling SchedulingConfig `json:"scheduling,omitempty"`

	// HighAvailability defines HA settings
	// +optional
	HighAvailability HighAvailabilityConfig `json:"highAvailability,omitempty"`

	// Network defines network configuration
	// +optional
	Network NetworkConfig `json:"network,omitempty"`

	// Security defines security settings
	// +optional
	Security SecurityConfig `json:"security,omitempty"`
}

// LLMClusterStatus defines the observed state of LLMCluster
type LLMClusterStatus struct {
	// Phase is the current phase
	// +optional
	Phase string `json:"phase,omitempty"`

	// Replicas is the actual number of replicas
	// +optional
	Replicas int32 `json:"replicas,omitempty"`

	// ReadyReplicas is the number of ready replicas
	// +optional
	ReadyReplicas int32 `json:"readyReplicas,omitempty"`

	// Conditions represents the latest observations
	// +optional
	Conditions []Condition `json:"conditions,omitempty"`

	// ObservedGeneration is the most recent generation observed
	// +optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// RouterURL is the access URL for the service
	// +optional
	RouterURL string `json:"routerURL,omitempty"`

	// Endpoints is the list of backend endpoints
	// +optional
	Endpoints []string `json:"endpoints,omitempty"`

	// Metrics contains cluster metrics
	// +optional
	Metrics ClusterMetrics `json:"metrics,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:subresource:scale:specpath=.spec.replicas,statuspath=.status.replicas
// +kubebuilder:resource:shortName=llm
// +kubebuilder:resource:shortName=llmc
// +kubebuilder:printcolumn:name="Model",type=string,JSONPath=`.spec.model`
// +kubebuilder:printcolumn:name="Replicas",type=integer,JSONPath=`.spec.replicas`
// +kubebuilder:printcolumn:name="GPUs",type=integer,JSONPath=`.spec.tensorParallelSize`
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

// LLMCluster is the Schema for the llmclusters API
type LLMCluster struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   LLMClusterSpec   `json:"spec,omitempty"`
	Status LLMClusterStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// LLMClusterList contains a list of LLMCluster
type LLMClusterList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []LLMCluster `json:"items"`
}

// Condition defines an observation of a LLMCluster's state
type Condition struct {
	// Type of condition
	Type string `json:"type"`

	// Status of the condition (True, False, Unknown)
	Status string `json:"status"`

	// Reason for the condition's last transition
	// +optional
	Reason string `json:"reason,omitempty"`

	// Human-readable message indicating details
	// +optional
	Message string `json:"message,omitempty"`

	// Last time the condition transitioned
	// +optional
	LastTransitionTime metav1.Time `json:"lastTransitionTime,omitempty"`
}

// ClusterMetrics contains cluster-level metrics
type ClusterMetrics struct {
	// TotalGPUs is the total number of GPUs
	// +optional
	TotalGPUs int `json:"totalGPUs,omitempty"`

	// QueueLength is the current queue length
	// +optional
	QueueLength int `json:"queueLength,omitempty"`

	// AvgRequestDuration is the average request duration
	// +optional
	AvgRequestDuration string `json:"avgRequestDuration,omitempty"`
}

// InferenceArgs contains inference engine arguments
type InferenceArgs struct {
	// MaxModelLen is the maximum context length
	// +optional
	MaxModelLen int `json:"maxModelLen,omitempty"`

	// BlockSize is the KV cache block size
	// +optional
	BlockSize int `json:"blockSize,omitempty"`

	// Dtype is the data type (half, bfloat16, float16)
	// +optional
	Dtype string `json:"dtype,omitempty"`

	// GPUMemoryUtilization is the GPU memory utilization fraction (0.0-1.0)
	// +optional
	GPUMemoryUtilization float64 `json:"gpuMemoryUtilization,omitempty"`
}

// ResourceRequirements defines resource requirements
type ResourceRequirements struct {
	// Requests defines resource requests
	// +optional
	Requests corev1.ResourceList `json:"requests,omitempty"`

	// Limits defines resource limits
	// +optional
	Limits corev1.ResourceList `json:"limits,omitempty"`
}

// RouterConfig defines router configuration
type RouterConfig struct {
	// Enabled indicates whether the router is enabled
	// +optional
	Enabled bool `json:"enabled,omitempty"`

	// Replicas is the number of router replicas
	// +optional
	Replicas int `json:"replicas,omitempty"`

	// Image is the router image
	// +optional
	Image string `json:"image,omitempty"`

	// Type is the router implementation (nginx, envoy, custom)
	// +optional
	Type string `json:"type,omitempty"`
}

// QueueConfig defines request queue configuration
type QueueConfig struct {
	// Enabled indicates whether the queue is enabled
	// +optional
	Enabled bool `json:"enabled,omitempty"`

	// Replicas is the number of queue replicas
	// +optional
	Replicas int `json:"replicas,omitempty"`

	// Backend is the queue implementation (redis, rabbitmq, custom)
	// +optional
	Backend string `json:"backend,omitempty"`

	// Capacity is the maximum queue size
	// +optional
	Capacity int `json:"capacity,omitempty"`
}

// AutoscalingConfig defines autoscaling configuration
type AutoscalingConfig struct {
	// Enabled indicates whether autoscaling is enabled
	// +optional
	Enabled bool `json:"enabled,omitempty"`

	// MinReplicas is the minimum number of replicas
	// +optional
	MinReplicas int `json:"minReplicas,omitempty"`

	// MaxReplicas is the maximum number of replicas
	// +optional
	MaxReplicas int `json:"maxReplicas,omitempty"`

	// TargetCPUUtilizationPercentage is the target CPU utilization
	// +optional
	TargetCPUUtilizationPercentage int `json:"targetCPUUtilizationPercentage,omitempty"`

	// CustomMetric defines custom metric autoscaling
	// +optional
	CustomMetric CustomMetric `json:"customMetric,omitempty"`
}

// CustomMetric defines a custom metric for autoscaling
type CustomMetric struct {
	// Name is the metric name
	// +optional
	Name string `json:"name,omitempty"`

	// Target defines the metric target
	// +optional
	Target MetricTarget `json:"target,omitempty"`
}

// MetricTarget defines a metric target
type MetricTarget struct {
	// AverageValue is the target average value
	// +optional
	AverageValue string `json:"averageValue,omitempty"`
}

// CoordinationConfig defines distributed coordination settings
type CoordinationConfig struct {
	// Enabled indicates whether coordination is enabled
	// +optional
	Enabled bool `json:"enabled,omitempty"`

	// LeaderElection indicates whether leader election is enabled
	// +optional
	LeaderElection bool `json:"leaderElection,omitempty"`

	// PodManagementPolicy is the StatefulSet pod management policy
	// +optional
	PodManagementPolicy string `json:"podManagementPolicy,omitempty"`
}

// MonitoringConfig defines observability settings
type MonitoringConfig struct {
	// Enabled indicates whether monitoring is enabled
	// +optional
	Enabled bool `json:"enabled,omitempty"`

	// Prometheus indicates whether Prometheus scraping is enabled
	// +optional
	Prometheus bool `json:"prometheus,omitempty"`

	// Grafana indicates whether Grafana is deployed
	// +optional
	Grafana bool `json:"grafana,omitempty"`

	// DCGMExporter indicates whether DCGM exporter is enabled
	// +optional
	DCGMExporter bool `json:"dcgmExporter,omitempty"`
}

// StorageConfig defines storage configuration
type StorageConfig struct {
	// ShmSize is the shared memory size for GPU communication
	// +optional
	ShmSize string `json:"shmSize,omitempty"`

	// ModelCache defines model cache PVC configuration
	// +optional
	ModelCache ModelCache `json:"modelCache,omitempty"`
}

// ModelCache defines model cache configuration
type ModelCache struct {
	// Enabled indicates whether model cache is enabled
	// +optional
	Enabled bool `json:"enabled,omitempty"`

	// StorageClass is the storage class for model cache
	// +optional
	StorageClass string `json:"storageClass,omitempty"`

	// Size is the size of model cache
	// +optional
	Size string `json:"size,omitempty"`
}

// SchedulingConfig defines pod scheduling constraints
type SchedulingConfig struct {
	// NodeSelector defines node selector for pods
	// +optional
	NodeSelector map[string]string `json:"nodeSelector,omitempty"`

	// PodAntiAffinity defines pod anti-affinity policy
	// +optional
	PodAntiAffinity string `json:"podAntiAffinity,omitempty"`

	// TopologySpreadConstraints defines topology spread constraints
	// +optional
	TopologySpreadConstraints []interface{} `json:"topologySpreadConstraints,omitempty"`
}

// HighAvailabilityConfig defines HA settings
type HighAvailabilityConfig struct {
	// PodDisruptionBudget defines PDB configuration
	// +optional
	PodDisruptionBudget PDBConfig `json:"podDisruptionBudget,omitempty"`

	// TerminationGracePeriodSeconds is the grace period for termination
	// +optional
	TerminationGracePeriodSeconds int `json:"terminationGracePeriodSeconds,omitempty"`
}

// PDBConfig defines PodDisruptionBudget configuration
type PDBConfig struct {
	// Enabled indicates whether PDB is enabled
	// +optional
	Enabled bool `json:"enabled,omitempty"`

	// MinAvailable is the minimum available pods
	// +optional
	MinAvailable int `json:"minAvailable,omitempty"`
}

// NetworkConfig defines network configuration
type NetworkConfig struct {
	// ServiceType is the service type (ClusterIP, LoadBalancer, NodePort)
	// +optional
	ServiceType string `json:"serviceType,omitempty"`

	// Port is the service port
	// +optional
	Port int `json:"port,omitempty"`

	// NetworkPolicy indicates whether network policy is enabled
	// +optional
	NetworkPolicy bool `json:"networkPolicy,omitempty"`
}

// SecurityConfig defines security settings
type SecurityConfig struct {
	// HuggingfaceToken defines HF token configuration
	// +optional
	HuggingfaceToken HuggingfaceToken `json:"huggingfaceToken,omitempty"`

	// ServiceAccountName is the custom service account for pods
	// +optional
	ServiceAccountName string `json:"serviceAccountName,omitempty"`
}

// HuggingfaceToken defines Hugging Face authentication
type HuggingfaceToken struct {
	// SecretName is the secret containing HF token
	// +optional
	SecretName string `json:"secretName,omitempty"`

	// SecretKey is the key in the secret
	// +optional
	SecretKey string `json:"secretKey,omitempty"`
}

func init() {
	SchemeBuilder.Register(&LLMCluster{}, &LLMClusterList{})
}
