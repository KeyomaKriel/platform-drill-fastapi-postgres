Option A: Use real open-source tech-test repos in Codespaces

  This is the highest-fidelity option. Several companies publish their Platform/DevOps tech tests as public repos with
  Codespace configs:

  1. Search GitHub for repos like platform-engineer-test, devops-technical-test, k8s-tech-test — many have .devcontainer/
   configs ready to go
  2. Fork one, launch a Codespace, and use Claude Code (in browser or via the Codespace terminal) to act as your
  interviewer/evaluator
  3. You get a genuinely unfamiliar repo + the real Codespace experience

  You could ask me to search for suitable repos if you want.

  Option B: Build a Codespace-ready drill generator

  Modify this drill system so Phase 2 generates a new unfamiliar repo instead of copying source-repo/:

  - Create 3-5 different app templates (different languages, different DB backends, different deploy patterns)
  - Store them in a templates/ directory
  - Phase 2 randomly picks one you haven't seen recently
  - Add a .devcontainer/devcontainer.json so each template works in Codespaces

  This is more work but gives you repeatable unfamiliar drills.

  Option C: Hybrid — Codespace + Claude Code remote interviewer

  1. Create a GitHub repo with a .devcontainer/ that includes kind, kubectl, helm, and docker-in-docker
  2. Put a randomized app in it (or have Claude generate one at drill start)
  3. Launch the Codespace, install Claude Code in the terminal
  4. Claude Code acts as interviewer from inside the Codespace — same Phase 3 evaluation, but in the real environment

  ---
  My recommendation

  Option A is the fastest path to realistic practice before April 7th — oh wait, that date has passed. When is the actual
   interview?

  Regardless, Option A gives you both gaps covered immediately: unfamiliar repo + real Codespace. You just need a
  suitable public repo. Option C is better long-term but requires setup work.

  Want me to search for public Platform Engineer tech-test repos with Codespace support, or help you build a
  .devcontainer config to run this drill system in a Codespace?
