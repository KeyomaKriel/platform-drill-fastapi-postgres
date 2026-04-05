## Bash / Linux quick cheat sheet

### Edit a file in a terminal editor

**nano**
```bash
nano path/to/file.yaml

Useful keys:
	•	Ctrl+O save
	•	Enter confirm filename
	•	Ctrl+X exit
	•	Ctrl+K cut line
	•	Ctrl+U paste line
	•	Ctrl+W search

vim

vim path/to/file.yaml

Useful keys:
	•	i enter insert mode
	•	Esc leave insert mode
	•	:w save
	•	:q quit
	•	:wq save and quit
	•	:q! quit without saving
	•	/text search
	•	n next match

force kubectl edit to use nano

KUBE_EDITOR=nano kubectl edit svc platform-drill-api -n drill

or:

export KUBE_EDITOR=nano
kubectl edit deployment my-app -n drill


⸻

View a markdown file in VS Code preview

Open the file in VS Code:

code playbook.md

Open markdown preview:

code -r playbook.md

Inside VS Code:
	•	Cmd+Shift+V open Markdown preview
	•	Cmd+K V open preview to the side

If using Linux proper instead of Mac:
	•	Ctrl+Shift+V
	•	Ctrl+K V

⸻

Show current repo structure

basic

pwd
ls
ls -la

recursive with find

find .

better: only a few levels deep

find . -maxdepth 3 | sort

files only

find . -maxdepth 3 -type f | sort

directories only

find . -maxdepth 3 -type d | sort

tree if installed

tree
tree -L 2
tree -L 3

If tree is not installed on Linux:

sudo apt-get install tree

On Mac with Homebrew:

brew install tree


⸻

Search for a file or text in the repo

find file by name

find . -name "app.yaml"
find . -iname "*service*"

search text with grep

grep -R "platform-drill-api" .
grep -R "namespace: drill" .

better search with ripgrep

rg "platform-drill-api"
rg "namespace:\s*drill"
rg "kind:\s*Service"


⸻

Print part of a file

show whole file

cat path/to/file.yaml

page through file

less path/to/file.yaml

Useful in less:
	•	q quit
	•	/text search
	•	n next match

show line numbers

nl -ba path/to/file.yaml | less

show specific lines

sed -n '1,80p' path/to/file.yaml
sed -n '42,70p' k8s/app.yaml


⸻

Check current directory and git repo status

pwd
git status
git branch
git rev-parse --show-toplevel


⸻

Useful kubectl file/edit workflow

Inspect live object:

kubectl get svc platform-drill-api -n drill -o yaml

Edit live object:

KUBE_EDITOR=nano kubectl edit svc platform-drill-api -n drill

Export live object to a file:

kubectl get svc platform-drill-api -n drill -o yaml > svc-drill.yaml

Apply a file:

kubectl apply -f k8s/app.yaml

Diff before apply:

kubectl diff -f k8s/app.yaml


⸻

Minimal practical set to remember

nano file.yaml
vim file.yaml
find . -maxdepth 3 | sort
find . -name "app.yaml"
rg "platform-drill-api"
sed -n '42,70p' k8s/app.yaml
code playbook.md

Here is the same thing without the markdown fence so you can paste it straight into a file if needed.

## Bash / Linux quick cheat sheet

### Edit a file in a terminal editor

**nano**
```bash
nano path/to/file.yaml

Useful keys:
	•	Ctrl+O save
	•	Enter confirm filename
	•	Ctrl+X exit
	•	Ctrl+K cut line
	•	Ctrl+U paste line
	•	Ctrl+W search

vim

vim path/to/file.yaml

Useful keys:
	•	i enter insert mode
	•	Esc leave insert mode
	•	:w save
	•	:q quit
	•	:wq save and quit
	•	:q! quit without saving
	•	/text search
	•	n next match

force kubectl edit to use nano

KUBE_EDITOR=nano kubectl edit svc platform-drill-api -n drill

View a markdown file in VS Code preview

Open the file in VS Code:

code playbook.md

Inside VS Code:
	•	Cmd+Shift+V open Markdown preview
	•	Cmd+K V open preview to the side

Show current repo structure

pwd
ls -la
find . -maxdepth 3 | sort
find . -maxdepth 3 -type f | sort
find . -maxdepth 3 -type d | sort
tree -L 3

Search for a file or text in the repo

find . -name "app.yaml"
grep -R "platform-drill-api" .
rg "platform-drill-api"
rg "namespace:\s*drill"
rg "kind:\s*Service"

Print part of a file

cat path/to/file.yaml
less path/to/file.yaml
nl -ba path/to/file.yaml | less
sed -n '42,70p' k8s/app.yaml

Check current directory and git repo status

pwd
git status
git branch
git rev-parse --show-toplevel

Useful kubectl file/edit workflow

kubectl get svc platform-drill-api -n drill -o yaml
KUBE_EDITOR=nano kubectl edit svc platform-drill-api -n drill
kubectl get svc platform-drill-api -n drill -o yaml > svc-drill.yaml
kubectl apply -f k8s/app.yaml
kubectl diff -f k8s/app.yaml

If you want, I can turn this into a tighter interview-focused cheat sheet with only the 15 commands you’re most likely to actually use.