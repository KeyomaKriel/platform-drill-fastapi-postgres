# Bash / Linux quick cheat sheet

## Edit a file in a terminal editor

### nano
```bash
nano path/to/file.yaml
```

Useful keys:
- `Ctrl+O` save
- `Enter` confirm filename
- `Ctrl+X` exit
- `Ctrl+K` cut line
- `Ctrl+U` paste line
- `Ctrl+W` search

### vim
```bash
vim path/to/file.yaml
```

Useful keys:
- `i` enter insert mode
- `Esc` leave insert mode
- `:w` save
- `:q` quit
- `:wq` save and quit
- `:q!` quit without saving
- `/text` search
- `n` next match

### force `kubectl edit` to use nano
```bash
KUBE_EDITOR=nano kubectl edit svc platform-drill-api -n drill
```

or:

```bash
export KUBE_EDITOR=nano
kubectl edit deployment my-app -n drill
```

## View a markdown file in VS Code preview

Open the file in VS Code:

```bash
code playbook.md
```

Open an already-open file in the current window:

```bash
code -r playbook.md
```

Inside VS Code:
- `Cmd+Shift+V` open Markdown preview
- `Cmd+K V` open preview to the side

## Show current repo structure

### basic
```bash
pwd
ls
ls -la
```

### recursive with find
```bash
find .
```

### better: only a few levels deep
```bash
find . -maxdepth 3 | sort
```

### files only
```bash
find . -maxdepth 3 -type f | sort
```

### directories only
```bash
find . -maxdepth 3 -type d | sort
```

### tree if installed
```bash
tree
tree -L 2
tree -L 3
```

If `tree` is not installed on Linux:

```bash
sudo apt-get install tree
```

On Mac with Homebrew:

```bash
brew install tree
```

## Search for a file or text in the repo

### find file by name
```bash
find . -name "app.yaml"
find . -iname "*service*"
```

### search text with grep
```bash
grep -R "platform-drill-api" .
grep -R "namespace: drill" .
```

### better search with ripgrep
```bash
rg "platform-drill-api"
rg "namespace:\s*drill"
rg "kind:\s*Service"
```

## Print part of a file

### show whole file
```bash
cat path/to/file.yaml
```

### page through file
```bash
less path/to/file.yaml
```

Useful in `less`:
- `q` quit
- `/text` search
- `n` next match

### show line numbers
```bash
nl -ba path/to/file.yaml | less
```

### show specific lines
```bash
sed -n '1,80p' path/to/file.yaml
sed -n '42,70p' k8s/app.yaml
```

## Check current directory and git repo status

```bash
pwd
git status
git branch
git rev-parse --show-toplevel
```

## Useful kubectl file/edit workflow

Inspect live object:

```bash
kubectl get svc platform-drill-api -n drill -o yaml
```

Edit live object:

```bash
KUBE_EDITOR=nano kubectl edit svc platform-drill-api -n drill
```

Export live object to a file:

```bash
kubectl get svc platform-drill-api -n drill -o yaml > svc-drill.yaml
```

Apply a file:

```bash
kubectl apply -f k8s/app.yaml
```

Diff before apply:

```bash
kubectl diff -f k8s/app.yaml
```

## Minimal practical set to remember

```bash
nano file.yaml
vim file.yaml
find . -maxdepth 3 | sort
find . -name "app.yaml"
rg "platform-drill-api"
sed -n '42,70p' k8s/app.yaml
code playbook.md
```
