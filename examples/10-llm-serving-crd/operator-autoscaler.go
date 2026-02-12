// LLMCluster Autoscaler Operator
//
// Production usage:
// 1. Build container image from this file.
// 2. Deploy image via 07-operator-deployment.yaml.
// 3. Create LLMClusterAutoscaler objects.
//
// This operator scales by creating/deleting LLMCluster instances
// (fleet scaling) and reconciling router backends.

package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/tools/leaderelection"
	"k8s.io/client-go/tools/leaderelection/resourcelock"
)

const (
	defaultSyncInterval       = 30 * time.Second
	defaultScaleUpCooldown    = 120
	defaultScaleDownCooldown  = 600
	defaultPrometheusAddress  = "http://prometheus:9090"
	defaultRouterBackendPort  = 8000
	defaultDrainDelay         = 30 * time.Second
	annotationLastScaleUp     = "autoscaling.serving.ai/last-scale-up-epoch"
	annotationLastScaleDown   = "autoscaling.serving.ai/last-scale-down-epoch"
	annotationLastAction      = "autoscaling.serving.ai/last-action"
	annotationCurrentInstance = "autoscaling.serving.ai/current-instances"
)

type metricPolicy struct {
	Type      string
	Query     string
	ScaleUp   float64
	ScaleDown float64
}

type autoscalerPolicy struct {
	Namespace string
	Name      string

	PrometheusAddress string
	AppLabel          string
	LabelSelector     string

	MinInstances int
	MaxInstances int

	Metrics []metricPolicy

	TemplateNamePrefix  string
	TemplateLabels      map[string]string
	TemplateAnnotations map[string]string
	TemplateSpec        map[string]interface{}

	RouterName              string
	RouterBackendPort       int
	RouterBackendNamePrefix string

	ScaleUpCooldownSeconds   int
	ScaleDownCooldownSeconds int
}

type scaleDecision struct {
	ScaleUp          bool
	ScaleDown        bool
	Trigger          string
	Reason           string
	MetricsAvailable bool
	Observed         map[string]float64
}

type controller struct {
	dynamicClient dynamic.Interface

	autoscalerGVR schema.GroupVersionResource
	llmclusterGVR schema.GroupVersionResource

	httpClient   *http.Client
	syncInterval time.Duration
	drainDelay   time.Duration
}

func newController(dynamicClient dynamic.Interface, syncInterval, queryTimeout, drainDelay time.Duration) *controller {
	return &controller{
		dynamicClient: dynamicClient,
		autoscalerGVR: schema.GroupVersionResource{
			Group:    "serving.ai",
			Version:  "v1alpha1",
			Resource: "llmclusterautoscalers",
		},
		llmclusterGVR: schema.GroupVersionResource{
			Group:    "serving.ai",
			Version:  "v1alpha1",
			Resource: "llmclusters",
		},
		httpClient: &http.Client{
			Timeout: queryTimeout,
		},
		syncInterval: syncInterval,
		drainDelay:   drainDelay,
	}
}

func (c *controller) run(ctx context.Context) {
	log.Printf("LLMCluster autoscaler loop started (interval=%s)", c.syncInterval)

	// Immediate reconcile on startup.
	c.reconcileAll(ctx)

	ticker := time.NewTicker(c.syncInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Printf("LLMCluster autoscaler loop stopped")
			return
		case <-ticker.C:
			c.reconcileAll(ctx)
		}
	}
}

func (c *controller) reconcileAll(ctx context.Context) {
	list, err := c.dynamicClient.Resource(c.autoscalerGVR).List(ctx, metav1.ListOptions{})
	if err != nil {
		log.Printf("reconcileAll: list autoscalers failed: %v", err)
		return
	}

	for i := range list.Items {
		item := &list.Items[i]
		if err := c.reconcileAutoscaler(ctx, item); err != nil {
			log.Printf("reconcile %s/%s failed: %v", item.GetNamespace(), item.GetName(), err)
		}
	}
}

func (c *controller) reconcileAutoscaler(ctx context.Context, autoscaler *unstructured.Unstructured) error {
	policy, err := parsePolicy(autoscaler)
	if err != nil {
		return fmt.Errorf("parse policy: %w", err)
	}

	instances, err := c.listManagedInstances(ctx, policy.Namespace, policy.LabelSelector, policy.RouterName)
	if err != nil {
		return fmt.Errorf("list managed instances: %w", err)
	}

	decision, err := c.evaluateDecision(ctx, policy)
	if err != nil {
		return fmt.Errorf("evaluate decision: %w", err)
	}

	action := "NoOp"
	actionReason := decision.Reason
	now := time.Now()

	if !decision.MetricsAvailable {
		action = "Blocked"
		if actionReason == "" {
			actionReason = "no metrics returned from Prometheus"
		}
	}

	if decision.MetricsAvailable {
		switch {
		case decision.ScaleUp && len(instances) < policy.MaxInstances:
			if c.scaleCooldownPassed(autoscaler, true, policy.ScaleUpCooldownSeconds, now) {
				newName, createErr := c.createInstance(ctx, policy, autoscaler, instances)
				if createErr != nil {
					action = "Blocked"
					actionReason = fmt.Sprintf("scale-up create failed: %v", createErr)
				} else {
					action = "ScaleUp"
					actionReason = fmt.Sprintf("created %s (%s)", newName, decision.Trigger)
					if err := c.patchAutoscalerAnnotations(ctx, policy.Namespace, policy.Name, map[string]string{
						annotationLastScaleUp: strconv.FormatInt(now.Unix(), 10),
						annotationLastAction:  actionReason,
					}); err != nil {
						log.Printf("warning: patch scale-up annotation failed: %v", err)
					}
				}
			} else {
				action = "NoOp"
				actionReason = "scale-up cooldown active"
			}
		case decision.ScaleDown && len(instances) > policy.MinInstances:
			if c.scaleCooldownPassed(autoscaler, false, policy.ScaleDownCooldownSeconds, now) {
				candidate := newestInstance(instances)
				if candidate == nil {
					action = "NoOp"
					actionReason = "no removable instance found"
					break
				}

				remaining := filterInstances(instances, candidate.GetName())
				if err := c.reconcileRouterBackends(ctx, policy, remaining); err != nil {
					action = "Blocked"
					actionReason = fmt.Sprintf("router detach failed: %v", err)
					break
				}

				time.Sleep(c.drainDelay)

				if err := c.dynamicClient.Resource(c.llmclusterGVR).Namespace(policy.Namespace).Delete(ctx, candidate.GetName(), metav1.DeleteOptions{}); err != nil {
					action = "Blocked"
					actionReason = fmt.Sprintf("scale-down delete failed: %v", err)
					break
				}

				action = "ScaleDown"
				actionReason = fmt.Sprintf("deleted %s", candidate.GetName())
				if err := c.patchAutoscalerAnnotations(ctx, policy.Namespace, policy.Name, map[string]string{
					annotationLastScaleDown: strconv.FormatInt(now.Unix(), 10),
					annotationLastAction:    actionReason,
				}); err != nil {
					log.Printf("warning: patch scale-down annotation failed: %v", err)
				}
			} else {
				action = "NoOp"
				actionReason = "scale-down cooldown active"
			}
		default:
			if actionReason == "" {
				actionReason = "within thresholds or limits"
			}
		}
	}

	instances, err = c.listManagedInstances(ctx, policy.Namespace, policy.LabelSelector, policy.RouterName)
	if err != nil {
		return fmt.Errorf("refresh managed instances: %w", err)
	}

	if err := c.reconcileRouterBackends(ctx, policy, instances); err != nil {
		action = "Blocked"
		actionReason = fmt.Sprintf("router reconcile failed: %v", err)
	}

	if err := c.patchAutoscalerAnnotations(ctx, policy.Namespace, policy.Name, map[string]string{
		annotationCurrentInstance: strconv.Itoa(len(instances)),
	}); err != nil {
		log.Printf("warning: patch current instance annotation failed: %v", err)
	}

	if err := c.updateAutoscalerStatus(ctx, policy, decision, action, actionReason, len(instances)); err != nil {
		log.Printf("warning: update status failed for %s/%s: %v", policy.Namespace, policy.Name, err)
	}

	log.Printf("reconciled %s/%s action=%s instances=%d reason=%s", policy.Namespace, policy.Name, action, len(instances), actionReason)
	return nil
}

func (c *controller) evaluateDecision(ctx context.Context, policy autoscalerPolicy) (scaleDecision, error) {
	decision := scaleDecision{
		ScaleUp:          false,
		ScaleDown:        true,
		MetricsAvailable: true,
		Observed:         make(map[string]float64, len(policy.Metrics)),
		Reason:           "within thresholds",
	}

	for _, metric := range policy.Metrics {
		query := strings.TrimSpace(metric.Query)
		if query == "" {
			query = defaultQuery(metric.Type, policy.AppLabel, policy.Namespace)
		}
		if query == "" {
			return decision, fmt.Errorf("metric %s has empty query and no default available", metric.Type)
		}

		value, found, err := c.queryPrometheus(ctx, policy.PrometheusAddress, query)
		if err != nil {
			decision.MetricsAvailable = false
			decision.ScaleUp = false
			decision.ScaleDown = false
			decision.Reason = fmt.Sprintf("Prometheus query failed for %s: %v", metric.Type, err)
			return decision, nil
		}
		if !found {
			decision.MetricsAvailable = false
			decision.ScaleUp = false
			decision.ScaleDown = false
			decision.Reason = fmt.Sprintf("Prometheus returned no data for %s", metric.Type)
			return decision, nil
		}

		decision.Observed[metric.Type] = value

		if value > metric.ScaleUp {
			decision.ScaleUp = true
			if decision.Trigger == "" {
				decision.Trigger = fmt.Sprintf("%s %.2f > %.2f", metric.Type, value, metric.ScaleUp)
			}
		}
		if !(value < metric.ScaleDown) {
			decision.ScaleDown = false
		}
	}

	if decision.ScaleUp {
		decision.Reason = decision.Trigger
	} else if decision.ScaleDown {
		decision.Reason = "all metrics below scale-down thresholds"
	}

	return decision, nil
}

func (c *controller) queryPrometheus(ctx context.Context, baseURL, query string) (float64, bool, error) {
	base := strings.TrimRight(baseURL, "/")
	endpoint := base + "/api/v1/query"

	reqURL, err := url.Parse(endpoint)
	if err != nil {
		return 0, false, err
	}

	values := reqURL.Query()
	values.Set("query", query)
	reqURL.RawQuery = values.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, reqURL.String(), nil)
	if err != nil {
		return 0, false, err
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return 0, false, err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return 0, false, fmt.Errorf("prometheus status %d", resp.StatusCode)
	}

	var payload struct {
		Status string `json:"status"`
		Error  string `json:"error"`
		Data   struct {
			ResultType string `json:"resultType"`
			Result     []struct {
				Value []interface{} `json:"value"`
			} `json:"result"`
		} `json:"data"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return 0, false, err
	}
	if payload.Status != "success" {
		if payload.Error == "" {
			payload.Error = "unknown prometheus error"
		}
		return 0, false, fmt.Errorf(payload.Error)
	}
	if len(payload.Data.Result) == 0 || len(payload.Data.Result[0].Value) < 2 {
		return 0, false, nil
	}

	raw := payload.Data.Result[0].Value[1]
	switch v := raw.(type) {
	case string:
		f, err := strconv.ParseFloat(v, 64)
		if err != nil {
			return 0, false, err
		}
		return f, true, nil
	case float64:
		return v, true, nil
	default:
		return 0, false, fmt.Errorf("unexpected prometheus value type %T", raw)
	}
}

func (c *controller) listManagedInstances(ctx context.Context, namespace, selector, routerName string) ([]*unstructured.Unstructured, error) {
	list, err := c.dynamicClient.Resource(c.llmclusterGVR).Namespace(namespace).List(ctx, metav1.ListOptions{
		LabelSelector: selector,
	})
	if err != nil {
		return nil, err
	}

	instances := make([]*unstructured.Unstructured, 0, len(list.Items))
	for i := range list.Items {
		item := &list.Items[i]
		if item.GetDeletionTimestamp() != nil {
			continue
		}
		if routerName != "" && item.GetName() == routerName {
			continue
		}
		clone := item.DeepCopy()
		instances = append(instances, clone)
	}

	sort.Slice(instances, func(i, j int) bool {
		return instances[i].GetCreationTimestamp().Time.Before(instances[j].GetCreationTimestamp().Time)
	})
	return instances, nil
}

func (c *controller) createInstance(
	ctx context.Context,
	policy autoscalerPolicy,
	autoscaler *unstructured.Unstructured,
	existing []*unstructured.Unstructured,
) (string, error) {
	name := nextInstanceName(policy.TemplateNamePrefix, existing)

	labels := map[string]string{}
	for k, v := range policy.TemplateLabels {
		labels[k] = v
	}
	labels["autoscaling.serving.ai/managed-by"] = autoscaler.GetName()
	if policy.AppLabel != "" {
		if _, ok := labels["app"]; !ok {
			labels["app"] = policy.AppLabel
		}
	}

	annotations := map[string]string{}
	for k, v := range policy.TemplateAnnotations {
		annotations[k] = v
	}

	specMap := runtime.DeepCopyJSON(policy.TemplateSpec)

	obj := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "serving.ai/v1alpha1",
			"kind":       "LLMCluster",
			"metadata": map[string]interface{}{
				"name":        name,
				"namespace":   policy.Namespace,
				"labels":      stringMapToInterfaceMap(labels),
				"annotations": stringMapToInterfaceMap(annotations),
			},
			"spec": specMap,
		},
	}

	if _, err := c.dynamicClient.Resource(c.llmclusterGVR).Namespace(policy.Namespace).Create(ctx, obj, metav1.CreateOptions{}); err != nil {
		return "", err
	}
	return name, nil
}

func (c *controller) reconcileRouterBackends(ctx context.Context, policy autoscalerPolicy, instances []*unstructured.Unstructured) error {
	if strings.TrimSpace(policy.RouterName) == "" {
		return nil
	}

	router, err := c.dynamicClient.Resource(c.llmclusterGVR).Namespace(policy.Namespace).Get(ctx, policy.RouterName, metav1.GetOptions{})
	if err != nil {
		return err
	}

	backends := make([]interface{}, 0, len(instances))
	for _, instance := range instances {
		instanceName := instance.GetName()
		backendName := instanceName
		if prefix := policy.RouterBackendNamePrefix; prefix != "" && strings.HasPrefix(instanceName, prefix) {
			backendName = strings.TrimPrefix(instanceName, prefix)
		}

		backends = append(backends, map[string]interface{}{
			"name":    backendName,
			"service": instanceName,
			"port":    int64(policy.RouterBackendPort),
		})
	}

	if err := unstructured.SetNestedSlice(router.Object, backends, "spec", "router", "backends"); err != nil {
		return err
	}

	_, err = c.dynamicClient.Resource(c.llmclusterGVR).Namespace(policy.Namespace).Update(ctx, router, metav1.UpdateOptions{})
	return err
}

func (c *controller) updateAutoscalerStatus(
	ctx context.Context,
	policy autoscalerPolicy,
	decision scaleDecision,
	action string,
	actionReason string,
	currentInstances int,
) error {
	obj, err := c.dynamicClient.Resource(c.autoscalerGVR).Namespace(policy.Namespace).Get(ctx, policy.Name, metav1.GetOptions{})
	if err != nil {
		return err
	}

	now := time.Now().Format(time.RFC3339)

	observedMetrics := map[string]interface{}{}
	for k, v := range decision.Observed {
		observedMetrics[k] = v
	}

	conditions := []interface{}{
		map[string]interface{}{
			"type":               "Ready",
			"status":             "True",
			"lastTransitionTime": now,
			"reason":             "ReconcileComplete",
			"message":            actionReason,
		},
		map[string]interface{}{
			"type":               "MetricsAvailable",
			"status":             boolString(decision.MetricsAvailable),
			"lastTransitionTime": now,
			"reason":             "PrometheusQuery",
			"message":            actionReason,
		},
	}

	status := map[string]interface{}{
		"currentInstances": int64(currentInstances),
		"desiredInstances": int64(currentInstances),
		"lastScaleTime":    now,
		"lastScaleAction":  action,
		"observedMetrics":  observedMetrics,
		"conditions":       conditions,
	}

	if err := unstructured.SetNestedMap(obj.Object, status, "status"); err != nil {
		return err
	}

	_, err = c.dynamicClient.Resource(c.autoscalerGVR).Namespace(policy.Namespace).UpdateStatus(ctx, obj, metav1.UpdateOptions{})
	return err
}

func (c *controller) patchAutoscalerAnnotations(ctx context.Context, namespace, name string, updates map[string]string) error {
	obj, err := c.dynamicClient.Resource(c.autoscalerGVR).Namespace(namespace).Get(ctx, name, metav1.GetOptions{})
	if err != nil {
		return err
	}

	annotations := obj.GetAnnotations()
	if annotations == nil {
		annotations = map[string]string{}
	}
	for k, v := range updates {
		annotations[k] = v
	}
	obj.SetAnnotations(annotations)

	_, err = c.dynamicClient.Resource(c.autoscalerGVR).Namespace(namespace).Update(ctx, obj, metav1.UpdateOptions{})
	return err
}

func (c *controller) scaleCooldownPassed(
	autoscaler *unstructured.Unstructured,
	scaleUp bool,
	cooldownSeconds int,
	now time.Time,
) bool {
	if cooldownSeconds <= 0 {
		return true
	}

	annotations := autoscaler.GetAnnotations()
	if annotations == nil {
		return true
	}

	key := annotationLastScaleDown
	if scaleUp {
		key = annotationLastScaleUp
	}

	value := strings.TrimSpace(annotations[key])
	if value == "" {
		return true
	}

	lastEpoch, err := strconv.ParseInt(value, 10, 64)
	if err != nil {
		return true
	}

	return now.Unix()-lastEpoch >= int64(cooldownSeconds)
}

func parsePolicy(autoscaler *unstructured.Unstructured) (autoscalerPolicy, error) {
	spec, ok, err := unstructured.NestedMap(autoscaler.Object, "spec")
	if err != nil {
		return autoscalerPolicy{}, err
	}
	if !ok {
		return autoscalerPolicy{}, fmt.Errorf("spec is required")
	}

	policy := autoscalerPolicy{
		Namespace:                autoscaler.GetNamespace(),
		Name:                     autoscaler.GetName(),
		PrometheusAddress:        defaultPrometheusAddress,
		RouterBackendPort:        defaultRouterBackendPort,
		ScaleUpCooldownSeconds:   defaultScaleUpCooldown,
		ScaleDownCooldownSeconds: defaultScaleDownCooldown,
		TemplateLabels:           map[string]string{},
		TemplateAnnotations:      map[string]string{},
	}

	if addr, found, _ := unstructured.NestedString(spec, "prometheus", "address"); found && strings.TrimSpace(addr) != "" {
		policy.PrometheusAddress = addr
	}

	if appLabel, found, _ := unstructured.NestedString(spec, "scaleTargetRef", "appLabel"); found {
		policy.AppLabel = appLabel
	}

	if selector, found, _ := unstructured.NestedString(spec, "scaleTargetRef", "labelSelector"); found {
		policy.LabelSelector = selector
	}
	if strings.TrimSpace(policy.LabelSelector) == "" {
		if policy.AppLabel == "" {
			return autoscalerPolicy{}, fmt.Errorf("spec.scaleTargetRef.labelSelector (or appLabel) is required")
		}
		policy.LabelSelector = fmt.Sprintf("app=%s,serving.ai/role=instance", policy.AppLabel)
	}

	if min, found, _ := unstructured.NestedInt64(spec, "minInstances"); found {
		policy.MinInstances = int(min)
	}
	if max, found, _ := unstructured.NestedInt64(spec, "maxInstances"); found {
		policy.MaxInstances = int(max)
	}
	if policy.MinInstances <= 0 || policy.MaxInstances <= 0 {
		return autoscalerPolicy{}, fmt.Errorf("minInstances/maxInstances must be > 0")
	}
	if policy.MinInstances > policy.MaxInstances {
		return autoscalerPolicy{}, fmt.Errorf("minInstances cannot exceed maxInstances")
	}

	metrics, found, err := unstructured.NestedSlice(spec, "metrics")
	if err != nil {
		return autoscalerPolicy{}, err
	}
	if !found || len(metrics) == 0 {
		return autoscalerPolicy{}, fmt.Errorf("spec.metrics must contain at least one metric")
	}

	policy.Metrics = make([]metricPolicy, 0, len(metrics))
	for _, item := range metrics {
		m, ok := item.(map[string]interface{})
		if !ok {
			return autoscalerPolicy{}, fmt.Errorf("invalid metric item")
		}

		metricType := stringValue(m["type"])
		if metricType == "" {
			return autoscalerPolicy{}, fmt.Errorf("metric.type is required")
		}
		query := stringValue(m["query"])

		threshold, ok := m["threshold"].(map[string]interface{})
		if !ok {
			return autoscalerPolicy{}, fmt.Errorf("metric.threshold is required for %s", metricType)
		}

		up, ok := floatValue(threshold["scaleUp"])
		if !ok {
			return autoscalerPolicy{}, fmt.Errorf("metric.threshold.scaleUp is required for %s", metricType)
		}
		down, ok := floatValue(threshold["scaleDown"])
		if !ok {
			return autoscalerPolicy{}, fmt.Errorf("metric.threshold.scaleDown is required for %s", metricType)
		}

		policy.Metrics = append(policy.Metrics, metricPolicy{
			Type:      metricType,
			Query:     query,
			ScaleUp:   up,
			ScaleDown: down,
		})
	}

	if up, found, _ := unstructured.NestedInt64(spec, "behavior", "scaleUpStabilizationSeconds"); found {
		policy.ScaleUpCooldownSeconds = int(up)
	}
	if down, found, _ := unstructured.NestedInt64(spec, "behavior", "scaleDownStabilizationSeconds"); found {
		policy.ScaleDownCooldownSeconds = int(down)
	}

	if name, found, _ := unstructured.NestedString(spec, "routerRef", "name"); found {
		policy.RouterName = strings.TrimSpace(name)
	}
	if port, found, _ := unstructured.NestedInt64(spec, "routerRef", "backendPort"); found {
		policy.RouterBackendPort = int(port)
	}
	if prefix, found, _ := unstructured.NestedString(spec, "routerRef", "backendNamePrefix"); found {
		policy.RouterBackendNamePrefix = prefix
	}

	if prefix, found, _ := unstructured.NestedString(spec, "instanceTemplate", "namePrefix"); found {
		policy.TemplateNamePrefix = prefix
	}
	if strings.TrimSpace(policy.TemplateNamePrefix) == "" {
		if policy.AppLabel != "" {
			policy.TemplateNamePrefix = fmt.Sprintf("%s-instance-", policy.AppLabel)
		} else {
			policy.TemplateNamePrefix = "llmcluster-instance-"
		}
	}
	if strings.TrimSpace(policy.RouterBackendNamePrefix) == "" {
		policy.RouterBackendNamePrefix = policy.TemplateNamePrefix
	}

	if labels, found, _ := unstructured.NestedStringMap(spec, "instanceTemplate", "labels"); found {
		for k, v := range labels {
			policy.TemplateLabels[k] = v
		}
	}
	if annotations, found, _ := unstructured.NestedStringMap(spec, "instanceTemplate", "annotations"); found {
		for k, v := range annotations {
			policy.TemplateAnnotations[k] = v
		}
	}

	if tmplSpec, found, _ := unstructured.NestedMap(spec, "instanceTemplate", "spec"); found && len(tmplSpec) > 0 {
		policy.TemplateSpec = runtime.DeepCopyJSON(tmplSpec)
	} else {
		fallbackSpec := map[string]interface{}{}
		if model, found, _ := unstructured.NestedString(spec, "instanceTemplate", "model"); found {
			fallbackSpec["model"] = model
		}
		if size, found, _ := unstructured.NestedString(spec, "instanceTemplate", "modelSize"); found {
			fallbackSpec["modelSize"] = size
		}
		if replicas, found, _ := unstructured.NestedInt64(spec, "instanceTemplate", "replicas"); found {
			fallbackSpec["replicas"] = replicas
		}
		if gpus, found, _ := unstructured.NestedInt64(spec, "instanceTemplate", "gpusPerPod"); found {
			fallbackSpec["gpusPerPod"] = gpus
		}
		if tp, found, _ := unstructured.NestedInt64(spec, "instanceTemplate", "tensorParallelSize"); found {
			fallbackSpec["tensorParallelSize"] = tp
		}
		if image, found, _ := unstructured.NestedString(spec, "instanceTemplate", "image"); found {
			fallbackSpec["image"] = image
		}
		if len(fallbackSpec) == 0 {
			return autoscalerPolicy{}, fmt.Errorf("instanceTemplate.spec (or flat template fields) is required")
		}
		if _, ok := fallbackSpec["router"]; !ok {
			fallbackSpec["router"] = map[string]interface{}{"enabled": false}
		}
		if _, ok := fallbackSpec["queue"]; !ok {
			fallbackSpec["queue"] = map[string]interface{}{"enabled": false}
		}
		if _, ok := fallbackSpec["inferenceEngine"]; !ok {
			fallbackSpec["inferenceEngine"] = "vllm"
		}
		policy.TemplateSpec = fallbackSpec
	}

	return policy, nil
}

func defaultQuery(metricType, appLabel, namespace string) string {
	switch metricType {
	case "QueueLength":
		if appLabel == "" {
			return ""
		}
		return fmt.Sprintf(`sum(redis_queue_length{app="%s",queue="request_queue"})`, appLabel)
	case "TTFT":
		if appLabel == "" {
			return ""
		}
		return fmt.Sprintf(`histogram_quantile(0.95, sum(rate(llm_ttft_seconds_bucket{app="%s"}[2m])) by (le)) * 1000`, appLabel)
	case "TPOT":
		if appLabel == "" {
			return ""
		}
		return fmt.Sprintf(`histogram_quantile(0.95, sum(rate(llm_tpot_seconds_bucket{app="%s"}[2m])) by (le)) * 1000`, appLabel)
	case "Latency":
		if appLabel == "" {
			return ""
		}
		return fmt.Sprintf(`histogram_quantile(0.95, sum(rate(llm_request_latency_seconds_bucket{app="%s"}[2m])) by (le)) * 1000`, appLabel)
	case "GPUUtilization":
		return fmt.Sprintf(`avg(DCGM_FI_DEV_GPU_UTIL{namespace="%s"})`, namespace)
	default:
		return ""
	}
}

func newestInstance(instances []*unstructured.Unstructured) *unstructured.Unstructured {
	if len(instances) == 0 {
		return nil
	}
	return instances[len(instances)-1]
}

func filterInstances(instances []*unstructured.Unstructured, removeName string) []*unstructured.Unstructured {
	out := make([]*unstructured.Unstructured, 0, len(instances))
	for _, instance := range instances {
		if instance.GetName() == removeName {
			continue
		}
		out = append(out, instance)
	}
	return out
}

func nextInstanceName(prefix string, existing []*unstructured.Unstructured) string {
	maxIndex := 0
	for _, item := range existing {
		name := item.GetName()
		if !strings.HasPrefix(name, prefix) {
			continue
		}
		suffix := strings.TrimPrefix(name, prefix)
		index, err := strconv.Atoi(suffix)
		if err != nil {
			continue
		}
		if index > maxIndex {
			maxIndex = index
		}
	}
	return fmt.Sprintf("%s%02d", prefix, maxIndex+1)
}

func floatValue(v interface{}) (float64, bool) {
	switch value := v.(type) {
	case float64:
		return value, true
	case float32:
		return float64(value), true
	case int:
		return float64(value), true
	case int64:
		return float64(value), true
	case json.Number:
		f, err := value.Float64()
		return f, err == nil
	default:
		return 0, false
	}
}

func stringValue(v interface{}) string {
	if v == nil {
		return ""
	}
	switch value := v.(type) {
	case string:
		return value
	default:
		return fmt.Sprintf("%v", value)
	}
}

func stringMapToInterfaceMap(m map[string]string) map[string]interface{} {
	out := make(map[string]interface{}, len(m))
	for k, v := range m {
		out[k] = v
	}
	return out
}

func boolString(value bool) string {
	if value {
		return "True"
	}
	return "False"
}

func startHealthServer(ctx context.Context, addr string) {
	if strings.TrimSpace(addr) == "" || addr == "0" {
		return
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	mux.HandleFunc("/readyz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})

	server := &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("health server stopped: %v", err)
		}
	}()
}

func startMetricsServer(ctx context.Context, addr string) {
	if strings.TrimSpace(addr) == "" || addr == "0" {
		return
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/metrics", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4")
		_, _ = w.Write([]byte("# llmcluster autoscaler metrics are exported by logging in this example\n"))
	})

	server := &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()

	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Printf("metrics server stopped: %v", err)
		}
	}()
}

func buildRestConfig(kubeconfig string) (*rest.Config, error) {
	if strings.TrimSpace(kubeconfig) != "" {
		return clientcmd.BuildConfigFromFlags("", kubeconfig)
	}

	inCluster, err := rest.InClusterConfig()
	if err == nil {
		return inCluster, nil
	}

	home, homeErr := os.UserHomeDir()
	if homeErr != nil {
		return nil, fmt.Errorf("in-cluster config failed: %v; user home lookup failed: %v", err, homeErr)
	}
	defaultPath := fmt.Sprintf("%s/.kube/config", home)
	return clientcmd.BuildConfigFromFlags("", defaultPath)
}

func main() {
	var (
		kubeconfig              string
		syncInterval            time.Duration
		queryTimeout            time.Duration
		drainDelay              time.Duration
		leaderElect             bool
		leaderElectionID        string
		leaderElectionNamespace string
		healthProbeBindAddress  string
		metricsBindAddress      string
		zapLogLevel             string
	)

	flag.StringVar(&kubeconfig, "kubeconfig", "", "Path to kubeconfig (optional)")
	flag.DurationVar(&syncInterval, "sync-interval", defaultSyncInterval, "Periodic autoscaler reconcile interval")
	flag.DurationVar(&queryTimeout, "prom-query-timeout", 10*time.Second, "Prometheus query timeout")
	flag.DurationVar(&drainDelay, "drain-delay", defaultDrainDelay, "Wait time before deleting scaled-down instances")
	flag.BoolVar(&leaderElect, "leader-elect", true, "Enable leader election")
	flag.StringVar(&leaderElectionID, "leader-election-id", "llmcluster-autoscaler.serving.ai", "Leader election lease name")
	flag.StringVar(&leaderElectionNamespace, "leader-election-namespace", "", "Leader election lease namespace")
	flag.StringVar(&healthProbeBindAddress, "health-probe-bind-address", ":8081", "Health probe bind address")
	flag.StringVar(&metricsBindAddress, "metrics-bind-address", ":8080", "Metrics bind address")
	flag.StringVar(&zapLogLevel, "zap-log-level", "info", "Log level placeholder for deployment compatibility")
	flag.Parse()
	_ = zapLogLevel // Kept for arg compatibility with deployment manifest.

	if strings.TrimSpace(leaderElectionNamespace) == "" {
		leaderElectionNamespace = os.Getenv("POD_NAMESPACE")
		if strings.TrimSpace(leaderElectionNamespace) == "" {
			leaderElectionNamespace = "default"
		}
	}

	restConfig, err := buildRestConfig(kubeconfig)
	if err != nil {
		log.Fatalf("build kube config failed: %v", err)
	}

	dynamicClient, err := dynamic.NewForConfig(restConfig)
	if err != nil {
		log.Fatalf("create dynamic client failed: %v", err)
	}

	kubeClient, err := kubernetes.NewForConfig(restConfig)
	if err != nil {
		log.Fatalf("create kubernetes client failed: %v", err)
	}

	ctrl := newController(dynamicClient, syncInterval, queryTimeout, drainDelay)

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	startHealthServer(ctx, healthProbeBindAddress)
	startMetricsServer(ctx, metricsBindAddress)

	if !leaderElect {
		ctrl.run(ctx)
		return
	}

	identity := os.Getenv("POD_NAME")
	if identity == "" {
		hostname, hostErr := os.Hostname()
		if hostErr != nil {
			identity = fmt.Sprintf("pid-%d", os.Getpid())
		} else {
			identity = hostname
		}
	}

	lock, err := resourcelock.New(
		resourcelock.LeasesResourceLock,
		leaderElectionNamespace,
		leaderElectionID,
		kubeClient.CoreV1(),
		kubeClient.CoordinationV1(),
		resourcelock.ResourceLockConfig{
			Identity: identity,
		},
	)
	if err != nil {
		log.Fatalf("create leader election lock failed: %v", err)
	}

	leaderelection.RunOrDie(ctx, leaderelection.LeaderElectionConfig{
		Lock:            lock,
		LeaseDuration:   15 * time.Second,
		RenewDeadline:   10 * time.Second,
		RetryPeriod:     2 * time.Second,
		ReleaseOnCancel: true,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: func(ctx context.Context) {
				log.Printf("acquired leadership: %s", identity)
				ctrl.run(ctx)
			},
			OnStoppedLeading: func() {
				log.Printf("lost leadership: %s", identity)
				os.Exit(1)
			},
			OnNewLeader: func(newLeader string) {
				if newLeader == identity {
					return
				}
				log.Printf("new leader elected: %s", newLeader)
			},
		},
		Name: "llmcluster-autoscaler",
	})
}
