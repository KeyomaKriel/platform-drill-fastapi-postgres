1. Add a new section near the top: “30-second orientation”

Put this just before or just after Default Triage Loop.

<section id="orientation">
  <h2>30-Second Orientation</h2>
  <div class="view-card">
    <h4>Before deep debugging</h4>
    <div class="flow">Find the namespace, entry path, app port, and config source before guessing.</div>
    <pre>kubectl config current-context
kubectl config get-contexts
kubectl config use-context &lt;context-name&gt;
kubectl config view --minify
kubectl get ns
kubectl config set-context --current --namespace=&lt;ns&gt;
kubectl get all -A
kubectl get ingress -A
kubectl get svc -A
kubectl get deploy -A</pre>
    <ul>
      <li>Confirm you are in the right cluster/context</li>
      <li>Find the namespace that actually contains the app</li>
      <li>Find whether entry is Ingress, LoadBalancer Service, or internal Service</li>
      <li>Find the Deployment, Service, and likely app port</li>
      <li>In the repo, find whether config comes from raw YAML, Helm values, or Kustomize overlays</li>
    </ul>
  </div>
</section>

2. Add a new caution card: namespace/context trap

Add this under Do Not Over-Infer.

<div class="caution-item">Wrong context or namespace can make a healthy app look missing</div>

3. Add a new high-likelihood symptom card: wrong namespace / wrong context

This should be in High Likelihood, because it is cheap and interview-realistic.

<div class="symptom-card">
  <div class="symptom-header sh-neutral" onclick="this.parentElement.classList.toggle('open')">
    <span class="chevron">&#9654;</span>
    <h4>Nothing looks right / expected objects seem missing</h4>
    <span class="bucket-tag" style="background:#f5f5f5;color:#666;border:1px solid #ccc;">Sanity check first</span>
  </div>
  <div class="symptom-body">
    <pre>kubectl config current-context
kubectl get ns
kubectl get all -A | head -n 80
kubectl get deploy,svc,ingress -A | grep -i &lt;app-name&gt;</pre>
    <div class="prove">whether you're looking at the wrong cluster or wrong namespace rather than a broken workload.</div>
    <div class="say-block">Before I assume the app is broken, I want to prove I'm in the right context and namespace and that I'm looking at the right objects.</div>
    <h5>Then check:</h5>
    <ul>
      <li>wrong namespace → switch commands to the namespace that actually contains the app</li>
      <li>wrong cluster/context → fix kube context before continuing</li>
      <li>object name assumption wrong → search actual deploy/service/ingress names first</li>
    </ul>
  </div>
</div>

4. Add a new moderate-likelihood symptom card: image is valid but wrong version

You already cover image pull failure. You need the case where the image runs fine but is not the intended one. Your current sheet does not make that explicit.

<div class="symptom-card">
  <div class="symptom-header sh-start" onclick="this.parentElement.classList.toggle('open')">
    <span class="chevron">&#9654;</span>
    <h4>App runs, but behaviour does not match the expected version</h4>
    <span class="bucket-tag tag-start">Start</span>
  </div>
  <div class="symptom-body">
    <pre>kubectl get deploy &lt;deploy&gt; -n &lt;ns&gt; -o jsonpath='{.spec.template.spec.containers[0].image}'
kubectl describe pod &lt;pod&gt; -n &lt;ns&gt;
kubectl logs &lt;pod&gt; -n &lt;ns&gt; | head</pre>
    <div class="prove">whether the workload is running the wrong image or stale tag even though the pod starts successfully.</div>
    <div class="say-block">The pod is healthy, but I want to confirm we're actually running the intended image and not an older or wrong tag.</div>
    <h5>Then check:</h5>
    <ul>
      <li>wrong tag pinned in Deployment → fix image tag</li>
      <li>mutable tag ambiguity like <code>latest</code> → use explicit version tag</li>
      <li>expected code path missing → image built from wrong commit or wrong Dockerfile context</li>
    </ul>
  </div>
</div>

5. Add a new moderate-likelihood symptom card: app binds only to localhost

This is a real one and maps directly to your traffic bucket.

<div class="symptom-card">
  <div class="symptom-header sh-traffic" onclick="this.parentElement.classList.toggle('open')">
    <span class="chevron">&#9654;</span>
    <h4>Pod is Running, but app only works from inside the container</h4>
    <span class="bucket-tag tag-traffic">Receive Traffic</span>
  </div>
  <div class="symptom-body">
    <pre>kubectl port-forward pod/&lt;pod&gt; 8080:&lt;container-port&gt; -n &lt;ns&gt;
curl localhost:8080/&lt;path&gt;
kubectl logs &lt;pod&gt; -n &lt;ns&gt;</pre>
    <div class="prove">whether the app itself serves locally but is bound incorrectly for Kubernetes traffic.</div>
    <div class="say-block">If the app works only from inside the container or only via local loopback, it may be listening on 127.0.0.1 instead of 0.0.0.0.</div>
    <h5>Then check:</h5>
    <ul>
      <li>app bound to 127.0.0.1 / localhost → change bind address to <code>0.0.0.0</code></li>
      <li>containerPort documented wrong → align manifest with actual listening port</li>
      <li>probe hits a port/path the app is not really serving → fix probe and/or app config</li>
    </ul>
  </div>
</div>

6. Add a new fix section: wrong bind address / listen interface

<div class="fix-card" id="fix-bind-address">
  <div class="fix-header" onclick="this.parentElement.classList.toggle('open')">
    <span class="chevron">&#9654;</span>
    <h3>Fix: App bound to localhost / wrong listen interface</h3>
  </div>
  <div class="fix-body">
    <div class="fix-means">The process is listening only on 127.0.0.1 inside the container, so Kubernetes traffic from the pod network cannot reach it properly.</div>
    <h4>First commands</h4>
    <pre>kubectl port-forward pod/&lt;pod&gt; 8080:&lt;container-port&gt; -n &lt;ns&gt;
curl localhost:8080/&lt;path&gt;
kubectl logs &lt;pod&gt; -n &lt;ns&gt;</pre>
    <h4>Likely fixes</h4>
    <ul>
      <li>App configured with localhost / 127.0.0.1 bind → change to <code>0.0.0.0</code></li>
      <li>Framework default bind assumption wrong → set host explicitly in app config or startup command</li>
      <li>Manifest containerPort correct but app not listening there → fix app startup config</li>
    </ul>
    <h4>Verification</h4>
    <pre>kubectl get pods -n &lt;ns&gt;
kubectl get endpoints &lt;service&gt; -n &lt;ns&gt;
kubectl port-forward svc/&lt;service&gt; 8080:&lt;service-port&gt; -n &lt;ns&gt;
curl localhost:8080/&lt;path&gt;</pre>
  </div>
</div>

7. Strengthen your traffic bucket with pod port-forward

Your current sheet does Service port-forwarding, which is good, but it should also explicitly tell you when to use pod port-forwarding to isolate app-vs-service break.  ￼

Replace this block in Receive Traffic:

<pre>kubectl get svc -n &lt;ns&gt;
kubectl describe svc &lt;service&gt; -n &lt;ns&gt;
kubectl get endpoints &lt;service&gt; -n &lt;ns&gt;
kubectl port-forward svc/&lt;service&gt; 8080:&lt;service-port&gt; -n &lt;ns&gt;
# then: curl localhost:8080/&lt;path&gt;</pre>

with this:

<pre>kubectl get svc -n &lt;ns&gt;
kubectl describe svc &lt;service&gt; -n &lt;ns&gt;
kubectl get endpoints &lt;service&gt; -n &lt;ns&gt;

# isolate app first
kubectl port-forward pod/&lt;pod&gt; 8080:&lt;container-port&gt; -n &lt;ns&gt;
# then: curl localhost:8080/&lt;path&gt;

# then isolate service routing
kubectl port-forward svc/&lt;service&gt; 8080:&lt;service-port&gt; -n &lt;ns&gt;
# then: curl localhost:8080/&lt;path&gt;</pre>

Then add this bullet:

<li><strong>Pod port-forward works but Service port-forward fails</strong> &rarr; Service selector / targetPort / endpoints problem</li>
<li><strong>Neither pod nor Service port-forward works</strong> &rarr; app itself is not serving, wrong port, wrong path, or wrong bind address</li>

8. Add a new fix section: config changed but pods did not pick it up

Your sheet mentions restarting after ConfigMap/Secret changes, but this deserves its own explicit fix because it is a classic practical trap.  ￼

<div class="fix-card" id="fix-rollout-restart">
  <div class="fix-header" onclick="this.parentElement.classList.toggle('open')">
    <span class="chevron">&#9654;</span>
    <h3>Fix: Config changed but running pods did not pick it up</h3>
  </div>
  <div class="fix-body">
    <div class="fix-means">The ConfigMap or Secret has been corrected, but the running pods are still using old environment values because they were not restarted.</div>
    <h4>First commands</h4>
    <pre>kubectl get configmap &lt;cm&gt; -n &lt;ns&gt; -o yaml
kubectl get secret &lt;secret&gt; -n &lt;ns&gt; -o yaml
kubectl exec -it &lt;pod&gt; -n &lt;ns&gt; -- env | grep &lt;VAR&gt;</pre>
    <h4>Likely fixes</h4>
    <ul>
      <li>ConfigMap/Secret data is fixed but env vars in pod are still old → rollout restart the Deployment</li>
      <li>Mounted file updates not reflected by the app → restart app/pod if the app does not hot-reload</li>
    </ul>
    <h4>Fix commands</h4>
    <pre>kubectl rollout restart deploy/&lt;deploy&gt; -n &lt;ns&gt;
kubectl rollout status deploy/&lt;deploy&gt; -n &lt;ns&gt;</pre>
    <h4>Verification</h4>
    <pre>kubectl exec -it &lt;new-pod&gt; -n &lt;ns&gt; -- env | grep &lt;VAR&gt;
kubectl logs &lt;new-pod&gt; -n &lt;ns&gt;</pre>
  </div>
</div>

9. Add a new moderate-likelihood symptom card: multi-container pod / wrong logs

<div class="symptom-card">
  <div class="symptom-header sh-stayup" onclick="this.parentElement.classList.toggle('open')">
    <span class="chevron">&#9654;</span>
    <h4>Logs are confusing or empty in a multi-container pod</h4>
    <span class="bucket-tag tag-stayup">Stay Up</span>
  </div>
  <div class="symptom-body">
    <pre>kubectl describe pod &lt;pod&gt; -n &lt;ns&gt;
kubectl logs &lt;pod&gt; -n &lt;ns&gt; -c &lt;container-name&gt;
kubectl logs &lt;pod&gt; -n &lt;ns&gt; -c &lt;container-name&gt; --previous</pre>
    <div class="prove">whether you're reading logs from the actual failing container.</div>
    <div class="say-block">This pod has multiple containers, so I want to make sure I'm reading logs from the right one before drawing conclusions.</div>
    <h5>Then check:</h5>
    <ul>
      <li>sidecar logs fine but app container failing → use <code>-c</code> for the app container</li>
      <li>init container was the failing one → inspect init container logs separately</li>
    </ul>
  </div>
</div>

10. Add a new repo/config-source support view: Helm / Kustomize drift

This is only worth adding if the repo might use them. Still, it is a very useful reminder.

<section id="config-source">
  <h2>Config Source View</h2>
  <div class="views-grid">
    <div class="view-card">
      <h4>When the repo uses Helm or Kustomize</h4>
      <div class="flow">Bug may be in values / overlay, not in the rendered object you first inspect.</div>
      <pre># Helm clues
ls
find . -maxdepth 3 | grep -E 'Chart.yaml|values.*yaml'

# Kustomize clues
find . -maxdepth 4 | grep -E 'kustomization.yaml|kustomization.yml'</pre>
      <ul>
        <li>Wrong image tag may come from values.yaml, not the Deployment YAML</li>
        <li>Wrong env var may come from overlay patch, not the base manifest</li>
        <li>Wrong replica count or ingress host may be environment-specific drift</li>
      </ul>
    </div>
  </div>
</section>

11. Add one interview phrase

In your Say section, add this:

<div class="phrase">I want to separate app-level failure from Kubernetes routing failure, so I'll test the pod directly first, then the Service, then ingress if needed.</div>

12. Small nav updates

Add these to the top nav:

<a href="#orientation">Orient</a>
<a href="#config-source">Config Source</a>