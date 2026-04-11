￼

1. Add it to the new Orientation section

This is where you decide what the entry path even is before deep debugging.

Use this full block in the new #orientation section:

<section id="orientation">
  <h2>30-Second Orientation</h2>
  <div class="view-card">
    <h4>Before deep debugging</h4>
    <div class="flow">Find the cluster/context, namespace, entry path, and config source before guessing.</div>
    <pre>kubectl config current-context
kubectl config get-contexts
kubectl config use-context &lt;context-name&gt;
kubectl config view --minify
kubectl get ns
kubectl config set-context --current --namespace=&lt;ns&gt;

kubectl get ingress -A
kubectl get svc -A
kubectl get deploy -A</pre>
    <ul>
      <li>Confirm you are in the right cluster/context</li>
      <li>Find the namespace that actually contains the app</li>
      <li>If Ingress exists for the app, entry is probably external URL/host/path via Ingress</li>
      <li>If no Ingress, inspect Service type: LoadBalancer / NodePort / ClusterIP</li>
      <li>Use Ingress rules to get host and path</li>
      <li>If no Ingress, use Service external address + port, and get the endpoint path from probes, repo, or app docs</li>
      <li>In the repo, find whether config comes from raw YAML, Helm values, or Kustomize overlays</li>
    </ul>
  </div>
</section>

2. Add it to the Receive Traffic bucket

This is the most important place, because that is where you actually use it during troubleshooting.

Your current Receive Traffic bucket is good, but it needs one small “decide entry path first” note and a stronger command block.  ￼

Replace the current <div class="say">...</div> in 3. Receive Traffic with:

<div class="say">If the pod is Running and Ready, I first decide how traffic is meant to enter: Ingress, LoadBalancer/NodePort Service, or internal ClusterIP Service. Then I test that path layer by layer instead of guessing.</div>

Replace the current <pre> block in 3. Receive Traffic with:

<pre>kubectl get ingress -n &lt;ns&gt;
kubectl describe ingress &lt;ingress&gt; -n &lt;ns&gt;

kubectl get svc -n &lt;ns&gt;
kubectl describe svc &lt;service&gt; -n &lt;ns&gt;
kubectl get endpoints &lt;service&gt; -n &lt;ns&gt;

# isolate app first
kubectl port-forward pod/&lt;pod&gt; 8080:&lt;container-port&gt; -n &lt;ns&gt;
# then: curl localhost:8080/&lt;path&gt;

# isolate service routing
kubectl port-forward svc/&lt;service&gt; 8080:&lt;service-port&gt; -n &lt;ns&gt;
# then: curl localhost:8080/&lt;path&gt;</pre>

Then add these bullets to that bucket’s <ul>:

<li><strong>Ingress exists</strong> &rarr; get host from <code>spec.rules[].host</code> and path from <code>spec.rules[].http.paths[].path</code>, then test with curl and Host header if needed</li>
<li><strong>No Ingress + Service type LoadBalancer</strong> &rarr; use EXTERNAL-IP/DNS + service port as the external entry</li>
<li><strong>No Ingress + Service type NodePort</strong> &rarr; use node IP + nodePort as the external entry</li>
<li><strong>No Ingress + Service type ClusterIP</strong> &rarr; treat it as internal only; use service DNS or port-forward for testing</li>
<li><strong>Pod port-forward works but Service port-forward fails</strong> &rarr; Service selector / targetPort / endpoints problem</li>
<li><strong>Neither pod nor Service port-forward works</strong> &rarr; app itself is not serving, wrong port, wrong path, or wrong bind address</li>
<li><strong>Need actual endpoint path</strong> &rarr; get it from readiness/liveness probe path, repo docs, or app routes &mdash; Kubernetes does not invent the app URL path</li>

3. Add a dedicated support view: “Entry Path View”

This is the cleanest way to encode the logic so you can scan it fast in the interview.

Put this in your Support views area, near #views:

<section id="entry-path-view">
  <h2>Entry Path View</h2>
  <div class="views-grid">
    <div class="view-card">
      <h4>How to determine the app entry path</h4>
      <div class="flow">Ingress? If yes, use host + path. If no, inspect Service type.</div>
      <pre># 1. Is there an Ingress?
kubectl get ingress -n &lt;ns&gt;
kubectl describe ingress &lt;ingress&gt; -n &lt;ns&gt;

# 2. If not, inspect the Service
kubectl get svc -n &lt;ns&gt;
kubectl describe svc &lt;service&gt; -n &lt;ns&gt;</pre>
      <ul>
        <li><strong>Ingress</strong>: use host from Ingress rule and path from Ingress path</li>
        <li><strong>LoadBalancer Service</strong>: use external IP/DNS + service port + app endpoint path</li>
        <li><strong>NodePort Service</strong>: use node IP + nodePort + app endpoint path</li>
        <li><strong>ClusterIP Service</strong>: internal only; use service DNS name or port-forward</li>
        <li><strong>App endpoint path</strong>: get it from probe path, repo docs, curl scripts, or app routes</li>
      </ul>
    </div>

    <div class="view-card">
      <h4>Example curl patterns</h4>
      <div class="flow">Use the object spec to build the exact curl command.</div>
      <pre># Ingress with host rule
curl -H "Host: &lt;host&gt;" http://&lt;ingress-ip&gt;&lt;path&gt;

# Local ingress
curl -H "Host: &lt;host&gt;" http://localhost&lt;path&gt;

# LoadBalancer Service
curl http://&lt;external-ip-or-dns&gt;:&lt;port&gt;&lt;path&gt;

# NodePort Service
curl http://&lt;node-ip&gt;:&lt;nodePort&gt;&lt;path&gt;

# Internal-only ClusterIP Service
kubectl port-forward svc/&lt;service&gt; 8080:&lt;service-port&gt; -n &lt;ns&gt;
curl http://localhost:8080/&lt;path&gt;</pre>
    </div>
  </div>
</section>

4. Add one phrase to the “Say” section

This helps you narrate it cleanly.

Add:

<div class="phrase">I want to identify the entry object first. If there is an Ingress, I’ll use its host and path rules. If there is no Ingress, I’ll inspect the Service type to see whether this is external LoadBalancer/NodePort access or internal ClusterIP routing.</div>

5. Add one nav link

In the top nav, add:

<a href="#entry-path-view">Entry Path</a>

