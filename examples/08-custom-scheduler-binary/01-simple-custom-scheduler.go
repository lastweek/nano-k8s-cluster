// Simple Custom Kubernetes Scheduler
//
// This is a minimal but functional custom scheduler written in Go.
// It demonstrates the core concepts of writing your own scheduler.
//
// What this scheduler does:
// 1. Watches the Kubernetes API for unscheduled pods
// 2. Filters nodes based on GPU requirements
// 3. Scores nodes based on available resources
// 4. Binds pods to the best node
//
// Architecture:
//
// ┌─────────────────────────────────────────────────────────────┐
// │  Main Loop                                                   │
// │  ┌───────────────────────────────────────────────────────┐ │
// │  │ 1. Start informer (watch pods)                        │ │
// │  │ 2. For each unscheduled pod:                         │ │
// │  │    a. Filter feasible nodes                          │ │
// │  │    b. Score nodes                                    │ │
// │  │    c. Select best node                               │ │
// │  │    d. Bind pod to node                               │ │
// │  └───────────────────────────────────────────────────────┘ │
// └─────────────────────────────────────────────────────────────┘

package main

import (
	"context"
	"fmt"
	"log"
	"math"
	"os"
	"time"

	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/informers"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/tools/clientcmd"
)

// Scheduler is the main scheduler struct
type Scheduler struct {
	clientset *kubernetes.Clientset
	schedulerName string
}

// NewScheduler creates a new scheduler
func NewScheduler(clientset *kubernetes.Clientset, schedulerName string) *Scheduler {
	return &Scheduler{
		clientset:     clientset,
		schedulerName: schedulerName,
	}
}

// Run starts the scheduler
func (s *Scheduler) Run(ctx context.Context) error {
	log.Printf("🚀 Starting custom scheduler: %s", s.schedulerName)

	// Create informer factory (resync every 10 minutes)
	factory := informers.NewSharedInformerFactory(s.clientset, 10*time.Minute)

	// Create pod informer
	podInformer := factory.Core().V1().Pods().Informer()

	// Add event handler for pod changes
	podInformer.AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			pod := obj.(*v1.Pod)
			s.schedulePod(pod)
		},
		UpdateFunc: func(oldObj, newObj interface{}) {
			pod := newObj.(*v1.Pod)
			s.schedulePod(pod)
		},
	})

	// Start informers
	factory.Start(ctx.Done())

	// Wait for cache sync
	factory.WaitForCacheSync(ctx.Done())
	log.Println("✓ Informer cache synced")

	// Keep running until context is cancelled
	<-ctx.Done()
	log.Println("Scheduler stopped")
	return nil
}

// schedulePod schedules a single pod
func (s *Scheduler) schedulePod(pod *v1.Pod) {
	// Skip if:
	// - Pod is already scheduled
	// - Pod is being deleted
	// - Pod is not for this scheduler
	if pod.Spec.NodeName != "" || pod.DeletionTimestamp != nil {
		return
	}

	if pod.Spec.SchedulerName != s.schedulerName {
		return
	}

	log.Printf("📋 Scheduling pod: %s/%s", pod.Namespace, pod.Name)

	// Get all nodes
	nodes, err := s.clientset.CoreV1().Nodes().List(context.TODO(), metav1.ListOptions{})
	if err != nil {
		log.Printf("Error listing nodes: %v", err)
		return
	}

	// Phase 1: Filter nodes
	feasibleNodes := s.filterNodes(pod, nodes.Items)
	if len(feasibleNodes) == 0 {
		log.Printf("⚠ No feasible nodes for pod %s/%s", pod.Namespace, pod.Name)
		return
	}
	log.Printf("  Feasible nodes: %d", len(feasibleNodes))

	// Phase 2: Score nodes
	nodeScores := s.scoreNodes(pod, feasibleNodes)
	bestNode := s.selectBestNode(nodeScores)

	// Phase 3: Bind pod to node
	err = s.bindPod(pod, bestNode)
	if err != nil {
		log.Printf("❌ Error binding pod: %v", err)
		return
	}

	log.Printf("✓ Scheduled %s/%s to %s", pod.Namespace, pod.Name, bestNode.Name)
}

// filterNodes filters nodes based on hard constraints
func (s *Scheduler) filterNodes(pod *v1.Pod, nodes []v1.Node) []v1.Node {
	var feasible []v1.Node

	for _, node := range nodes {
		// Check 1: Node is ready
		if !isNodeReady(node) {
			continue
		}

		// Check 2: Enough CPU
		if !hasEnoughCPU(node, pod) {
			continue
		}

		// Check 3: Enough memory
		if !hasEnoughMemory(node, pod) {
			continue
		}

		// Check 4: Enough GPU (if requested)
		if !hasEnoughGPU(node, pod) {
			continue
		}

		// Check 5: Tolerates taints
		if !toleratesTaints(node, pod) {
			continue
		}

		// Check 6: Matches node selector
		if !matchesNodeSelector(node, pod) {
			continue
		}

		feasible = append(feasible, node)
	}

	return feasible
}

// scoreNodes scores nodes based on preferences
func (s *Scheduler) scoreNodes(pod *v1.Pod, nodes []v1.Node) map[string]int64 {
	scores := make(map[string]int64)

	for _, node := range nodes {
		score := int64(0)

		// Score 1: CPU utilization (prefer less utilized)
		score += scoreCPUUtilization(node, pod) * 10

		// Score 2: Memory utilization (prefer less utilized)
		score += scoreMemoryUtilization(node, pod) * 10

		// Score 3: GPU utilization (prefer less utilized)
		score += scoreGPUUtilization(node, pod) * 20

		// Score 4: Zone locality (prefer same zone)
		score += scoreZoneLocality(node, pod) * 5

		scores[node.Name] = score
	}

	return scores
}

// selectBestNode selects the node with the highest score
func (s *Scheduler) selectBestNode(scores map[string]int64) v1.Node {
	var bestNode v1.Node
	var bestScore int64 = -1

	for nodeName, score := range scores {
		if score > bestScore {
			bestScore = score
			node, err := s.clientset.CoreV1().Nodes().Get(context.TODO(), nodeName, metav1.GetOptions{})
			if err == nil {
				bestNode = *node
			}
		}
	}

	return bestNode
}

// bindPod binds a pod to a node
func (s *Scheduler) bindPod(pod *v1.Pod, node v1.Node) error {
	binding := &v1.Binding{
		ObjectMeta: metav1.ObjectMeta{Name: pod.Name, UID: pod.UID},
		Target:     v1.ObjectReference{Kind: "Node", Name: node.Name},
	}

	_, err := s.clientset.CoreV1().Pods(pod.Namespace).Bind(context.TODO(), binding, metav1.CreateOptions{})
	return err
}

// Helper functions

func isNodeReady(node v1.Node) bool {
	for _, condition := range node.Status.Conditions {
		if condition.Type == v1.NodeReady {
			return condition.Status == v1.ConditionTrue
		}
	}
	return false
}

func hasEnoughCPU(node v1.Node, pod *v1.Pod) bool {
	podCPU := pod.Spec.Containers[0].Resources.Requests.Cpu()
	nodeAllocatableCPU := node.Status.Allocatable[v1.ResourceCPU]
	return podCPU.Cmp(*nodeAllocatableCPU) <= 0
}

func hasEnoughMemory(node v1.Node, pod *v1.Pod) bool {
	podMem := pod.Spec.Containers[0].Resources.Requests.Memory()
	nodeAllocatableMem := node.Status.Allocatable[v1.ResourceMemory]
	return podMem.Cmp(*nodeAllocatableMem) <= 0
}

func hasEnoughGPU(node v1.Node, pod *v1.Pod) bool {
	podGPU := pod.Spec.Containers[0].Resources.Requests["nvidia.com/gpu"]
	if podGPU.IsZero() {
		return true // No GPU required
	}
	nodeGPU := node.Status.Capacity["nvidia.com/gpu"]
	return podGPU.Cmp(*nodeGPU) <= 0
}

func toleratesTaints(node v1.Node, pod *v1.Pod) bool {
	for _, taint := range node.Spec.Taints {
		tolerated := false
		for _, toleration := range pod.Spec.Tolerations {
			if toleration.MatchTaint(&taint) {
				tolerated = true
				break
			}
		}
		if !tolerated && taint.Effect == v1.TaintEffectNoSchedule {
			return false
		}
	}
	return true
}

func matchesNodeSelector(node v1.Node, pod *v1.Pod) bool {
	if pod.Spec.NodeSelector == nil {
		return true
	}
	for key, value := range pod.Spec.NodeSelector {
		if node.Labels[key] != value {
			return false
		}
	}
	return true
}

func scoreCPUUtilization(node v1.Node, pod *v1.Pod) int64 {
	// Simplified: use allocatable as proxy for available
	// In production, query actual utilization via metrics API
	nodeCPU := node.Status.Allocatable[v1.ResourceCPU]
	return int64(nodeCPU.MilliValue())
}

func scoreMemoryUtilization(node v1.Node, pod *v1.Pod) int64 {
	nodeMem := node.Status.Allocatable[v1.ResourceMemory]
	return int64(nodeMem.Value() / (1024 * 1024 * 1024)) // Convert to GB
}

func scoreGPUUtilization(node v1.Node, pod *v1.Pod) int64 {
	nodeGPU := node.Status.Allocatable["nvidia.com/gpu"]
	if nodeGPU.IsZero() {
		return 0
	}
	// Prefer nodes with more available GPUs
	return nodeGPU.Value()
}

func scoreZoneLocality(node v1.Node, pod *v1.Pod) int64 {
	// If pod specifies zone preference
	podZone := pod.Spec.NodeSelector["topology.kubernetes.io/zone"]
	if podZone == "" {
		return 0
	}
	nodeZone := node.Labels["topology.kubernetes.io/zone"]
	if nodeZone == podZone {
		return 100
	}
	return 0
}

func main() {
	// Get scheduler name from env or default
	schedulerName := os.Getenv("SCHEDULER_NAME")
	if schedulerName == "" {
		schedulerName = "simple-custom-scheduler"
	}

	// Create Kubernetes client
	config, err := rest.InClusterConfig()
	if err != nil {
		// Fall back to kubeconfig
		kubeconfig := os.Getenv("KUBECONFIG")
		if kubeconfig == "" {
			kubeconfig = clientcmd.RecommendedHomeFile
		}
		config, err = clientcmd.BuildConfigFromFlags("", kubeconfig)
		if err != nil {
			log.Fatalf("Error building kubeconfig: %v", err)
		}
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Error creating clientset: %v", err)
	}

	// Create and run scheduler
	scheduler := NewScheduler(clientset, schedulerName)

	ctx := context.Background()
	if err := scheduler.Run(ctx); err != nil {
		log.Fatalf("Error running scheduler: %v", err)
	}
}

/*
 * How This Scheduler Works:
 *
 * ┌─────────────────────────────────────────────────────────────┐
 * │  1. Watch for Pods                                          │
 * │  ┌───────────────────────────────────────────────────────┐ │
 * │  │ Uses informer to watch pod events (add/update)        │ │
 * │  │ Filters for:                                          │ │
 * │  │   - spec.nodeName == "" (unscheduled)                │ │
 * │  │   - spec.schedulerName == "simple-custom-scheduler"   │ │
 * │  └───────────────────────────────────────────────────────┘ │
 * └─────────────────────────────────────────────────────────────┘
 *                           │
 *                           ▼
 * ┌─────────────────────────────────────────────────────────────┐
 * │  2. Filter Nodes                                            │
 * │  ┌───────────────────────────────────────────────────────┐ │
 * │  │ For each node, check:                                  │ │
 * │  │   ✓ Is node ready?                                    │ │
 * │  │   ✓ Enough CPU?                                       │ │
 * │  │   ✓ Enough memory?                                    │ │
 * │  │   ✓ Enough GPU (if requested)?                        │ │
 * │  │   ✓ Can pod tolerate taints?                          │ │
 * │  │   ✓ Does node match nodeSelector?                     │ │
 * │  │                                                        │ │
 * │  │ Result: List of feasible nodes                        │ │
 * │  └───────────────────────────────────────────────────────┘ │
 * └─────────────────────────────────────────────────────────────┘
 *                           │
 *                           ▼
 * ┌─────────────────────────────────────────────────────────────┐
 * │  3. Score Nodes                                             │
 * │  ┌───────────────────────────────────────────────────────┐ │
 * │  │ For each feasible node:                               │ │
 * │  │   score = 0                                           │ │
 * │  │   score += cpu_utilization * 10                       │ │
 * │  │   score += memory_utilization * 10                    │ │
 * │  │   score += gpu_utilization * 20                       │ │
 * │  │   score += zone_locality * 5                          │ │
 * │  │                                                        │ │
 * │  │ Result: Map of node → score                           │ │
 * │  └───────────────────────────────────────────────────────┘ │
 * └─────────────────────────────────────────────────────────────┘
 *                           │
 *                           ▼
 * ┌─────────────────────────────────────────────────────────────┐
 * │  4. Select Best Node                                        │
 * │  ┌───────────────────────────────────────────────────────┐ │
 * │  │ bestNode = node with highest score                    │ │
 * │  └───────────────────────────────────────────────────────┘ │
 * └─────────────────────────────────────────────────────────────┘
 *                           │
 *                           ▼
 * ┌─────────────────────────────────────────────────────────────┐
 * │  5. Bind Pod to Node                                        │
 * │  ┌───────────────────────────────────────────────────────┐ │
 * │  │ POST /api/v1/namespaces/{ns}/pods/{pod}/binding       │ │
 * │  │ { target: { nodeName: bestNode } }                    │ │
 * │  └───────────────────────────────────────────────────────┘ │
 * └─────────────────────────────────────────────────────────────┘
 *
 * To Build and Run:
 *
 * # Local development (uses kubeconfig)
 * go run 01-simple-custom-scheduler.go
 *
 * # Build for container
 * GOOS=linux go build -o simple-custom-scheduler 01-simple-custom-scheduler.go
 *
 * # Deploy to Kubernetes
 * kubectl apply -f 03-deploy-custom-scheduler.yaml
 *
 * # Use in your pods
 * spec:
 *   schedulerName: simple-custom-scheduler
 *
 */
