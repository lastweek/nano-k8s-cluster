// LLMCluster Operator Controller
//
// This controller reconciles LLMCluster custom resources.
// For each LLMCluster, it creates and manages:
// - StatefulSet (model pods)
// - Deployment (router)
// - Deployment (queue)
// - Services
// - ConfigMaps
// - HPA (if autoscaling enabled)
// - PDB (if HA enabled)
// - NetworkPolicy (if enabled)
//
// Usage:
//   go run main.go
//
// +kubebuilder:rbac:groups=serving.ai,resources=llmclusters,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=serving.ai,resources=llmclusters/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=serving.ai,resources=llmclusters/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=statefulsets;deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=services;configmaps;events;pods,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=autoscaling,resources=horizontalpodautoscalers,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=policy,resources=poddisruptionbudgets,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=networkpolicies,verbs=get;list;watch;create;update;patch;delete

package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	autoscalingv2 "k8s.io/api/autoscaling/v2"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/client-go/tools/record"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/healthz"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
	"sigs.k8s.io/controller-runtime/pkg/metrics/server"

	// CRD Types - in a real project, these would be in api/v1alpha1/
	servingv1alpha1 "github.com/example/llmcluster-operator/api/v1alpha1"
)

// LLMClusterReconciler reconciles a LLMCluster object
type LLMClusterReconciler struct {
	client.Client
	Scheme   *runtime.Scheme
	Recorder record.EventRecorder
}

// RBAC markers (for controller-gen)
// +kubebuilder:rbac:groups=serving.ai,resources=llmclusters,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=serving.ai,resources=llmclusters/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps,resources=statefulsets,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=autoscaling,resources=horizontalpodautoscalers,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=policy,resources=poddisruptionbudgets,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=networkpolicies,verbs=get;list;watch;create;update;patch;delete

// Reconcile is the main reconciliation loop
func (r *LLMClusterReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := ctrl.LoggerFrom(ctx)

	// ============================================
	// 1. Fetch the LLMCluster instance
	// ============================================
	log.Info("Reconciling LLMCluster", "name", req.Name)

	var llmCluster servingv1alpha1.LLMCluster
	if err := r.Get(ctx, req.NamespacedName, &llmCluster); err != nil {
		if errors.IsNotFound(err) {
			// Object deleted, stop reconciling
			log.Info("LLMCluster deleted, nothing to do")
			return ctrl.Result{}, nil
		}
		// Error reading the object
		log.Error(err, "unable to fetch LLMCluster")
		return ctrl.Result{}, err
	}

	// ============================================
	// 2. Validate the spec
	// ============================================
	if err := r.validateSpec(&llmCluster); err != nil {
		log.Error(err, "LLMCluster spec validation failed")
		r.Recorder.Event(&llmCluster, corev1.EventTypeWarning, "ValidationFailed", err.Error())
		return ctrl.Result{}, err
	}

	// ============================================
	// 3. Update status to "Creating"
	// ============================================
	if llmCluster.Status.Phase != "Creating" && llmCluster.Status.Phase != "Running" {
		llmCluster.Status.Phase = "Creating"
		if err := r.Status().Update(ctx, &llmCluster); err != nil {
			log.Error(err, "unable to update LLMCluster status")
			return ctrl.Result{}, err
		}
	}

	// ============================================
	// 4. Reconcile child resources
	// ============================================

	// 4a. Reconcile StatefulSet (model pods)
	statefulSet, err := r.reconcileStatefulSet(ctx, &llmCluster)
	if err != nil {
		log.Error(err, "unable to reconcile StatefulSet")
		return ctrl.Result{RequeueAfter: time.Second * 5}, err
	}

	// 4b. Reconcile Router Deployment
	if llmCluster.Spec.Router.Enabled {
		if err := r.reconcileRouterDeployment(ctx, &llmCluster); err != nil {
			log.Error(err, "unable to reconcile Router Deployment")
			return ctrl.Result{RequeueAfter: time.Second * 5}, err
		}
	}

	// 4c. Reconcile Queue Deployment
	if llmCluster.Spec.Queue.Enabled {
		if err := r.reconcileQueueDeployment(ctx, &llmCluster); err != nil {
			log.Error(err, "unable to reconcile Queue Deployment")
			return ctrl.Result{RequeueAfter: time.Second * 5}, err
		}
	}

	// 4d. Reconcile Services
	if err := r.reconcileServices(ctx, &llmCluster); err != nil {
		log.Error(err, "unable to reconcile Services")
		return ctrl.Result{RequeueAfter: time.Second * 5}, err
	}

	// 4e. Reconcile ConfigMaps
	if err := r.reconcileConfigMaps(ctx, &llmCluster); err != nil {
		log.Error(err, "unable to reconcile ConfigMaps")
		return ctrl.Result{RequeueAfter: time.Second * 5}, err
	}

	// 4f. Reconcile HPA (if autoscaling enabled)
	if llmCluster.Spec.Autoscaling.Enabled {
		if err := r.reconcileHPA(ctx, &llmCluster); err != nil {
			log.Error(err, "unable to reconcile HPA")
			return ctrl.Result{RequeueAfter: time.Second * 5}, err
		}
	}

	// 4g. Reconcile PDB (if HA enabled)
	if llmCluster.Spec.HighAvailability.PodDisruptionBudget.Enabled {
		if err := r.reconcilePDB(ctx, &llmCluster); err != nil {
			log.Error(err, "unable to reconcile PDB")
			return ctrl.Result{RequeueAfter: time.Second * 5}, err
		}
	}

	// 4h. Reconcile NetworkPolicy (if enabled)
	if llmCluster.Spec.Network.NetworkPolicy {
		if err := r.reconcileNetworkPolicy(ctx, &llmCluster); err != nil {
			log.Error(err, "unable to reconcile NetworkPolicy")
			return ctrl.Result{RequeueAfter: time.Second * 5}, err
		}
	}

	// ============================================
	// 5. Update status
	// ============================================
	readyReplicas := statefulSet.Status.ReadyReplicas
	llmCluster.Status.Replicas = int32(llmCluster.Spec.Replicas)
	llmCluster.Status.ReadyReplicas = readyReplicas
	llmCluster.Status.ObservedGeneration = llmCluster.Generation
	llmCluster.Status.Metrics.TotalGPUs = llmCluster.Spec.Replicas * llmCluster.Spec.GPUsPerPod

	// Determine phase
	if readyReplicas == int32(llmCluster.Spec.Replicas) {
		llmCluster.Status.Phase = "Running"
		llmCluster.Status.Conditions = []servingv1alpha1.Condition{
			{
				Type:               "Ready",
				Status:             "True",
				Reason:             "AllPodsReady",
				Message:            fmt.Sprintf("All %d replicas are ready", readyReplicas),
				LastTransitionTime: metav1.Now(),
			},
		}
	} else {
		llmCluster.Status.Phase = "Progressing"
		llmCluster.Status.Conditions = []servingv1alpha1.Condition{
			{
				Type:               "Ready",
				Status:             "False",
				Reason:             "PodsNotReady",
				Message:            fmt.Sprintf("%d/%d pods ready", readyReplicas, llmCluster.Spec.Replicas),
				LastTransitionTime: metav1.Now(),
			},
		}
	}

	if err := r.Status().Update(ctx, &llmCluster); err != nil {
		log.Error(err, "unable to update LLMCluster status")
		return ctrl.Result{}, err
	}

	// ============================================
	// 6. Requeue for next reconciliation
	// ============================================
	// Requeue more frequently if not ready
	if readyReplicas < int32(llmCluster.Spec.Replicas) {
		return ctrl.Result{RequeueAfter: time.Second * 10}, nil
	}

	return ctrl.Result{RequeueAfter: time.Minute * 5}, nil
}

// validateSpec validates the LLMCluster spec
func (r *LLMClusterReconciler) validateSpec(llmCluster *servingv1alpha1.LLMCluster) error {
	// Validate tensor parallel size
	expectedTPSize := llmCluster.Spec.Replicas * llmCluster.Spec.GPUsPerPod
	if llmCluster.Spec.TensorParallelSize != 0 && llmCluster.Spec.TensorParallelSize != expectedTPSize {
		return fmt.Errorf("tensorParallelSize must equal replicas × gpusPerPod (%d), got %d",
			expectedTPSize, llmCluster.Spec.TensorParallelSize)
	}

	return nil
}

// reconcileStatefulSet creates or updates the StatefulSet for model pods
func (r *LLMClusterReconciler) reconcileStatefulSet(ctx context.Context, llmCluster *servingv1alpha1.LLMCluster) (*appsv1.StatefulSet, error) {
	log := ctrl.LoggerFrom(ctx)

	// Define the StatefulSet
	desiredStatefulSet := &appsv1.StatefulSet{
		ObjectMeta: metav1.ObjectMeta{
			Name:      llmCluster.Name,
			Namespace: llmCluster.Namespace,
			Labels: map[string]string{
				"app":                        llmCluster.Name,
				"llmcluster.serving.ai/owned": "true",
			},
		},
		Spec: appsv1.StatefulSetSpec{
			ServiceName:         fmt.Sprintf("%s-backend", llmCluster.Name),
			Replicas:            func() *int32 { i := int32(llmCluster.Spec.Replicas); return &i }(),
			PodManagementPolicy: appsv1.PodManagementPolicyType(llmCluster.Spec.Coordination.PodManagementPolicy),
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app": llmCluster.Name,
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app": llmCluster.Name,
					},
				},
				Spec: corev1.PodSpec{
					Affinity: &corev1.Affinity{
						PodAntiAffinity: &corev1.PodAntiAffinity{
							RequiredDuringSchedulingIgnoredDuringExecution: []corev1.PodAffinityTerm{
								{
									LabelSelector: &metav1.LabelSelector{
										MatchLabels: map[string]string{"app": llmCluster.Name},
									},
									TopologyKey: "kubernetes.io/hostname",
								},
							},
						},
					},
					Containers: []corev1.Container{
						{
							Name:    "inference",
							Image:   llmCluster.Spec.Image,
							Command: []string{"python", "-m", "vllm.entrypoints.openai.api_server"},
							Args: []string{
								fmt.Sprintf("--model=%s", llmCluster.Spec.Model),
								fmt.Sprintf("--tensor-parallel-size=%d", llmCluster.Spec.TensorParallelSize),
								"--host=0.0.0.0",
								"--port=8000",
							},
							Env: []corev1.EnvVar{
								{
									Name: "POD_NAME",
									ValueFrom: &corev1.EnvVarSource{
										FieldRef: &corev1.ObjectFieldSelector{
											FieldPath: "metadata.name",
										},
									},
								},
								{
									Name:  "MASTER_ADDR",
									Value: fmt.Sprintf("%s-0.%s-backend.%s.svc.cluster.local", llmCluster.Name, llmCluster.Name, llmCluster.Namespace),
								},
								{
									Name:  "MASTER_PORT",
									Value: "5000",
								},
							},
							Ports: []corev1.ContainerPort{
								{Name: "http", ContainerPort: 8000},
							},
							Resources: corev1.ResourceRequirements{
								Requests: corev1.ResourceList{
									corev1.ResourceName("nvidia.com/gpu"): *resource.NewQuantity(int64(llmCluster.Spec.GPUsPerPod), resource.DecimalSI),
								},
							},
							VolumeMounts: []corev1.VolumeMount{
								{Name: "shm", MountPath: "/dev/shm"},
							},
						},
					},
					Volumes: []corev1.Volume{
						{
							Name: "shm",
							VolumeSource: corev1.VolumeSource{
								EmptyDir: &corev1.EmptyDirVolumeSource{
									Medium:    corev1.StorageMediumMemory,
									SizeLimit: resource.NewQuantity(16*1024*1024*1024, resource.BinarySI), // 16Gi
								},
							},
						},
					},
				},
			},
		},
	}

	// Apply node selector if specified
	if llmCluster.Spec.Scheduling.NodeSelector != nil {
		desiredStatefulSet.Spec.Template.Spec.NodeSelector = llmCluster.Spec.Scheduling.NodeSelector
	}

	// Set owner reference
	if err := ctrl.SetControllerReference(llmCluster, desiredStatefulSet, r.Scheme); err != nil {
		return nil, err
	}

	// Create or update
	var actualStatefulSet appsv1.StatefulSet
	err := r.Get(ctx, client.ObjectKeyFromObject(desiredStatefulSet), &actualStatefulSet)
	if err != nil {
		if errors.IsNotFound(err) {
			log.Info("Creating StatefulSet", "name", desiredStatefulSet.Name)
			if err := r.Create(ctx, desiredStatefulSet); err != nil {
				return nil, err
			}
			r.Recorder.Event(llmCluster, corev1.EventTypeNormal, "Created", "Created StatefulSet")
			return desiredStatefulSet, nil
		}
		return nil, err
	}

	// Update if needed
	actualStatefulSet.Spec = desiredStatefulSet.Spec
	if err := r.Update(ctx, &actualStatefulSet); err != nil {
		return nil, err
	}

	return &actualStatefulSet, nil
}

// reconcileRouterDeployment creates or updates the router Deployment
func (r *LLMClusterReconciler) reconcileRouterDeployment(ctx context.Context, llmCluster *servingv1alpha1.LLMCluster) error {
	// TODO: Implement router Deployment creation
	return nil
}

// reconcileQueueDeployment creates or updates the queue Deployment
func (r *LLMClusterReconciler) reconcileQueueDeployment(ctx context.Context, llmCluster *servingv1alpha1.LLMCluster) error {
	// TODO: Implement queue Deployment creation
	return nil
}

// reconcileServices creates or updates Services
func (r *LLMClusterReconciler) reconcileServices(ctx context.Context, llmCluster *servingv1alpha1.LLMCluster) error {
	// TODO: Implement Service creation
	return nil
}

// reconcileConfigMaps creates or updates ConfigMaps
func (r *LLMClusterReconciler) reconcileConfigMaps(ctx context.Context, llmCluster *servingv1alpha1.LLMCluster) error {
	// TODO: Implement ConfigMap creation
	return nil
}

// reconcileHPA creates or updates HorizontalPodAutoscaler
func (r *LLMClusterReconciler) reconcileHPA(ctx context.Context, llmCluster *servingv1alpha1.LLMCluster) error {
	desiredHPA := &autoscalingv2.HorizontalPodAutoscaler{
		ObjectMeta: metav1.ObjectMeta{
			Name:      fmt.Sprintf("%s-hpa", llmCluster.Name),
			Namespace: llmCluster.Namespace,
		},
		Spec: autoscalingv2.HorizontalPodAutoscalerSpec{
			ScaleTargetRef: autoscalingv2.CrossVersionObjectReference{
				APIVersion: "apps/v1",
				Kind:       "StatefulSet",
				Name:       llmCluster.Name,
			},
			MinReplicas: func() *int32 { i := int32(llmCluster.Spec.Autoscaling.MinReplicas); return &i }(),
			MaxReplicas: int32(llmCluster.Spec.Autoscaling.MaxReplicas),
			Metrics: []autoscalingv2.MetricSpec{
				{
					Type: autoscalingv2.ResourceMetricSourceType,
					Resource: &autoscalingv2.ResourceMetricSource{
						Name: corev1.ResourceCPU,
						Target: autoscalingv2.MetricTarget{
							Type:               autoscalingv2.UtilizationMetricType,
							AverageUtilization: func() *int32 { i := int32(llmCluster.Spec.Autoscaling.TargetCPUUtilizationPercentage); return &i }(),
						},
					},
				},
			},
		},
	}

	if err := ctrl.SetControllerReference(llmCluster, desiredHPA, r.Scheme); err != nil {
		return err
	}

	// Create or update
	var actualHPA autoscalingv2.HorizontalPodAutoscaler
	err := r.Get(ctx, client.ObjectKeyFromObject(desiredHPA), &actualHPA)
	if err != nil {
		if errors.IsNotFound(err) {
			if err := r.Create(ctx, desiredHPA); err != nil {
				return err
			}
			r.Recorder.Event(llmCluster, corev1.EventTypeNormal, "Created", "Created HPA")
			return nil
		}
		return err
	}

	actualHPA.Spec = desiredHPA.Spec
	return r.Update(ctx, &actualHPA)
}

// reconcilePDB creates or updates PodDisruptionBudget
func (r *LLMClusterReconciler) reconcilePDB(ctx context.Context, llmCluster *servingv1alpha1.LLMCluster) error {
	// TODO: Implement PDB creation
	return nil
}

// reconcileNetworkPolicy creates or updates NetworkPolicy
func (r *LLMClusterReconciler) reconcileNetworkPolicy(ctx context.Context, llmCluster *servingv1alpha1.LLMCluster) error {
	// TODO: Implement NetworkPolicy creation
	return nil
}

// SetupWithManager sets up the controller with the Manager
func (r *LLMClusterReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&servingv1alpha1.LLMCluster{}).
		Owns(&appsv1.StatefulSet{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Owns(&autoscalingv2.HorizontalPodAutoscaler{}).
		Complete(r)
}

func main() {
	// ============================================
	// 1. Setup logging
	// ============================================
	opts := zap.Options{
		Development: false,
	}
	opts.BindFlags(flag.CommandLine)
	flag.Parse()

	log := zap.New(zap.UseFlagOptions(&opts))
	ctrl.SetLogger(log)

	// ============================================
	// 2. Create manager
	// ============================================
	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		Scheme:                 runtime.NewScheme(),
		Metrics:                server.Options{BindAddress: ":8080"},
		HealthProbeBindAddress: ":8081",
		// Leader election: only one replica runs the reconcile loop
		LeaderElection:          true,
		LeaderElectionID:        "llmcluster-operator",
		LeaderElectionNamespace: "default",
	})
	if err != nil {
		log.Error(err, "unable to start manager")
		os.Exit(1)
	}

	// ============================================
	// 3. Setup scheme with CRD types
	// ============================================
	if err := servingv1alpha1.AddToScheme(mgr.GetScheme()); err != nil {
		log.Error(err, "unable to add scheme")
		os.Exit(1)
	}

	// ============================================
	// 4. Create reconciler
	// ============================================
	reconciler := &LLMClusterReconciler{
		Client:   mgr.GetClient(),
		Scheme:   mgr.GetScheme(),
		Recorder: mgr.GetEventRecorderFor("llmcluster-operator"),
	}

	if err := reconciler.SetupWithManager(mgr); err != nil {
		log.Error(err, "unable to create controller")
		os.Exit(1)
	}

	// ============================================
	// 5. Add health checks
	// ============================================
	if err := mgr.AddHealthzCheck("healthz", healthz.Ping); err != nil {
		log.Error(err, "unable to set up health check")
		os.Exit(1)
	}

	if err := mgr.AddReadyzCheck("readyz", healthz.Ping); err != nil {
		log.Error(err, "unable to set up ready check")
		os.Exit(1)
	}

	// ============================================
	// 6. Start manager
	// ============================================
	log.Info("starting manager")
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		log.Error(err, "problem running manager")
		os.Exit(1)
	}
}
